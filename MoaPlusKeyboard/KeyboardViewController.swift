import UIKit
import SwiftUI
import AudioToolbox
import Combine

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {

    // Required for playInputClick() to work
    var enableInputClicksWhenVisible: Bool { return true }

    private var keyboardView: UIViewController?
    private let viewModel = KeyboardViewModel()
    private var heightConstraint: NSLayoutConstraint?
    /// First viewDidAppear is the cold start — no prior lifecycle to recover
    /// from, so we skip the isUserInteractionEnabled toggle that exists for
    /// recovering touch delivery after background→foreground transitions.
    private var hasAppearedOnce = false
    /// True while our own insert/delete is in flight. Our text edits always
    /// fire textWillChange→textDidChange and incidentally move the selection;
    /// a user tapping elsewhere in the field fires selectionDidChange WITHOUT
    /// a text change. This flag lets selectionDidChange tell the two apart so
    /// only a genuine external caret move clears the composer (the
    /// "안욥하세욥" bug). Cleared on the next runloop tick after textDidChange
    /// because selectionDidChange arrives synchronously within the same edit.
    private var isProgrammaticTextChange = false
    /// Keeps the container height in sync while the keyboard is on screen and
    /// the user drags the height slider in the host app. `viewWillAppear`
    /// already re-applies on every show; this covers the split-screen /
    /// side-by-side case where no re-appearance happens.
    private var heightScaleCancellable: AnyCancellable?
    /// 하단 여백 두 설정(자동 토글 / 추가 여백)에 대한 구독.
    /// `heightScaleCancellable` 과 같은 이유 — 호스트 앱에서 슬라이더를 드래그하는
    /// 동안에도 컨테이너 높이가 따라가야 한다(스플릿 뷰에서는 재등장이 없다).
    private var bottomInsetCancellables: Set<AnyCancellable> = []
    /// 약어 후보 바는 키보드 VStack 안에 끼어들어가므로, 컨테이너 높이를 그만큼
    /// 늘리지 않으면 아래쪽 기능행이 잘린다(실기기 확인). 표시 상태를 여기서 들고 있다가
    /// 모든 높이 계산 지점에 반영한다.
    private var isCandidateBarVisible = false
    private var candidateBarCancellable: AnyCancellable?
    /// 호스트 앱의 백그라운드 ↔ 포그라운드 전환 관찰자.
    ///
    /// 익스텐션에는 `UIApplication` 이 없으므로 `NSExtensionHost*` 알림을 쓴다.
    /// 키보드를 **띄운 채** 앱만 전환하고 돌아오면 뷰가 사라진 적이 없어
    /// `viewDidAppear` 가 불리지 않는다 → 거기 있던 터치 복구 토글도 안 돈다.
    /// 그 결과 키보드가 살아 보이는데 입력이 먹지 않는다(카카오톡 실기기 확인).
    private var hostForegroundObserver: NSObjectProtocol?
    private var hostBackgroundObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Match the SwiftUI keyboard background fallback color so the first
        // frame doesn't flash the bare UIInputViewController background
        // (system keyboard gray) before SwiftUI's Color(.systemGray6) lays in.
        view.backgroundColor = UIColor.systemGray6

        // 키보드 높이 설정 (iOS 키보드 익스텐션은 명시적 높이 필요)
        guard let rootView = self.view else { return }
        let heightConstraint = NSLayoutConstraint(
            item: rootView,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: computedKeyboardHeight()
        )
        // 999, not .required(1000): on globe-key keyboard switches iOS lays
        // the input container out at its own provisional height first. A
        // .required height constraint then "snaps" in a frame later — the
        // visible jump-then-settle the user reported. 999 lets our height
        // win steady-state while yielding to the system's transient layout,
        // so it converges without the jump/flicker.
        heightConstraint.priority = UILayoutPriority(rawValue: 999)
        rootView.addConstraint(heightConstraint)
        self.heightConstraint = heightConstraint

        viewModel.delegate = self
        // iOS only permits input-mode switching when it says so (e.g. more than
        // one keyboard installed). Feeding it to the view model keeps the globe
        // key from ever rendering as a dead button. Re-applied on every
        // appearance below, since the user can add a keyboard mid-session.
        viewModel.canSwitchInputMode = needsInputModeSwitchKey
        // Settings must be loaded before SwiftUI hosts the keyboard so the
        // first measure pass sees the user's layout/theme — otherwise the
        // initial frame uses defaults and visibly re-renders once
        // viewWillAppear's loadAll() lands.
        KeyboardSettings.shared.loadAll()
        setupKeyboardView()
        observeHeightScale()
        observeBottomInset()
        observeCandidateBar()
        observeHostLifecycle()
        // Audio session warmup removed: it ignored clickSoundEnabled and
        // played an unconditional click on every keyboard show, audible
        // even to users who disabled sounds and inconsistent with normal
        // typing volume. iOS routes the first real AudioServicesPlaySystemSound
        // call fine without explicit warmup.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The keyboard extension lives in a separate process from the main
        // app, so @Published mutations there don't notify our singleton.
        // Reload from App Group UserDefaults on every appearance to pick up
        // theme/gesture/etc. changes the user just made in the host app.
        // No forced layoutIfNeeded — letting UIKit/SwiftUI run their normal
        // layout pass once avoids a visible double-layout flicker on first
        // appearance.
        KeyboardSettings.shared.loadAll()
        // `viewDidLoad` 시점에는 아직 레이아웃 전이라 `safeAreaInsets.bottom` 이 0 이고,
        // 첫 제약 상수가 여백만큼 짧게 잡힌다. `viewSafeAreaInsetsDidChange` 가
        // 곧바로 키우므로 결과는 같지만 한 번의 정착 과정을 거친다 — 위 999 우선순위
        // 주석이 설명하는 것과 같은 종류의 수렴이다.
        viewModel.bottomSafeAreaInset = view.safeAreaInsets.bottom
        heightConstraint?.constant = computedKeyboardHeight()
        viewModel.canSwitchInputMode = needsInputModeSwitchKey
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Skip the touch-recovery toggle on the very first appearance. It
        // exists to fix touch delivery after background→foreground cycles,
        // and applying it on cold start causes a visible reattach flash.
        if hasAppearedOnce, let hostingView = keyboardView?.view {
            hostingView.isUserInteractionEnabled = false
            hostingView.isUserInteractionEnabled = true
        }
        hasAppearedOnce = true

        // 안전영역 기록/반영은 **여기서도** 해야 한다. `viewSafeAreaInsetsDidChange`
        // 는 값이 *바뀔 때만* 불리므로, 처음부터 0 이고 계속 0 인 환경(iOS 26 처럼
        // 시스템이 키보드 아래에 지구본 바를 직접 그려 우리 뷰가 홈 인디케이터
        // 구역까지 내려가지 않는 경우)에서는 한 번도 호출되지 않는다.
        // 그러면 진단 기록이 영영 비어 있어 "먹었는지 / 이중인지"를 판정할 수 없다.
        publishSafeAreaInset()

        // Reset any stuck gesture state (e.g., user was mid-drag when backgrounding)
        viewModel.resetGestureState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // The keyboard can be torn down mid-press — e.g. the host app presents
        // a photo picker while the finger is still holding backspace. The
        // repeat timer is driven by a Timer, not by touch events, so nothing
        // else stops it: it keeps firing deleteBackward() against the proxy of
        // a field the user can no longer see. Previously this was only cleared
        // on the *next* viewDidAppear, i.e. after the damage was done.
        viewModel.resetGestureState()
    }

    private func computedKeyboardHeight() -> CGFloat {
        let bounds = UIScreen.main.bounds
        let screenShort = min(bounds.width, bounds.height)
        let screenLong = max(bounds.width, bounds.height)
        let isPad = traitCollection.userInterfaceIdiom == .pad
        // 키보드 폭 = 현재 화면 폭. 레이아웃 전이면 UIScreen 폭으로 폴백.
        let width = view.bounds.width > 0 ? view.bounds.width : bounds.width
        let isLandscape = KeyboardMetrics.isLandscapeKeyboard(
            keyboardWidth: width, screenShort: screenShort, screenLong: screenLong)
        return KeyboardMetrics.keyboardHeight(
            isPad: isPad, isLandscape: isLandscape, screenShort: screenShort, screenLong: screenLong,
            scale: KeyboardSettings.shared.keyboardHeightScale)
            + candidateBarExtraHeight
            + bottomInset()
    }

    /// 현재 기기/설정 기준 하단 여백.
    ///
    /// 자동 여백의 근거는 **실측 `view.safeAreaInsets.bottom` 뿐**이고 기기 추정에
    /// 기대지 않는다. 이 값은 정의상 "이 뷰 하단에서 시스템 UI(홈 인디케이터)에
    /// 가려지는 영역"이므로, iOS 가 0 을 보고하면 우리 뷰는 애초에 그 구역까지
    /// 내려가 있지 않다는 뜻이다 — 홈 버튼 기기든, 시스템이 이미 띄워 준
    /// 경우든 여백을 더하면 그만큼 헛돈다. **화면 크기로 34pt 를 추정해 더하는
    /// 폴백을 넣지 말 것**: 여백이 이중으로 들어가는 유일한 경로다.
    ///
    /// `KeyboardView` 도 **같은 규칙**으로 계산해야 한다 — 컨테이너 높이와
    /// 그리드 배분이 어긋나면 기능행이 잘린다.
    private func bottomInset() -> CGFloat {
        KeyboardMetrics.resolvedBottomInset(
            autoEnabled: KeyboardSettings.shared.keyboardAutoBottomInsetEnabled,
            deviceInset: view.safeAreaInsets.bottom,
            extra: KeyboardSettings.shared.keyboardExtraBottomInset)
    }

    /// 익스텐션에서만 읽히는 실측 안전영역을 뷰 모델로 넘긴다(글로브 키의
    /// `canSwitchInputMode` 와 같은 경로). SwiftUI 쪽 여백 계산이 이 값을 본다.
    private func publishSafeAreaInset() {
        let measured = view.safeAreaInsets.bottom
        recordGeometryDiagnostic(measured: measured)
        guard viewModel.bottomSafeAreaInset != measured else { return }
        viewModel.bottomSafeAreaInset = measured
        heightConstraint?.constant = computedKeyboardHeight()
    }

    /// 하단 여백이 실제로 먹었는지 / 이중으로 들어갔는지 판정할 수 있는 삼종세트를
    /// App Group 에 남긴다. 시뮬레이터에서는 서드파티 키보드를 띄울 수 없어
    /// 실기기 사용자가 "설정 › 입력 기록"에서 읽어 주는 경로가 유일한 관측 수단이다.
    ///
    /// 판독법: `bounds.height == constraint` 면 우리가 요청한 높이가 곧 실제
    /// 프레임이고 여백은 정확히 한 번 들어간 것. `bounds.height ≈ constraint + 안전영역`
    /// 이면 iOS 가 스트립을 위에 더 얹은 것이라 컨테이너를 키우면 안 되고
    /// 패딩만 넣어야 한다.
    /// 마지막으로 진단에 기록한 컨테이너 높이. `viewDidAppear` 시점의 값은 iOS 가
    /// 아직 자기 잠정 높이로 잡아 둔 것이라 실제와 다르다(위 999 우선순위 주석 참조).
    /// 레이아웃이 정착한 뒤 값이 바뀔 때마다 덮어써야 기록이 실제를 가리킨다.
    private var lastDiagnosticBoundsHeight: CGFloat = -1

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.height != lastDiagnosticBoundsHeight else { return }
        recordGeometryDiagnostic(measured: view.safeAreaInsets.bottom)
    }

    private static let diagnosticTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()

    private func recordGeometryDiagnostic(measured: CGFloat) {
        lastDiagnosticBoundsHeight = view.bounds.height
        // 시각을 함께 남긴다 — 기록이 이번 실행에서 나온 것인지, 업데이트 전 빌드의
        // 잔재인지 사용자가 구분할 수 있어야 판독이 성립한다.
        let stamp = Self.diagnosticTimeFormatter.string(from: Date())
        // 메인 앱 설정/미리보기가 앱 창 값 대신 이 실측값을 쓰도록 남긴다.
        KeyboardSettings.shared.recordMeasuredBottomInset(Double(measured))
        KeyboardSettings.shared.recordKeyboardGeometryDiagnostic(
            String(format: "%@ bounds.h=%.1f constraint=%.1f safeArea.bottom=%.1f 여백=%.1f",
                   stamp, view.bounds.height, heightConstraint?.constant ?? -1,
                   measured, bottomInset()))
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        publishSafeAreaInset()
    }

    /// 후보 바가 떠 있는 동안 컨테이너에 더해 줄 높이.
    private var candidateBarExtraHeight: CGFloat {
        isCandidateBarVisible ? KeyboardMetrics.abbreviationCandidateBarFootprint : 0
    }

    /// 호스트 앱이 포그라운드로 돌아올 때 터치 전달을 되살린다.
    ///
    /// iOS 키보드 익스텐션은 호스트가 백그라운드를 다녀오면 호스팅 뷰가 터치를 더 이상
    /// 받지 않는 상태로 남을 수 있다. `viewDidAppear` 에 이미 같은 복구가 있지만,
    /// 키보드를 **닫지 않고** 앱만 전환하면 뷰 생명주기 콜백이 아예 오지 않아 그 경로가
    /// 돌지 않는다. 그래서 익스텐션용 호스트 알림으로 같은 복구를 건다.
    private func observeHostLifecycle() {
        hostForegroundObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostDidBecomeActive,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recoverTouchDelivery()
        }

        // 백그라운드로 갈 때는 진행 중이던 제스처/반복 타이머를 정리한다.
        // `viewWillDisappear` 의 정리와 같은 목적인데, 키보드를 띄운 채 앱을 전환하면
        // 그쪽도 불리지 않아 백스페이스 반복이 보이지 않는 필드에 계속 먹힐 수 있다.
        hostBackgroundObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSExtensionHostDidEnterBackground,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.resetGestureState()
        }
    }

    private func recoverTouchDelivery() {
        if let hostingView = keyboardView?.view {
            hostingView.isUserInteractionEnabled = false
            hostingView.isUserInteractionEnabled = true
        }
        // 전환 중 손가락이 떠 있었을 수 있으니 제스처 상태도 초기화한다.
        viewModel.resetGestureState()
    }

    deinit {
        if let hostForegroundObserver {
            NotificationCenter.default.removeObserver(hostForegroundObserver)
        }
        if let hostBackgroundObserver {
            NotificationCenter.default.removeObserver(hostBackgroundObserver)
        }
    }

    /// 후보 바 표시/숨김에 맞춰 키보드 높이를 늘렸다 줄인다.
    /// 이게 없으면 바가 뜨는 순간 기능행(스페이스·엔터)이 화면 밖으로 밀려 잘린다.
    private func observeCandidateBar() {
        candidateBarCancellable = viewModel.$isAbbreviationCandidateVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                guard let self, self.isCandidateBarVisible != visible else { return }
                self.isCandidateBarVisible = visible
                self.heightConstraint?.constant = self.computedKeyboardHeight()
            }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            let bounds = UIScreen.main.bounds
            let screenShort = min(bounds.width, bounds.height)
            let screenLong = max(bounds.width, bounds.height)
            let isPad = self.traitCollection.userInterfaceIdiom == .pad
            let isLandscape = KeyboardMetrics.isLandscapeKeyboard(
                keyboardWidth: size.width, screenShort: screenShort, screenLong: screenLong)
            self.heightConstraint?.constant = KeyboardMetrics.keyboardHeight(
                isPad: isPad, isLandscape: isLandscape, screenShort: screenShort, screenLong: screenLong,
                scale: KeyboardSettings.shared.keyboardHeightScale)
                + self.candidateBarExtraHeight
                + self.bottomInset()
        })
    }

    /// `loadAll()` reassigns every @Published on each cross-process change, so
    /// `removeDuplicates()` is required or this fires on unrelated edits.
    private func observeHeightScale() {
        heightScaleCancellable = KeyboardSettings.shared.$keyboardHeightScale
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.heightConstraint?.constant = self.computedKeyboardHeight()
            }
    }

    /// `loadAll()` 이 매 변경마다 모든 @Published 를 재대입하므로
    /// `removeDuplicates()` 없이는 무관한 설정 편집에도 발화한다.
    private func observeBottomInset() {
        KeyboardSettings.shared.$keyboardAutoBottomInsetEnabled
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.heightConstraint?.constant = self.computedKeyboardHeight()
            }
            .store(in: &bottomInsetCancellables)

        KeyboardSettings.shared.$keyboardExtraBottomInset
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                self.heightConstraint?.constant = self.computedKeyboardHeight()
            }
            .store(in: &bottomInsetCancellables)
    }

    private func setupKeyboardView() {
        let rootView = KeyboardView(
            viewModel: viewModel,
            gestureState: viewModel.gestureState,
            popupState: viewModel.popupState
        ).ignoresSafeArea(.all)
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        keyboardView = hostingController
    }

    override func textWillChange(_ textInput: UITextInput?) {
        // A text edit is starting. Mark it so the selectionDidChange that
        // rides along with our own insert/delete is not mistaken for the
        // user tapping elsewhere.
        isProgrammaticTextChange = true
    }

    override func textDidChange(_ textInput: UITextInput?) {
        // Reset composer state when text field is cleared externally
        // (e.g., when user sends a message and the app clears the input field)
        // Only reset if the text field is completely empty
        if textDocumentProxy.documentContextBeforeInput == nil &&
           textDocumentProxy.documentContextAfterInput == nil {
            viewModel.resetComposer()
        }
        // Clear on the NEXT runloop tick: the selectionDidChange caused by
        // this same edit fires synchronously before we return here, so the
        // flag must stay set until the edit fully settles.
        DispatchQueue.main.async { [weak self] in
            self?.isProgrammaticTextChange = false
        }
    }

    override func selectionWillChange(_ textInput: UITextInput?) {}

    override func selectionDidChange(_ textInput: UITextInput?) {
        // Selection moved without an accompanying text edit ⇒ the user
        // tapped elsewhere in the host field; iOS already repositioned the
        // caret. Freeze the composer so the next keystroke starts fresh at
        // the new caret. Our programmatic caret moves (moveCursor /
        // auto-bracket) also land here but already cleared the composer, so
        // handleExternalCursorMove is a harmless no-op there.
        if isProgrammaticTextChange { return }
        viewModel.handleExternalCursorMove()
    }
}

// MARK: - KeyboardViewModelDelegate
extension KeyboardViewController: KeyboardViewModelDelegate {
    func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    func updateComposingText(from previous: String, to current: String) {
        // iOS keyboard extensions don't support marked text directly,
        // so we simulate it by deleting the previous composing text
        // and inserting the new composing text.

        // Delete previous composing characters
        for _ in previous {
            textDocumentProxy.deleteBackward()
        }

        // Insert new composing characters
        if !current.isEmpty {
            textDocumentProxy.insertText(current)
        }
    }

    func switchToNextKeyboard() {
        advanceToNextInputMode()
    }

    func triggerHapticFeedback() {
        HapticManager.shared.playTap()
        if KeyboardSettings.shared.clickSoundEnabled {
            AudioServicesPlaySystemSound(KeyboardMetrics.clickSoundID)
        }
    }

    func moveCursor(by offset: Int) {
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    func textBeforeCursor() -> String? {
        textDocumentProxy.documentContextBeforeInput
    }

    func textAfterCursor() -> String? {
        textDocumentProxy.documentContextAfterInput
    }
}

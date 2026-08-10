import UIKit
import SwiftUI
import AudioToolbox
import Combine

class KeyboardViewController: UIInputViewController, UIInputViewAudioFeedback {

    // Required for playInputClick() to work
    var enableInputClicksWhenVisible: Bool { return true }

    private var keyboardView: UIViewController?
    private let viewModel = KeyboardViewModel()
    private var feedbackGenerator: UIImpactFeedbackGenerator?
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
        setupHapticFeedback()
        observeHeightScale()
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

    private func setupHapticFeedback() {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator?.prepare()
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

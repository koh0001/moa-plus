import SwiftUI

struct KeyView: View {
    let content: KeyContent
    let keySize: CGSize
    let isPressed: Bool
    let previewVowel: Jungseong?
    let longPressNumber: String?
    var secondaryAction: SecondaryKeyAction?
    var showSecondaryHints: Bool = true
    var hintSize: Int = 1
    var isGestureActive: Bool = false
    var row: Int = 1  // Row index (0 = top row, popup goes down)
    var column: Int = 3  // Column index (0 and 6 = side keys)
    var shiftState: ShiftState = .off
    var mode: KeyboardMode = .korean
    let onLongPress: ((String) -> Void)?
    let onBackspacePressStart: (() -> Void)?
    let onBackspacePressEnd: (() -> Void)?
    let onGestureStart: (CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: () -> Void
    var onPopupDrag: ((CGFloat) -> Void)?     // translationX during long-press drag
    var onPopupRelease: (() -> Void)?          // finger up after long-press
    /// Long-press handler for the English-mode shift key. Fires
    /// caps-lock toggle so users can hold shift to lock instead of
    /// having to time a precise double-tap.
    var onShiftLongPress: (() -> Void)? = nil
    /// 시스템이 터치를 가져가 SwiftUI 제스처가 끝내 오지 않았을 때 뷰모델의 진행 중
    /// 제스처(활성 키·팝업)를 입력 확정 없이 걷는다. `EarlyTouch.swift` 참조.
    var onGestureCancel: (() -> Void)? = nil

    @State private var isHighlighted = false
    @State private var pressLinger = false
    @State private var showNumberPopup = false
    @State private var longPressTimer: Timer?

    var body: some View {
        ZStack {
            // Key background
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                .fill(themedBackgroundColor)
                .shadow(color: .black.opacity(0.2), radius: showsPressed ? 0 : 1, y: showsPressed ? 0 : 1)

            // Key label
            keyLabel

            // Secondary hint label
            if let action = secondaryAction, showSecondaryHints {
                if KeyboardSettings.shared.showDetailedHints {
                    // Detailed: show all popup candidates
                    Text(action.popupOutputs.joined(separator: " "))
                        .font(.system(size: max(hintFontSize - 2, 6)))
                        .foregroundColor(themedTextColor.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 2)
                        .opacity(isGestureActive ? 0 : 1)
                } else {
                    // Simple: show only primary hint
                    Text(action.visibleHint)
                        .font(.system(size: hintFontSize))
                        .foregroundColor(themedTextColor.opacity(0.6))
                        .padding(hintEdge, hintEdgePadding)
                        .padding(.top, 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hintAlignment)
                        .opacity(isGestureActive ? 0 : 1)
                }
            }
        }
        .frame(width: keySize.width, height: keySize.height)
        .onChange(of: isPressed) { _, pressed in
            if pressed {
                pressLinger = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.pressLingerDuration) {
                    pressLinger = false
                }
            }
        }
        .gesture(
            // Use the keyboard-frame coordinate space so start point and
            // current location are reported in the keyboard's frame, not
            // the key's local frame. GestureOverlayView positions itself
            // using these coords (opposite-side rendering).
            DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboardPreview"))
                .onChanged { value in
                    TouchLatencyProbe.recordRecognition(label: probeLabel)
                    // 하단 절반에서는 `earlyPress` 가 ~20ms 에 이미 시작했다 — 여기서는
                    // 건너뛴다(두 번 시작하면 백스페이스 두 번·진동 두 번).
                    if !isHighlighted {
                        beginPress(at: value.startLocation)
                    }

                    guard !isBackspaceKey else { return }

                    if showNumberPopup {
                        // Long-press popup is showing — drag selects candidates
                        onPopupDrag?(value.translation.width)
                        return
                    }

                    // Cancel long press if user moved significantly (for consonant gesture).
                    // 곱셈으로 계산한다 — 터치 포인트마다 도는 자리라 pow(_:2) 를 쓰면
                    // Double 지수 함수가 포인트당 2회 호출된다(GestureAnalyzer 도 같은
                    // 계산을 dx*dx+dy*dy 로 한다).
                    let dx = value.translation.width, dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance > KeyboardMetrics.gestureThreshold {
                        cancelLongPressTimer()
                    }

                    onGestureMove(value.location)
                }
                .onEnded { _ in
                    isHighlighted = false
                    cancelLongPressTimer()

                    if showNumberPopup {
                        // Release after long-press — confirm popup selection
                        hideNumberPopup()
                        onPopupRelease?()
                        return
                    }

                    hideNumberPopup()
                    if isBackspaceKey {
                        onBackspacePressEnd?()
                    } else {
                        onGestureEnd()
                    }
                }
        )
        // SwiftUI 제스처는 키보드 아래쪽 절반에서 가만히 누르면 ~0.75초 늦게 시작한다
        // (iOS 27 실측). 누름 시작만 UIKit 층에서 먼저 받는다 — `EarlyTouch.swift`.
        .earlyPress(
            onPress: { point in
                guard !isHighlighted else { return }
                TouchLatencyProbe.event("조기 시작")
                beginPress(at: point)
            },
            onMove: { t in
                // SwiftUI 가 아직 안 붙은 동안 긋기가 시작되면 롱프레스를 여기서 끊는다.
                if !isBackspaceKey, sqrt(t.width * t.width + t.height * t.height) > KeyboardMetrics.gestureThreshold {
                    cancelLongPressTimer()
                }
            },
            isStillPressed: { isHighlighted },
            onUnhandledRelease: { cancelUnhandledPress() }
        )
        .onDisappear {
            if isHighlighted && isBackspaceKey {
                onBackspacePressEnd?()
            }
            cancelLongPressTimer()
            isHighlighted = false
            showNumberPopup = false
        }
    }

    @ViewBuilder
    private var keyLabel: some View {
        let fontSize = keySize.height * 0.4
        switch content {
        case .consonant(let consonant):
            VStack(spacing: 2) {
                Text(String(consonant.compatibilityCharacter))
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(themedTextColor)

                // Show preview vowel when dragging
                if let vowel = previewVowel {
                    Text(String(vowel.compatibilityCharacter))
                        .font(.system(size: keySize.height * 0.25))
                        .foregroundColor(themedTextColor)
                        .opacity(0.9)
                }
            }

        case .symbol(let s):
            let displayText = (mode == .english && s.first?.isLetter == true && shiftState != .off)
                ? s.uppercased() : s
            Text(displayText)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(themedTextColor)

        case .backspace:
            Image(systemName: "delete.left")
                .font(.system(size: keySize.height * 0.35))
                .foregroundColor(themedTextColor)

        case .backspaceWide:
            Image(systemName: "delete.left")
                .font(.system(size: 20))
                .foregroundColor(themedTextColor)

        case .vowelPrimitive(let type):
            switch type {
            case .bar:
                if let vowel = previewVowel {
                    Text(String(vowel.compatibilityCharacter))
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(themedTextColor)
                } else {
                    VStack(spacing: 1) {
                        Text("ㅕ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                        HStack(spacing: 2) {
                            Text("ㅓ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                            Text("ㅣ").font(.system(size: fontSize, weight: .medium)).foregroundColor(themedTextColor)
                            Text("ㅏ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                        }
                        Text("ㅑ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                    }
                    .opacity(isGestureActive ? 0 : 1)
                }
            case .dash:
                if let vowel = previewVowel {
                    Text(String(vowel.compatibilityCharacter))
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(themedTextColor)
                } else {
                    VStack(spacing: 1) {
                        Text("ㅗ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                        HStack(spacing: 2) {
                            Text("ㅛ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                            Text("ㅡ").font(.system(size: fontSize, weight: .medium)).foregroundColor(themedTextColor)
                            Text("ㅠ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                        }
                        Text("ㅜ").font(.system(size: 9)).foregroundColor(themedTextColor.opacity(0.5))
                    }
                    .opacity(isGestureActive ? 0 : 1)
                }
            case .dot:
                Text(type.displayLabel)
                    .font(.system(size: fontSize))
                    .foregroundColor(themedTextColor)
            }

        case .functional(let type):
            if type == .shift {
                let iconName: String = {
                    switch shiftState {
                    case .off:    return "shift"
                    case .on:     return "shift.fill"
                    case .locked: return "capslock.fill"
                    }
                }()
                Image(systemName: iconName)
                    .font(.system(size: keySize.height * 0.35, weight: .medium))
                    .foregroundColor(shiftState != .off ? Color.accentColor : themedTextColor)
            } else {
                Text(type.rawValue)
                    .font(.system(size: fontSize * 0.7))
                    .foregroundColor(themedTextColor)
            }

        case .systemSwitch:
            Image(systemName: "globe")
                .font(.system(size: fontSize * 0.8))
                .foregroundColor(themedTextColor)

        case .quickPunctuation(let punct):
            Text(punct)
                .font(.system(size: fontSize))
                .foregroundColor(themedTextColor)

        case .slotBVowelKey:
            // KeyGridView intercepts this case and renders SlotBVowelKey directly.
            // This stub exists only to satisfy exhaustive switch.
            EmptyView()

        case .slotBPunctuation:
            // KeyGridView intercepts this case and renders PunctuationSwipeKey directly.
            EmptyView()
        }
    }


    private var hintFontSize: CGFloat {
        switch hintSize {
        case 0: return 8
        case 2: return 12
        default: return 10
        }
    }

    private var hintAlignment: Alignment {
        switch secondaryAction?.hintInsetDirection {
        case .inwardLeft:
            return .topLeading
        default:
            return .topTrailing
        }
    }

    private var hintEdge: Edge.Set {
        switch secondaryAction?.hintInsetDirection {
        case .inwardLeft:
            return .leading
        default:
            return .trailing
        }
    }

    private var hintEdgePadding: CGFloat { 4 }

    private var isSideKey: Bool {
        column == 0 || column == 6
    }

    /// 눌림 표시 여부. 짧은 탭은 누름→뗌이 한두 프레임 안에 끝나 표시가 그려지기도 전에
    /// 사라지므로 `pressLinger` 로 뗀 뒤 잠깐 더 남긴다 (앱스토어 리뷰 2026-09-28
    /// "자음만 클릭했을 때도 누른 표시가 났으면").
    private var showsPressed: Bool { isPressed || isHighlighted || pressLinger }

    /// 눌림 표시를 뗀 뒤 남기는 시간. 연타 속도(~100ms 간격)를 넘지 않게 짧게 둔다.
    static let pressLingerDuration: TimeInterval = 0.08

    private var themedBackgroundColor: Color {
        // 미리 계산된 색 캐시를 읽는다 — ThemeSettings 를 통째로 복사하면 키마다
        // 구조체 복사(String? 필드 때문에 ARC 발생) + Color 재생성이 일어난다.
        //
        // 눌림 색은 순정 키보드처럼 **반대쪽 키 색**으로 바꾼다(일반 키 → 기능키 색,
        // 기능키 → 일반 키 색). 예전처럼 투명도만 낮추면 뒤 배경(`systemGray6`)이 키 색과
        // 거의 같아 눌러도 티가 나지 않았다.
        let ts = KeyboardSettings.shared
        let key = ts.resolvedKeyBackground
        let function = ts.resolvedFunctionKeyBackground
        let usesFunctionColor: Bool
        switch content {
        case .consonant:
            usesFunctionColor = false
        case .vowelPrimitive:
            return showsPressed ? function : key.opacity(0.85)
        case .symbol(let s), .quickPunctuation(let s):
            // English mode: letter keys use normal key color; digit keys use function key color
            // Korean / symbol mode: center keys use key color, side keys use function key color
            usesFunctionColor = mode == .english ? s.first?.isNumber == true : isSideKey
        case .functional, .systemSwitch, .backspace, .backspaceWide,
             .slotBVowelKey, .slotBPunctuation:
            usesFunctionColor = true
        }
        if usesFunctionColor {
            return showsPressed ? key : function
        }
        return showsPressed ? function : key
    }

    private var themedTextColor: Color {
        return KeyboardSettings.shared.resolvedKeyText
    }

    private var isBackspaceKey: Bool {
        if case .backspace = content { return true }
        if case .backspaceWide = content { return true }
        return false
    }

    private var probeLabel: String {
        String(String(describing: content).prefix(24))
    }

    /// 누름 시작 — SwiftUI 첫 `onChanged` 와 `earlyPress` 중 먼저 온 쪽이 한 번만 부른다.
    private func beginPress(at point: CGPoint) {
        isHighlighted = true
        if isBackspaceKey {
            TouchLatencyProbe.event("백스페이스 시작")
            onBackspacePressStart?()
        } else {
            onGestureStart(point)
            startLongPressTimer()
        }
    }

    /// 뗐는데 SwiftUI 가 끝내 처리하지 않은 누름(시스템 제스처가 가져감)의 뒷정리.
    /// 입력은 확정하지 않는다 — `onGestureEnd` 를 부르면 의도하지 않은 글자가 들어간다.
    private func cancelUnhandledPress() {
        isHighlighted = false
        cancelLongPressTimer()
        hideNumberPopup()
        if isBackspaceKey {
            onBackspacePressEnd?()
        } else {
            onGestureCancel?()
        }
    }

    private func startLongPressTimer() {
        let isShiftKey: Bool = {
            if case .functional(.shift) = content { return true }
            return false
        }()
        guard longPressNumber != nil || isShiftKey else { return }
        cancelLongPressTimer()

        let timer = Timer(timeInterval: KeyboardSettings.shared.longPressDelay, repeats: false) { _ in
            if isShiftKey {
                onShiftLongPress?()
                return
            }
            TouchLatencyProbe.event("롱프레스 팝업")
            showNumberPopup = true
            if let number = longPressNumber {
                onLongPress?(number)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        longPressTimer = timer
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func hideNumberPopup() {
        showNumberPopup = false
    }
}

// Legacy alias for compatibility
typealias ConsonantKeyView = KeyView

#Preview {
    HStack {
        KeyView(
            content: .consonant(.ㄱ),
            keySize: CGSize(width: 50, height: 50),
            isPressed: false,
            previewVowel: nil,
            longPressNumber: "4",
            onLongPress: { _ in },
            onBackspacePressStart: nil,
            onBackspacePressEnd: nil,
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )

        KeyView(
            content: .consonant(.ㄴ),
            keySize: CGSize(width: 50, height: 50),
            isPressed: true,
            previewVowel: .ㅏ,
            longPressNumber: "7",
            onLongPress: { _ in },
            onBackspacePressStart: nil,
            onBackspacePressEnd: nil,
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )

        KeyView(
            content: .symbol("!"),
            keySize: CGSize(width: 50, height: 50),
            isPressed: false,
            previewVowel: nil,
            longPressNumber: nil,
            onLongPress: nil,
            onBackspacePressStart: nil,
            onBackspacePressEnd: nil,
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )

        KeyView(
            content: .backspace,
            keySize: CGSize(width: 50, height: 50),
            isPressed: false,
            previewVowel: nil,
            longPressNumber: nil,
            onLongPress: nil,
            onBackspacePressStart: {},
            onBackspacePressEnd: {},
            onGestureStart: { _ in },
            onGestureMove: { _ in },
            onGestureEnd: {}
        )
    }
    .padding()
    .background(Color(.systemGray6))
}

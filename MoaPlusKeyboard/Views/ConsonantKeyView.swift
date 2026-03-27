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
    var row: Int = 1  // Row index (0 = top row, popup goes down)
    var column: Int = 3  // Column index (0 and 6 = side keys)
    let onLongPress: ((String) -> Void)?
    let onBackspacePressStart: (() -> Void)?
    let onBackspacePressEnd: (() -> Void)?
    let onGestureStart: (CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: () -> Void
    var onPopupDrag: ((CGFloat) -> Void)?     // translationX during long-press drag
    var onPopupRelease: (() -> Void)?          // finger up after long-press

    @State private var isHighlighted = false
    @State private var showNumberPopup = false
    @State private var longPressTimer: Timer?

    var body: some View {
        ZStack {
            // Key background
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                .fill(themedBackgroundColor)
                .shadow(color: .black.opacity(0.2), radius: isPressed ? 0 : 1, y: isPressed ? 0 : 1)

            // Key label
            keyLabel

            // Secondary hint label
            if let hint = secondaryAction?.visibleHint,
               showSecondaryHints {
                Text(hint)
                    .font(.system(size: hintFontSize))
                    .foregroundColor(Color(.label).opacity(0.5))
                    .padding(hintEdge, hintEdgePadding)
                    .padding(.top, 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hintAlignment)
            }
        }
        .frame(width: keySize.width, height: keySize.height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isHighlighted {
                        isHighlighted = true
                        if isBackspaceKey {
                            onBackspacePressStart?()
                        } else {
                            onGestureStart(value.startLocation)
                            startLongPressTimer()
                        }
                    }

                    guard !isBackspaceKey else { return }

                    if showNumberPopup {
                        // Long-press popup is showing — drag selects candidates
                        onPopupDrag?(value.translation.width)
                        return
                    }

                    // Cancel long press if user moved significantly (for consonant gesture)
                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
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
                        .foregroundColor(.blue)
                }
            }

        case .symbol(let symbol):
            Text(symbol)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(themedTextColor)

        case .backspace:
            Image(systemName: "delete.left")
                .font(.system(size: keySize.height * 0.35))
                .foregroundColor(themedTextColor)

        case .vowelPrimitive(let type):
            Text(type.displayLabel)
                .font(.system(size: fontSize))
                .foregroundColor(themedTextColor)

        case .functional(let type):
            Text(type.rawValue)
                .font(.system(size: fontSize * 0.7))
                .foregroundColor(themedTextColor)

        case .systemSwitch:
            Image(systemName: "globe")
                .font(.system(size: fontSize * 0.8))
                .foregroundColor(themedTextColor)

        case .quickPunctuation(let punct):
            Text(punct)
                .font(.system(size: fontSize))
                .foregroundColor(themedTextColor)
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

    private var themedBackgroundColor: Color {
        let ts = KeyboardSettings.shared.themeSettings
        switch content {
        case .consonant:
            return isPressed || isHighlighted ? ts.resolvedKeyBackground.opacity(0.7) : ts.resolvedKeyBackground
        case .vowelPrimitive:
            return isPressed || isHighlighted ? ts.resolvedKeyBackground.opacity(0.6) : ts.resolvedKeyBackground.opacity(0.85)
        case .symbol, .quickPunctuation:
            // Center symbols (numbers/chars) use key color, side symbols use function key color
            if isSideKey {
                return isPressed || isHighlighted ? ts.resolvedFunctionKeyBackground.opacity(0.7) : ts.resolvedFunctionKeyBackground
            }
            return isPressed || isHighlighted ? ts.resolvedKeyBackground.opacity(0.7) : ts.resolvedKeyBackground
        case .functional, .systemSwitch, .backspace:
            return isPressed || isHighlighted ? ts.resolvedFunctionKeyBackground.opacity(0.7) : ts.resolvedFunctionKeyBackground
        }
    }

    private var themedTextColor: Color {
        return KeyboardSettings.shared.themeSettings.resolvedKeyText
    }

    private var isBackspaceKey: Bool {
        if case .backspace = content {
            return true
        }
        return false
    }

    private func startLongPressTimer() {
        guard longPressNumber != nil else { return }

        longPressTimer = Timer.scheduledTimer(withTimeInterval: KeyboardSettings.shared.longPressDelay, repeats: false) { _ in
            showNumberPopup = true
            if let number = longPressNumber {
                onLongPress?(number)
            }
        }
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

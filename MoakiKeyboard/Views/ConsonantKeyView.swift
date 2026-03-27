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
    let onLongPress: ((String) -> Void)?
    let onBackspacePressStart: (() -> Void)?
    let onBackspacePressEnd: (() -> Void)?
    let onGestureStart: (CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: () -> Void

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
        .overlay(numberPopupOverlay, alignment: .top)
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

    @ViewBuilder
    private var numberPopupOverlay: some View {
        if showNumberPopup, let number = longPressNumber {
            Text(number)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                )
                .offset(y: -keySize.height * 0.8)
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

    private var themedBackgroundColor: Color {
        let theme = KeyboardSettings.shared.themeSettings.buttonTheme
        switch content {
        case .consonant:
            return isPressed || isHighlighted ? theme.keyBackgroundColor.opacity(0.7) : theme.keyBackgroundColor
        case .vowelPrimitive:
            return isPressed || isHighlighted ? theme.keyBackgroundColor.opacity(0.6) : theme.keyBackgroundColor.opacity(0.85)
        case .symbol, .functional, .systemSwitch, .quickPunctuation, .backspace:
            return isPressed || isHighlighted ? theme.functionKeyBackgroundColor.opacity(0.7) : theme.functionKeyBackgroundColor
        }
    }

    private var themedTextColor: Color {
        return KeyboardSettings.shared.themeSettings.buttonTheme.keyTextColor
    }

    private var isBackspaceKey: Bool {
        if case .backspace = content {
            return true
        }
        return false
    }

    private func startLongPressTimer() {
        guard longPressNumber != nil else { return }

        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
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

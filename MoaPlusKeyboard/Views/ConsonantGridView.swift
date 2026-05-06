import SwiftUI

struct KeyGridView: View {
    let centerKeyWidth: CGFloat
    let keyHeight: CGFloat
    let totalWidth: CGFloat
    let mode: KeyboardMode
    let activeKey: (row: Int, column: Int)?
    let previewVowel: Jungseong?
    var isGestureActive: Bool = false
    var shiftState: ShiftState = .off
    let onConsonantTap: (Choseong) -> Void
    let onSymbolTap: (String) -> Void
    let onBackspacePressStart: () -> Void
    let onBackspacePressEnd: () -> Void
    let onLongPressNumber: (String) -> Void
    var onShiftLongPress: (() -> Void)? = nil
    let onGestureStart: (Int, Int, CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: (Int, Int) -> Void
    var onPopupDrag: ((CGFloat) -> Void)?
    var onPopupRelease: (() -> Void)?

    /// Compute total width of a single row (sum of key widths + gaps)
    private func rowWidth(for row: Int) -> CGFloat {
        let columnCount = KeyboardMetrics.columnCount(for: row, mode: mode)
        var width: CGFloat = 0
        for col in 0..<columnCount {
            width += KeyboardMetrics.keyWidth(for: col, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
            if col < columnCount - 1 {
                width += KeyboardMetrics.keySpacing
            }
        }
        return width
    }

    /// Number of rows in the active layout.
    private var rowCount: Int {
        KeyboardMetrics.activeLayout(for: mode).count
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.keySpacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: KeyboardMetrics.keySpacing) {
                    let columnCount = KeyboardMetrics.columnCount(for: row, mode: mode)

                    ForEach(0..<columnCount, id: \.self) { column in
                        let content = KeyboardMetrics.keyContent(at: row, column: column, mode: mode)
                        let isActive = activeKey?.row == row && activeKey?.column == column

                        // Determine the key ID used for secondaryAction lookup:
                        // - Korean mode: use consonant's compatibilityCharacter (e.g. "ㄱ")
                        // - English mode symbol keys: use the symbol string itself (e.g. "1")
                        // - All other keys: no secondary action
                        let secondaryKeyId: String = {
                            switch content {
                            case .consonant(let choseong):
                                return String(choseong.compatibilityCharacter)
                            case .symbol(let s):
                                return s
                            default:
                                return ""
                            }
                        }()

                        // Long-press trigger:
                        // - Korean mode: use longPressNumbers table
                        // - English mode: digit keys use their primaryLongPressOutput from secondaryAction
                        let longPressNumber: String? = {
                            if mode == .korean {
                                return KeyboardMetrics.longPressNumber(at: row, column: column)
                            }
                            if mode == .english,
                               case .symbol(let s) = content,
                               s.first?.isNumber == true {
                                return KeyboardSettings.shared.secondaryAction(forKey: s)?.primaryLongPressOutput
                            }
                            return nil
                        }()

                        let width = KeyboardMetrics.keyWidth(
                            for: column,
                            row: row,
                            centerKeyWidth: centerKeyWidth,
                            mode: mode
                        )

                        KeyView(
                            content: content ?? .symbol(""),
                            keySize: CGSize(width: width, height: keyHeight),
                            isPressed: isActive,
                            previewVowel: isActive ? previewVowel : nil,
                            longPressNumber: longPressNumber,
                            secondaryAction: KeyboardSettings.shared.secondaryAction(forKey: secondaryKeyId),
                            showSecondaryHints: KeyboardSettings.shared.showSecondaryHints,
                            hintSize: KeyboardSettings.shared.hintSize,
                            isGestureActive: isGestureActive,
                            row: row,
                            column: column,
                            shiftState: shiftState,
                            mode: mode,
                            onLongPress: { number in
                                onLongPressNumber(number)
                            },
                            onBackspacePressStart: {
                                guard case .backspace = content else { return }
                                onBackspacePressStart()
                            },
                            onBackspacePressEnd: {
                                guard case .backspace = content else { return }
                                onBackspacePressEnd()
                            },
                            onGestureStart: { point in
                                onGestureStart(row, column, point)
                            },
                            onGestureMove: { point in
                                onGestureMove(point)
                            },
                            onGestureEnd: {
                                onGestureEnd(row, column)
                            },
                            onPopupDrag: { translationX in
                                onPopupDrag?(translationX)
                            },
                            onPopupRelease: {
                                onPopupRelease?()
                            },
                            onShiftLongPress: onShiftLongPress
                        )
                    }
                }
                .frame(width: rowWidth(for: row))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// Legacy alias for compatibility
typealias ConsonantGridView = KeyGridView

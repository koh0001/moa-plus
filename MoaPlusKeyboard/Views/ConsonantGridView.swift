import SwiftUI

struct KeyGridView: View {
    let centerKeyWidth: CGFloat
    let keyHeight: CGFloat
    let totalWidth: CGFloat
    let mode: KeyboardMode
    let layoutCustomization: LayoutCustomization
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
    var onSlotBVowelKey: ((GestureDirection?) -> Void)? = nil

    /// Returns the rendered width for a single cell, accounting for .backspaceWide.
    private func cellWidth(content: KeyContent, column: Int, row: Int) -> CGFloat {
        if case .backspaceWide = content {
            return KeyboardMetrics.keyWidth(forBackspaceWideAt: column, centerKeyWidth: centerKeyWidth)
        }
        // Slot B embedded keys (A3 col 6) use the same width as other col 6 cells.
        // The mode-aware key width helper already handles col 6 sizing (sideRatio*1.3).
        return KeyboardMetrics.keyWidth(for: column, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
    }

    /// Compute total width of a single row (sum of key widths + gaps)
    private func rowWidth(for row: Int) -> CGFloat {
        let layoutGrid = KeyboardMetrics.activeLayout(for: mode, layout: layoutCustomization)
        guard row >= 0 && row < layoutGrid.count else { return 0 }
        let cells = layoutGrid[row]
        var width: CGFloat = 0
        for (col, content) in cells.enumerated() {
            width += cellWidth(content: content, column: col, row: row)
            if col < cells.count - 1 {
                width += KeyboardMetrics.keySpacing
            }
        }
        return width
    }

    /// Number of rows in the active layout.
    private var rowCount: Int {
        KeyboardMetrics.activeLayout(for: mode, layout: layoutCustomization).count
    }

    var body: some View {
        let layoutGrid = KeyboardMetrics.activeLayout(for: mode, layout: layoutCustomization)
        VStack(spacing: KeyboardMetrics.keySpacing) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: KeyboardMetrics.keySpacing) {
                    let columnCount = layoutGrid[row].count

                    ForEach(0..<columnCount, id: \.self) { column in
                        let content: KeyContent? = layoutGrid[row][column]
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
                                return KeyboardMetrics.longPressNumber(at: row, column: column, layout: layoutCustomization)
                            }
                            if mode == .english,
                               case .symbol(let s) = content,
                               s.first?.isNumber == true {
                                return KeyboardSettings.shared.secondaryAction(forKey: s)?.primaryLongPressOutput
                            }
                            return nil
                        }()

                        let width = cellWidth(content: content ?? .symbol(""), column: column, row: row)

                        // A3 (.fullPackage) embeds slot B keys in col 6.
                        // KeyGridView intercepts those content types and renders the
                        // dedicated standalone views (already used in FunctionRowView).
                        if case .slotBVowelKey = content {
                            SlotBVowelKey(
                                width: width,
                                height: keyHeight,
                                onAction: { direction in onSlotBVowelKey?(direction) }
                            )
                        } else if case .slotBPunctuation = content {
                            PunctuationSwipeKey(
                                width: width,
                                height: keyHeight,
                                onPunctuation: { symbol in onSymbolTap(symbol) }
                            )
                        } else {
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
                                guard case .backspace = content else {
                                    if case .backspaceWide = content { onBackspacePressStart() }
                                    return
                                }
                                onBackspacePressStart()
                            },
                            onBackspacePressEnd: {
                                guard case .backspace = content else {
                                    if case .backspaceWide = content { onBackspacePressEnd() }
                                    return
                                }
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
                        }   // close else branch (slot B intercept)
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

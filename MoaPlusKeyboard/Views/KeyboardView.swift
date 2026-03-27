import SwiftUI
import Combine

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var settings = KeyboardSettings.shared

    private var keyboardBackground: some View {
        Group {
            if let imageId = KeyboardSettings.shared.themeSettings.backgroundImageId,
               let image = BackgroundImageManager.shared.loadUserImage(withId: imageId) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(KeyboardSettings.shared.themeSettings.backgroundOpacity)
            } else {
                Color(.systemGray6)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: geometry.size.width)
            let keyHeight = KeyboardMetrics.keyHeight(for: geometry.size.height)

                ZStack {
                    VStack(spacing: KeyboardMetrics.keySpacing) {
                        // Abbreviation candidate bar
                        if viewModel.isAbbreviationCandidateVisible,
                           !viewModel.abbreviationCandidates.isEmpty {
                            AbbreviationCandidateView(
                                trigger: viewModel.abbreviationCandidates.first?.trigger ?? "",
                                candidates: viewModel.abbreviationCandidates,
                                onConfirm: { expansion in viewModel.confirmAbbreviation(expansion) },
                                onDismiss: { viewModel.dismissAbbreviation() }
                            )
                        }

                        // Key grid (consonants or symbols based on mode)
                        KeyGridView(
                            centerKeyWidth: centerKeyWidth,
                            keyHeight: keyHeight,
                            totalWidth: geometry.size.width,
                            isSymbolMode: viewModel.isSymbolMode,
                            activeKey: viewModel.activeKey,
                            previewVowel: viewModel.previewVowel,
                            onConsonantTap: { consonant in
                                viewModel.inputConsonant(consonant)
                            },
                            onSymbolTap: { symbol in
                                viewModel.inputSymbol(symbol)
                            },
                            onBackspacePressStart: {
                                viewModel.beginBackspacePress()
                            },
                            onBackspacePressEnd: {
                                viewModel.endBackspacePress()
                            },
                            onLongPressNumber: { number in
                                viewModel.inputLongPressNumber(number)
                            },
                            onGestureStart: { row, column, point in
                                viewModel.gestureStarted(row: row, column: column, at: point)
                            },
                            onGestureMove: { point in
                                viewModel.gestureMoved(to: point)
                            },
                            onGestureEnd: { row, column in
                                viewModel.gestureEnded(row: row, column: column)
                            },
                            onPopupDrag: { translationX in
                                viewModel.updatePopupSelection(translationX: translationX)
                            },
                            onPopupRelease: {
                                viewModel.confirmPopupSelection()
                            }
                        )

                        // Function row
                        FunctionRowView(
                            totalWidth: geometry.size.width,
                            isSymbolMode: viewModel.isSymbolMode,
                            onToggleModePressed: {
                                viewModel.toggleMode()
                            },
                            onCommaPressed: {
                                viewModel.inputSymbol(",")
                            },
                            onSpacePressed: {
                                viewModel.inputSpace()
                            },
                            onReturnPressed: {
                                viewModel.inputReturn()
                            }
                        )
                    }
                    .padding(KeyboardMetrics.keySpacing)

                    // Gesture overlay (only shown when enabled and in Korean mode)
                    if settings.showGesturePreview && !viewModel.isSymbolMode {
                        GestureOverlayView(
                            directions: viewModel.gestureDirections,
                            startPoint: viewModel.gestureStartPoint,
                            currentVowel: viewModel.previewVowel
                        )
                    }

                    // Long-press popup with candidate bar
                    if viewModel.longPressPopupText != nil,
                       let activeRow = viewModel.activeKey?.row,
                       let activeCol = viewModel.activeKey?.column {
                        let sp = KeyboardMetrics.keySpacing
                        let x = keyXPosition(column: activeCol, row: activeRow, centerKeyWidth: centerKeyWidth, spacing: sp, totalWidth: geometry.size.width)
                        let y = CGFloat(activeRow) * (keyHeight + sp) + sp + keyHeight / 2
                        let popupY = activeRow == 0 ? y + keyHeight * 0.9 : y - keyHeight * 0.9
                        let candidates = viewModel.longPressPopupCandidates
                        let selectedIdx = viewModel.longPressPopupSelectedIndex

                        HStack(spacing: 2) {
                            ForEach(0..<candidates.count, id: \.self) { i in
                                Text(candidates[i])
                                    .font(.system(size: 18, weight: i == selectedIdx ? .bold : .regular))
                                    .foregroundColor(i == selectedIdx ? .white : .primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(i == selectedIdx ? Color.accentColor : Color(.systemBackground))
                                    )
                            }
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        )
                        .position(x: min(max(x, 80), geometry.size.width - 80), y: popupY)
                        .allowsHitTesting(false)
                    }
                }
                .background(keyboardBackground)
        }
    }

    /// Calculate the X center of a key based on column/row
    private func keyXPosition(column: Int, row: Int, centerKeyWidth: CGFloat, spacing: CGFloat, totalWidth: CGFloat) -> CGFloat {
        var x = spacing // left padding

        let columnCount = KeyboardMetrics.columnCount(for: row, isSymbolMode: viewModel.isSymbolMode)
        for col in 0..<columnCount {
            let w = KeyboardMetrics.keyWidth(for: col, row: row, centerKeyWidth: centerKeyWidth)
            if col == column {
                return x + w / 2
            }
            x += w + spacing
        }
        return totalWidth / 2 // fallback: center
    }
}

#Preview {
    KeyboardView(viewModel: KeyboardViewModel())
        .frame(height: 280)
}

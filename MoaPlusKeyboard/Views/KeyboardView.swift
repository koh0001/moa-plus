import SwiftUI
import Combine

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var settings = KeyboardSettings.shared
    @State private var cachedBgImage: UIImage?
    @State private var cachedBgImageId: String?

    private var keyboardBackground: some View {
        Group {
            if let image = cachedBgImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(KeyboardSettings.shared.themeSettings.backgroundOpacity)
                    .clipped()
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
                        let rawCandidates = viewModel.longPressPopupCandidates
                        let selectedIdx = viewModel.longPressPopupSelectedIndex
                        let isRightEdge = activeCol >= 5
                        // When auto-bracket is on, hide standalone closing brackets
                        let closingBrackets: Set<String> = [")", "]", "}", ">", "」", "』", "》", "】", "〕"]
                        let candidates = KeyboardSettings.shared.autoBracketEnabled
                            ? rawCandidates.filter { !closingBrackets.contains($0) }
                            : rawCandidates
                        // Right-edge: reverse display so leftward drag matches visual order
                        let displayCandidates = isRightEdge ? Array(candidates.reversed()) : candidates
                        let displaySelectedIdx = isRightEdge ? (candidates.count - 1 - min(selectedIdx, candidates.count - 1)) : min(selectedIdx, candidates.count - 1)

                        HStack(spacing: 2) {
                            ForEach(0..<displayCandidates.count, id: \.self) { i in
                                let text = displayCandidates[i]
                                // Show bracket pair if auto-bracket enabled
                                let label = KeyboardSettings.shared.autoBracketEnabled
                                    ? (bracketPairLabel(text) ?? text)
                                    : text
                                Text(label)
                                    .font(.system(size: label.count > 1 ? 14 : 18, weight: i == displaySelectedIdx ? .bold : .regular))
                                    .foregroundColor(i == displaySelectedIdx ? .white : .primary)
                                    .frame(width: label.count > 1 ? 44 : 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(i == displaySelectedIdx ? Color.accentColor : Color(.systemBackground))
                                    )
                            }
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        )
                        .position(x: {
                            let cellSize: CGFloat = 36
                            let popupHalfWidth = CGFloat(candidates.count) * (cellSize + 2) / 2 + 8
                            // Right-edge keys: anchor popup to the left of key
                            if activeCol >= 5 {
                                return min(x, geometry.size.width - popupHalfWidth - 4)
                            }
                            // Left-edge keys: anchor popup to the right
                            if activeCol == 0 {
                                return max(x, popupHalfWidth + 4)
                            }
                            return min(max(x, popupHalfWidth + 4), geometry.size.width - popupHalfWidth - 4)
                        }(), y: popupY)
                        .allowsHitTesting(false)
                    }
                }
                .background(keyboardBackground)
        }
        .onAppear { loadBackgroundIfNeeded() }
        .onChange(of: settings.themeSettings.backgroundImageId) { _ in loadBackgroundIfNeeded() }
    }

    private func loadBackgroundIfNeeded() {
        let currentId = settings.themeSettings.backgroundImageId
        guard currentId != cachedBgImageId else { return }
        cachedBgImageId = currentId
        if let id = currentId {
            cachedBgImage = BackgroundImageManager.shared.loadUserImage(withId: id)
        } else {
            cachedBgImage = nil
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

    /// Returns "( )" style label if the character is an opening bracket, nil otherwise
    private func bracketPairLabel(_ text: String) -> String? {
        let pairs: [String: String] = [
            "(": "( )", "[": "[ ]", "{": "{ }", "<": "< >",
            "「": "「」", "『": "『』", "《": "《》", "【": "【】", "〔": "〔〕"
        ]
        return pairs[text]
    }
}

#Preview {
    KeyboardView(viewModel: KeyboardViewModel())
        .frame(height: 280)
}

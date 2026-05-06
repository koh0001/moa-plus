import SwiftUI
import Combine

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var settings = KeyboardSettings.shared
    // Observe sub-states directly to reduce unnecessary redraws
    @ObservedObject var gestureState: GestureState
    @ObservedObject var popupState: PopupState
    private static let closingBrackets: Set<String> = [")", "]", "}", ">", "」", "』", "》", "】", "〕"]
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
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(
                for: geometry.size.width,
                columnCount: viewModel.keyboardMode == .english ? 10 : 7,
                mode: viewModel.keyboardMode
            )
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
                            mode: viewModel.keyboardMode,
                            activeKey: viewModel.activeKey,
                            previewVowel: viewModel.previewVowel,
                            isGestureActive: gestureState.activeKey != nil,
                            shiftState: viewModel.shiftState,
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
                            onShiftLongPress: {
                                viewModel.lockShift()
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
                            mode: viewModel.keyboardMode,
                            onToggleSymbolPressed: {
                                viewModel.toggleSymbolMode()
                            },
                            onToggleLetterPressed: {
                                viewModel.toggleLetterMode()
                            },
                            onSpacePressed: {
                                viewModel.inputSpace()
                            },
                            onPunctuation: { symbol in
                                viewModel.inputSymbol(symbol)
                            },
                            onReturnPressed: {
                                viewModel.inputReturn()
                            },
                            onCursorMoveDelta: { offset in
                                viewModel.moveCursor(by: offset)
                            }
                        )
                    }
                    .padding(KeyboardMetrics.keySpacing)

                    // Gesture overlay (only shown when enabled and in Korean mode)
                    if settings.showGesturePreview && viewModel.keyboardMode == .korean {
                        GestureOverlayView(
                            directions: gestureState.directions,
                            startPoint: gestureState.startPoint,
                            currentVowel: gestureState.previewVowel
                        )
                    }

                    // Long-press popup with candidate bar
                    if popupState.text != nil,
                       let activeRow = gestureState.activeKey?.row,
                       let activeCol = gestureState.activeKey?.column {
                        let sp = KeyboardMetrics.keySpacing
                        let x = keyXPosition(column: activeCol, row: activeRow, centerKeyWidth: centerKeyWidth, spacing: sp, totalWidth: geometry.size.width)
                        let y = CGFloat(activeRow) * (keyHeight + sp) + sp + keyHeight / 2
                        let popupY = activeRow == 0 ? y + keyHeight * 0.9 : y - keyHeight * 0.9
                        let rawCandidates = popupState.candidates
                        let selectedIdx = popupState.selectedIndex
                        let isRightEdge = activeCol >= 5
                        // When auto-bracket is on, hide standalone closing brackets
                        let candidates = KeyboardSettings.shared.autoBracketEnabled
                            ? rawCandidates.filter { !Self.closingBrackets.contains($0) }
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
                .onAppear { viewModel.setCenterKeyWidth(centerKeyWidth) }
                .onChange(of: centerKeyWidth) { newValue in
                    viewModel.setCenterKeyWidth(newValue)
                }
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

    /// Calculate the X center of a key based on column/row, with grid centered horizontally
    private func keyXPosition(column: Int, row: Int, centerKeyWidth: CGFloat, spacing: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let mode = viewModel.keyboardMode
        let columnCount = KeyboardMetrics.columnCount(for: row, mode: mode)

        // Calculate total grid width for centering
        var totalGridWidth: CGFloat = 0
        for col in 0..<columnCount {
            totalGridWidth += KeyboardMetrics.keyWidth(for: col, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
            if col < columnCount - 1 {
                totalGridWidth += spacing
            }
        }

        let leftMargin = max(spacing, (totalWidth - totalGridWidth) / 2)

        var x = leftMargin
        for col in 0..<columnCount {
            let w = KeyboardMetrics.keyWidth(for: col, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
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
    let vm = KeyboardViewModel()
    KeyboardView(viewModel: vm, gestureState: vm.gestureState, popupState: vm.popupState)
        .frame(height: 280)
}

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

            if viewModel.isSpecialCharLayerVisible {
                SpecialCharacterLayerView(
                    onCharacterTap: { char in viewModel.inputSymbol(char) },
                    onDismiss: { viewModel.isSpecialCharLayerVisible = false }
                )
            } else {
                ZStack {
                    VStack(spacing: KeyboardMetrics.keySpacing) {
                        // Abbreviation candidate bar
                        if viewModel.isAbbreviationCandidateVisible,
                           let candidate = viewModel.abbreviationCandidate {
                            AbbreviationCandidateView(
                                trigger: candidate.trigger,
                                replacement: candidate.replacement,
                                onConfirm: { viewModel.confirmAbbreviation() },
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
                }
                .background(keyboardBackground)
            }
        }
    }
}

#Preview {
    KeyboardView(viewModel: KeyboardViewModel())
        .frame(height: 280)
}

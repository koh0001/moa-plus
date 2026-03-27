import SwiftUI

struct TutorialPracticeView: View {
    @ObservedObject var viewModel: TutorialViewModel
    @FocusState private var isInputFocused: Bool

    private let accentBlue = Color(red: 0.26, green: 0.38, blue: 0.93)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stage title and description
                VStack(spacing: 8) {
                    Text(viewModel.currentStage.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(viewModel.currentStage.description)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Vowel gesture cards
                if !viewModel.currentStage.vowelGestures.isEmpty {
                    let columns = Array(
                        repeating: GridItem(.flexible(), spacing: 8),
                        count: min(viewModel.currentStage.vowelGestures.count, 4)
                    )
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.currentStage.vowelGestures) { gesture in
                            VowelGestureCard(gesture: gesture)
                        }
                    }
                    .padding(.horizontal, 12)
                }

                // Tip
                if let tip = viewModel.currentStage.tip {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.1))
                    )
                    .padding(.horizontal, 16)
                }

                // Keyboard switch banner
                keyboardBanner

                // Practice area
                if viewModel.hasPractice && !viewModel.stageCompleted {
                    practiceSection
                }

                // Stage completed
                if viewModel.stageCompleted {
                    stageCompletedSection
                }
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            viewModel.startStage()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }

    private var keyboardBanner: some View {
        VStack(spacing: 4) {
            if viewModel.showKeyboardWarning {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .foregroundColor(.orange)
                    Text("🌐 버튼을 눌러 모아+ 키보드로 전환하세요")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var practiceSection: some View {
        VStack(spacing: 16) {
            CharacterComparisonView(
                target: viewModel.currentTargetLine,
                states: viewModel.characterStates
            )
            .padding(.horizontal, 16)

            PracticeInputField(
                text: $viewModel.inputText,
                isFocused: $isInputFocused
            )
            .padding(.horizontal, 16)

            HStack {
                Text("\(viewModel.currentLineIndex + 1)/\(viewModel.totalLines) 줄")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if viewModel.lineCompleted {
                    Button {
                        viewModel.advanceToNextLine()
                        isInputFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("다음")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(accentBlue)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var stageCompletedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("잘하셨습니다!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Button {
                viewModel.advanceToNextStage()
            } label: {
                Text("다음 단계로")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentBlue)
                    )
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 20)
    }
}

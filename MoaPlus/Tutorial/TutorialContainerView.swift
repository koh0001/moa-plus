import SwiftUI

struct TutorialContainerView: View {
    @StateObject private var viewModel = TutorialViewModel()

    private let deepBlue = Color(red: 0.10, green: 0.10, blue: 0.18)
    private let accentBlue = Color(red: 0.26, green: 0.38, blue: 0.93)

    var body: some View {
        ZStack {
            // Background gradient matching main screen
            LinearGradient(
                colors: [deepBlue, accentBlue.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                if !viewModel.isCompletion {
                    ProgressView(value: viewModel.overallProgress)
                        .tint(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                // Stage content
                Group {
                    if viewModel.isCompletion {
                        TutorialCompletionView(onRestart: viewModel.restart)
                    } else if viewModel.isWelcome {
                        TutorialWelcomeView(
                            stage: viewModel.currentStage,
                            onStart: viewModel.advanceToNextStage
                        )
                    } else {
                        TutorialPracticeView(viewModel: viewModel)
                    }
                }
            }
        }
        .navigationTitle("제스처 연습")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

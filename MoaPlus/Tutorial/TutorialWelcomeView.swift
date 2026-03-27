import SwiftUI

struct TutorialWelcomeView: View {
    let stage: TutorialStage
    let onStart: () -> Void

    private let accentBlue = Color(red: 0.26, green: 0.38, blue: 0.93)

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "hand.draw")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            Text(stage.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(stage.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let tip = stage.tip {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text(tip)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )
                .padding(.horizontal, 20)
            }

            Spacer()

            Button(action: onStart) {
                Text("시작하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentBlue)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

import SwiftUI

struct TutorialCompletionView: View {
    let onRestart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var freeText: String = ""
    @FocusState private var isFocused: Bool

    private let accentBlue = Color(red: 0.26, green: 0.38, blue: 0.93)

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text("준비 완료!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("모아+ 제스처를 마스터하셨습니다.\n자유롭게 입력해 보세요.")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            TextEditor(text: $freeText)
                .font(.system(size: 18))
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .foregroundColor(.white)
                .focused($isFocused)
                .padding(.horizontal, 16)

            // Tip
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                Text("처음엔 느려도 며칠이면 익숙해집니다. 설정에서 단축어를 등록하면 더 빠르게 입력할 수 있어요.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.1))
            )
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Button(action: onRestart) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("다시 연습")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.3), lineWidth: 1.5)
                    )
                }

                Button {
                    dismiss()
                } label: {
                    Text("완료")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(accentBlue)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

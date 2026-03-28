import SwiftUI

struct TypingPracticeView: View {
    let item: TypingPracticeItem
    @State private var currentLineIndex: Int = 0
    @State private var inputText: String = ""
    @State private var completedLines: Int = 0
    @State private var isComplete: Bool = false
    @FocusState private var isInputFocused: Bool

    private var currentLine: String {
        guard currentLineIndex < item.lines.count else { return "" }
        return item.lines[currentLineIndex]
    }

    private var progress: Double {
        Double(completedLines) / Double(item.lines.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            ProgressView(value: progress)
                .tint(.accentColor)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if isComplete {
                completionView
            } else {
                practiceContent
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
        }
    }

    // MARK: - Practice Content

    private var practiceContent: some View {
        VStack(spacing: 20) {
            Spacer()

            // Author & progress
            HStack {
                Text(item.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(currentLineIndex + 1) / \(item.lines.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            // Target text with character coloring
            HStack(spacing: 0) {
                ForEach(Array(currentLine.enumerated()), id: \.offset) { idx, char in
                    Text(String(char))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(charColor(at: idx))
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Input field
            TextField("여기에 입력하세요", text: $inputText)
                .font(.system(size: 20))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 24)
                .focused($isInputFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: inputText) { _ in
                    checkLineCompletion()
                }

            // Keyboard switch hint
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                Text("🌐 버튼으로 모아키 키보드로 전환하세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("연습 완료!")
                .font(.title2)
                .fontWeight(.bold)

            Text("\"\(item.title)\" 전체를 입력했습니다")
                .font(.body)
                .foregroundColor(.secondary)

            Button {
                restart()
            } label: {
                Text("다시 연습하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func charColor(at index: Int) -> Color {
        guard index < inputText.count else {
            return Color(.label)  // Not yet typed
        }
        let inputIdx = inputText.index(inputText.startIndex, offsetBy: index)
        let targetIdx = currentLine.index(currentLine.startIndex, offsetBy: index)
        if inputText[inputIdx] == currentLine[targetIdx] {
            return .green  // Correct
        } else {
            return .red  // Wrong
        }
    }

    private func checkLineCompletion() {
        if inputText == currentLine {
            completedLines += 1
            if currentLineIndex + 1 < item.lines.count {
                currentLineIndex += 1
                inputText = ""
            } else {
                isComplete = true
                isInputFocused = false
            }
        }
    }

    private func restart() {
        currentLineIndex = 0
        completedLines = 0
        inputText = ""
        isComplete = false
        isInputFocused = true
    }
}

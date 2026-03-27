import SwiftUI

struct CharacterComparisonView: View {
    let target: String
    let states: [TutorialViewModel.CharacterState]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(target.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.system(size: 28, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(color(for: index))
            }
        }
    }

    private func color(for index: Int) -> Color {
        guard index < states.count else { return Color(.label).opacity(0.3) }
        switch states[index] {
        case .pending:
            return Color(.label).opacity(0.3)
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .composing:
            return Color.accentColor
        }
    }
}

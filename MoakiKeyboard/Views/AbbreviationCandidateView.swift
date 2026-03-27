import SwiftUI

/// Abbreviation candidate bar displayed above the keyboard
struct AbbreviationCandidateView: View {
    let trigger: String
    let replacement: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Trigger label
            Text(trigger)
                .font(.system(size: 13))
                .foregroundColor(Color(.secondaryLabel))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .cornerRadius(4)

            Image(systemName: "arrow.right")
                .font(.system(size: 11))
                .foregroundColor(Color(.tertiaryLabel))

            // Replacement preview - tappable to confirm
            Button(action: onConfirm) {
                Text(replacement)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(.secondarySystemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        AbbreviationCandidateView(
            trigger: "ㅎㅅㅁㅇ",
            replacement: "koh@move.kr",
            onConfirm: {},
            onDismiss: {}
        )
        Spacer()
    }
}

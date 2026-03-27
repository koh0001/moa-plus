import SwiftUI

/// Abbreviation candidate bar displayed above the keyboard
/// Supports single or multiple candidates
struct AbbreviationCandidateView: View {
    let trigger: String
    let candidates: [ShortcutExpansion]
    let onConfirm: (ShortcutExpansion) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Trigger label
            Text(trigger)
                .font(.system(size: 13))
                .foregroundColor(Color(.secondaryLabel))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .cornerRadius(4)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(Color(.tertiaryLabel))

            // Candidate buttons (scrollable if multiple)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(candidates) { expansion in
                        Button(action: { onConfirm(expansion) }) {
                            Text(expansion.replacement)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                }
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 8)
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

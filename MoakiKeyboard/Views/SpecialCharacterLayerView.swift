import SwiftUI

/// Special character categories
enum SpecialCharCategory: String, CaseIterable {
    case numbers    = "숫자"
    case basic      = "기본"
    case developer  = "개발"
    case brackets   = "괄호"

    var characters: [[String]] {
        switch self {
        case .numbers:
            return [
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
            ]
        case .basic:
            return [
                ["!", "?", ".", ",", ":", ";"],
                ["@", "#", "%", "&", "+", "-"],
                ["=", "_", "/", "\\", "|", "~"],
            ]
        case .developer:
            return [
                ["{", "}", "<", ">", "[", "]"],
                ["(", ")", "'", "\"", "`", "^"],
                ["→", "←", "↑", "↓", "•", "※"],
            ]
        case .brackets:
            return [
                ["(", ")", "[", "]", "{", "}"],
                ["<", ">", "「", "」", "『", "』"],
                ["《", "》", "【", "】", "〔", "〕"],
            ]
        }
    }
}

/// Special character layer view
struct SpecialCharacterLayerView: View {
    @State private var selectedCategory: SpecialCharCategory = .numbers
    let onCharacterTap: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Category tabs
            categoryTabs

            // Character grid
            characterGrid
                .padding(.horizontal, 4)
                .padding(.vertical, 8)

            // Dismiss bar
            dismissBar
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ForEach(SpecialCharCategory.allCases, id: \.self) { category in
                Button(action: { selectedCategory = category }) {
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: selectedCategory == category ? .semibold : .regular))
                        .foregroundColor(selectedCategory == category ? .accentColor : Color(.secondaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                            ? Color(.systemBackground)
                            : Color.clear
                        )
                        .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: - Character Grid

    private var characterGrid: some View {
        VStack(spacing: 6) {
            ForEach(selectedCategory.characters.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(selectedCategory.characters[rowIndex], id: \.self) { char in
                        Button(action: { onCharacterTap(char) }) {
                            Text(char)
                                .font(.system(size: 18))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color(.systemBackground))
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                        }
                        .foregroundColor(Color(.label))
                    }
                }
            }
        }
    }

    // MARK: - Dismiss Bar

    private var dismissBar: some View {
        HStack {
            Button(action: onDismiss) {
                Text("닫기")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            Spacer()
            // Recently used characters could go here in future
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

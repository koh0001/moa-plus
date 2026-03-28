import SwiftUI

struct TypingPracticeListView: View {
    @State private var selectedCategory: PracticeCategory?

    private var filteredItems: [TypingPracticeItem] {
        if let cat = selectedCategory {
            return TypingPracticeContent.items.filter { $0.category == cat }
        }
        return TypingPracticeContent.items
    }

    var body: some View {
        List {
            // Category filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("전체", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(PracticeCategory.allCases, id: \.self) { cat in
                            filterChip(cat.rawValue, icon: cat.icon, isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // Practice items
            Section {
                ForEach(filteredItems) { item in
                    NavigationLink(destination: TypingPracticeView(item: item)) {
                        HStack(spacing: 12) {
                            Image(systemName: item.category.icon)
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.headline)
                                HStack(spacing: 4) {
                                    Text(item.author)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("·")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(item.lines.count)줄")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("\(filteredItems.count)개 연습")
            }
        }
        .navigationTitle("자판 연습")
    }

    private func filterChip(_ label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : Color(.label))
        }
    }
}

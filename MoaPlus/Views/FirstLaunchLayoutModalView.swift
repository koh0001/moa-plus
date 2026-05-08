import SwiftUI

struct FirstLaunchLayoutModalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 12)

            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("키보드 모드를 선택하세요")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("v1.4 부터 키보드 레이아웃을 선택할 수 있습니다.\n이전 1.1 레이아웃을 좋아하셨나요?")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                ChoiceCard(
                    title: "모던 (현재)",
                    subtitle: "우측에 모음 키 ㅣ ㅡ ㆍ + 백스페이스 위쪽",
                    preview: ModernPreviewMini(),
                    onSelect: applyModern
                )
                ChoiceCard(
                    title: "클래식 1.1",
                    subtitle: "! ? . + 가로 백스페이스. 모음 키 없음.",
                    preview: ClassicPreviewMini(),
                    onSelect: applyClassic
                )
            }

            Button("나중에") {
                markShown()
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding(.top, 4)

            Spacer()

            Text("언제든 설정 → 키보드 → 레이아웃에서 변경 가능")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .onDisappear { markShown() }
    }

    private func applyModern() {
        // Defaults already match modern (A1 + B2 + default C)
        settings.layoutCustomization = LayoutCustomization()
        markShown()
        dismiss()
    }

    private func applyClassic() {
        var c = LayoutCustomization()
        c.slotA = .classic11
        c.slotB = .vowelKey
        settings.layoutCustomization = c
        markShown()
        dismiss()
    }

    private func markShown() {
        if !settings.firstLaunchModalShown {
            settings.firstLaunchModalShown = true
        }
    }
}

private struct ChoiceCard<Preview: View>: View {
    let title: String
    let subtitle: String
    let preview: Preview
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                preview
                    .frame(width: 90, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

/// Mini preview of A1 (modern) layout.
private struct ModernPreviewMini: View {
    var body: some View {
        SimpleKeyboardSketch(
            rows: [
                ["~", "ㅃ", "ㅉ", "ㄸ", "ㄲ", "ㅆ", "#"],
                ["^", "ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "⌫"],
                [";", "ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅣ"],
                ["*", "ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅡ", "ㆍ"],
            ],
            highlightLast: false
        )
    }
}

/// Mini preview of A2 (classic 1.1) layout.
private struct ClassicPreviewMini: View {
    var body: some View {
        SimpleKeyboardSketch(
            rows: [
                ["~", "ㅃ", "ㅉ", "ㄸ", "ㄲ", "ㅆ", "!"],
                ["^", "ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "?"],
                [";", "ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "."],
                ["*", "ㅋ", "ㅌ", "ㅊ", "ㅍ", "⌫⌫", ""],
            ],
            highlightLast: true
        )
    }
}

/// Tiny visual sketch (not the real KeyboardView). Avoids triggering the
/// keyboard extension's full setup just for two thumbnails.
private struct SimpleKeyboardSketch: View {
    let rows: [[String]]
    /// If true, treat row 3 col 5 as a wide cell that absorbs col 6 (no col 6 cell).
    let highlightLast: Bool

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 1.5
            let cols = 7
            let cellW = (geo.size.width - spacing * CGFloat(cols + 1)) / CGFloat(cols)
            let rowsCount = rows.count
            let cellH = (geo.size.height - spacing * CGFloat(rowsCount + 1)) / CGFloat(rowsCount)

            VStack(spacing: spacing) {
                ForEach(0..<rowsCount, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(0..<rows[r].count, id: \.self) { c in
                            let label = rows[r][c]
                            if label.isEmpty {
                                EmptyView()
                            } else {
                                let isWide = highlightLast && r == rowsCount - 1 && label == "⌫⌫"
                                Text(isWide ? "⌫" : label)
                                    .font(.system(size: 6, weight: .medium))
                                    .frame(width: isWide ? cellW * 2 + spacing : cellW, height: cellH)
                                    .background(
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(Color(.systemBackground))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(spacing)
            .background(Color(.systemGray5))
        }
    }
}

#Preview {
    FirstLaunchLayoutModalView()
}

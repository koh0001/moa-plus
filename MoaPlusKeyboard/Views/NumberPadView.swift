import SwiftUI

/// 아이패드 가로 분리 레이아웃의 숫자패드(계산기식 3×4).
/// 키 탭은 KeyboardViewModel 의 기존 입력 경로(inputSymbol / 백스페이스)로 흐른다.
struct NumberPadView: View {
    let panelWidth: CGFloat
    let keyHeight: CGFloat
    let onDigit: (String) -> Void
    let onBackspacePressStart: () -> Void
    let onBackspacePressEnd: () -> Void

    @ObservedObject private var settings = KeyboardSettings.shared

    private var keyWidth: CGFloat {
        let spacing = KeyboardMetrics.keySpacing
        return (panelWidth - spacing * 2) / 3
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.keySpacing) {
            ForEach(Array(KeyboardMetrics.numberPadKeys.enumerated()), id: \.offset) { _, row in
                HStack(spacing: KeyboardMetrics.keySpacing) {
                    ForEach(row, id: \.self) { key in
                        keyView(for: key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(for key: String) -> some View {
        let theme = settings.themeSettings
        if key == KeyboardMetrics.numberPadBackspaceLabel {
            Text(key)
                .font(.system(size: 22))
                .frame(width: keyWidth, height: keyHeight)
                .background(RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(theme.resolvedFunctionKeyBackground)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1))
                .foregroundColor(theme.resolvedKeyText)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                    if pressing { onBackspacePressStart() } else { onBackspacePressEnd() }
                }, perform: {})
        } else {
            Button(action: { onDigit(key) }) {
                Text(key)
                    .font(.system(size: 22))
                    .frame(width: keyWidth, height: keyHeight)
                    .background(RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                        .fill(theme.resolvedKeyBackground)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1))
                    .foregroundColor(theme.resolvedKeyText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

import SwiftUI

struct GestureOverlayView: View {
    let directions: [GestureDirection]
    let startPoint: CGPoint?
    let currentVowel: Jungseong?

    var body: some View {
        GeometryReader { geometry in
            if let start = startPoint, !directions.isEmpty {
                ZStack {
                    // Direction indicator text
                    VStack(spacing: 4) {
                        // 화살표가 많아도 한 줄·고정 폭으로 — 길어져서 미리보기
                        // 박스가 화면을 침범하지 않게 최근 8개만, 축소 허용.
                        Text(directions.suffix(8).map { $0.symbol }.joined())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        if let vowel = currentVowel {
                            Text(String(vowel.compatibilityCharacter))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: 240)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.9))
                            .shadow(radius: 2)
                    )
                    .position(indicatorPosition(start: start, in: geometry.size))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func indicatorPosition(start: CGPoint, in size: CGSize) -> CGPoint {
        let overlayHeight: CGFloat = 80

        // Vertical: upper half → below, lower half → above (keep existing rule)
        let y: CGFloat
        if start.y < size.height * 0.45 {
            y = start.y + overlayHeight
        } else {
            y = start.y - overlayHeight
        }

        // Horizontal: render on the opposite half so the user's finger
        // never covers the preview. Left half touch → anchor at 75% width
        // (right half), right half touch → anchor at 25% width (left half).
        let isOnLeft = start.x < size.width / 2
        let x: CGFloat = isOnLeft ? size.width * 0.75 : size.width * 0.25

        return CGPoint(
            x: max(50, min(size.width - 50, x)),
            y: max(40, min(size.height - 40, y))
        )
    }
}

#Preview {
    ZStack {
        Color(.systemGray6)

        GestureOverlayView(
            directions: [.up, .right],
            startPoint: CGPoint(x: 150, y: 200),
            currentVowel: .ㅘ
        )
    }
    .frame(width: 300, height: 300)
}

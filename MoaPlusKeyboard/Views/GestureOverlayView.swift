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
                        Text(directions.map { $0.symbol }.joined())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.blue)

                        if let vowel = currentVowel {
                            Text(String(vowel.compatibilityCharacter))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
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
        let overlayWidth: CGFloat = 80

        // Vertical: upper half → below, lower half → above
        let y: CGFloat
        if start.y < size.height * 0.45 {
            y = start.y + overlayHeight
        } else {
            y = start.y - overlayHeight
        }

        // Horizontal: left edge → push right, right edge → push left
        let x: CGFloat
        if start.x < size.width * 0.25 {
            x = start.x + overlayWidth
        } else if start.x > size.width * 0.75 {
            x = start.x - overlayWidth
        } else {
            x = start.x
        }

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

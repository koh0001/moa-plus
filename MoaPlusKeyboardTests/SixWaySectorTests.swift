import XCTest
import CoreGraphics
@testable import MoaPlusKeyboard

/// 6방향 60° 균등 프리셋 (사용자 메일 제안) + 프리셋 피커가 섹터를 실제로 적용하는지.
///
/// 분류기는 바꾸지 않고 섹터 데이터(비대칭 좌우 폭)만으로 60° 타일링을 만든다.
/// 이 가드가 깨지면 `GestureDirection.from` 의 STEP1/STEP2 우선순위가 바뀐 것이다.
final class SixWaySectorTests: XCTestCase {

    // MARK: - 전수 스윕

    /// 0.25°, 1.25°, … 359.25° — 6방향 경계(정수 각도)와 8방향 경계(x.5°)를 모두 피해
    /// 섹터마다 정확히 60개(6방향) / 45개(8방향)가 나와야 한다.
    private func sweep(_ sectors: [DirectionSector], fillGap: Bool = true) -> [GestureDirection: Int] {
        var counts: [GestureDirection: Int] = [:]
        for k in 0..<360 {
            let deg = Double(k) + 0.25
            let rad = deg * .pi / 180
            // iOS 좌표계: y 가 아래로 증가 → 위쪽 성분은 음수.
            let v = CGVector(dx: cos(rad) * 100, dy: -sin(rad) * 100)
            guard let d = GestureDirection.from(vector: v, sectors: sectors, rotationOffset: 0,
                                                threshold: 1, fillGap: fillGap) else { continue }
            counts[d, default: 0] += 1
        }
        return counts
    }

    func test_sixWayRight_tilesSixSixtyDegreeSectors() {
        for fillGap in [true, false] {
            let c = sweep(DirectionSector.sixWayRightSectors, fillGap: fillGap)
            for d in [GestureDirection.right, .upRight, .up, .left, .downLeft, .down] {
                XCTAssertEqual(c[d], 60, "\(d) 는 60° (fillGap=\(fillGap))")
            }
            XCTAssertNil(c[.upLeft], "↖ 는 꺼짐")
            XCTAssertNil(c[.downRight], "↘ 는 꺼짐")
        }
    }

    func test_sixWayLeft_tilesSixSixtyDegreeSectors() {
        for fillGap in [true, false] {
            let c = sweep(DirectionSector.sixWayLeftSectors, fillGap: fillGap)
            for d in [GestureDirection.right, .upLeft, .up, .left, .downRight, .down] {
                XCTAssertEqual(c[d], 60, "\(d) 는 60° (fillGap=\(fillGap))")
            }
            XCTAssertNil(c[.upRight], "↗ 는 꺼짐")
            XCTAssertNil(c[.downLeft], "↙ 는 꺼짐")
        }
    }

    /// 열별 ㅣ/ㅡ 보정은 ↖(3)·↘(7) 에도 폭을 더한다. 끈 대각선이 되살아나지 않아야 한다.
    func test_sixWayRight_columnDiagonalDeltasDoNotReviveDisabledDiagonals() {
        let widened = DirectionSector.sixWayRightSectors.applyingDiagonalDeltas(iDelta: 10, euDelta: 10)
        let c = sweep(widened)
        XCTAssertNil(c[.upLeft])
        XCTAssertNil(c[.downRight])
    }

    /// 기본 8방향 배치는 바뀌지 않는다 (회귀 가드).
    func test_defaultSectors_stillEightFortyFive() {
        let c = sweep(DirectionSector.defaultSectors)
        for d in GestureDirection.allCases {
            XCTAssertEqual(c[d], 45, "\(d)")
        }
    }

    // MARK: - 프리셋 적용

    func test_applyingPreset_writesSectorsAndKeepsOtherFields() {
        var p = SwipeProfile.bothHands
        p.swipeLength = .long
        p.upRightMapping = .vowelA
        p.axisRotation = 5
        p.gapFillNearest = false

        let six = p.applyingPreset(.sixWayRight)
        XCTAssertEqual(six.mode, .sixWayRight)
        XCTAssertEqual(six.sectors, DirectionSector.sixWayRightSectors)
        XCTAssertEqual(six.swipeLength, .long)
        XCTAssertEqual(six.upRightMapping, .vowelA)
        XCTAssertEqual(six.axisRotation, 5)
        XCTAssertFalse(six.gapFillNearest)
    }

    /// v2.2.2 까지 오른손/왼손 프리셋은 라벨만 바꾸고 섹터는 기본값 그대로였다.
    func test_applyingPreset_rightAndLeftActuallyChangeSectors() {
        XCTAssertEqual(SwipeProfile.bothHands.applyingPreset(.right).sectors, SwipeProfile.rightHand.sectors)
        XCTAssertEqual(SwipeProfile.bothHands.applyingPreset(.left).sectors, SwipeProfile.leftHand.sectors)
        XCTAssertNotEqual(SwipeProfile.rightHand.sectors, DirectionSector.defaultSectors)
    }

    func test_applyingPreset_bothRestoresDefault_customKeepsCurrent() {
        let six = SwipeProfile.bothHands.applyingPreset(.sixWayLeft)
        XCTAssertEqual(six.applyingPreset(.both).sectors, DirectionSector.defaultSectors)
        XCTAssertEqual(six.applyingPreset(.custom).sectors, DirectionSector.sixWayLeftSectors)
        XCTAssertEqual(six.applyingPreset(.custom).mode, .custom)
    }

    func test_sixWayMode_roundTripsThroughJSON() throws {
        let p = SwipeProfile.bothHands.applyingPreset(.sixWayRight)
        let decoded = try JSONDecoder().decode(SwipeProfile.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded, p)
    }

    // MARK: - E2E (분석기 + 리졸버)

    /// 꼭짓점 사이를 4pt 간격으로 채워 분석기에 넣고 모음을 돌려준다.
    private func vowel(_ mode: SwipeMode, strokes: [(dx: CGFloat, dy: CGFloat)]) -> Jungseong? {
        var settings = GestureSettings.default
        settings.swipeProfile = SwipeProfile.bothHands.applyingPreset(mode)
        let analyzer = GestureAnalyzer(settings: settings, columnId: 2)
        var p = CGPoint(x: 200, y: 200)
        analyzer.addPoint(p)
        for s in strokes {
            let steps = max(1, Int((hypot(s.dx, s.dy) / 4).rounded()))
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                analyzer.addPoint(CGPoint(x: p.x + s.dx * t, y: p.y + s.dy * t))
            }
            p = CGPoint(x: p.x + s.dx, y: p.y + s.dy)
        }
        let detail = analyzer.finalizeGestureDetailed()
        let resolver = VowelResolver()
        resolver.swipeProfile = settings.swipeProfile
        return resolver.resolve(directions: detail.directions,
                                firstStrokeCardinal: detail.firstStrokeCardinal).vowel
    }

    /// 각도(수학 좌표) → 획 벡터.
    private func stroke(_ deg: Double, _ len: CGFloat = 60) -> (dx: CGFloat, dy: CGFloat) {
        let r = deg * .pi / 180
        return (len * CGFloat(cos(r)), -len * CGFloat(sin(r)))
    }

    func test_e2e_sixWayRight_widerIAndO() {
        // 70°: ↗(ㅣ) 범위(15~75°) 안쪽.
        XCTAssertEqual(vowel(.sixWayRight, strokes: [stroke(70)]), .ㅣ)
        // 128°: 8방향이면 ↖(ㅣ) 이지만 6방향 오른손형에서는 ↑(ㅗ) 범위(75~135°).
        XCTAssertEqual(vowel(.sixWayRight, strokes: [stroke(128)]), .ㅗ)
        // 320°: 8방향이면 ↘(ㅡ) 이지만 6방향 오른손형에서는 →(ㅏ) 범위(315~15°).
        XCTAssertEqual(vowel(.sixWayRight, strokes: [stroke(320)]), .ㅏ)
    }

    func test_e2e_sixWayLeft_mirror() {
        XCTAssertEqual(vowel(.sixWayLeft, strokes: [stroke(110)]), .ㅣ)
        XCTAssertEqual(vowel(.sixWayLeft, strokes: [stroke(52)]), .ㅗ)
        XCTAssertEqual(vowel(.sixWayLeft, strokes: [stroke(290)]), .ㅡ)
    }

    /// 제보자 요청: "6방향으로 줄이더라도 복모음 조합은 유지".
    func test_e2e_compoundVowelsSurviveBothSixWayPresets() {
        for mode in [SwipeMode.sixWayRight, .sixWayLeft] {
            XCTAssertEqual(vowel(mode, strokes: [stroke(90, 40), stroke(0, 40)]), .ㅘ, "↑→ \(mode)")
            XCTAssertEqual(vowel(mode, strokes: [stroke(270, 40), stroke(180, 40)]), .ㅝ, "↓← \(mode)")
            XCTAssertEqual(vowel(mode, strokes: [stroke(0, 40), stroke(180, 40)]), .ㅐ, "→← \(mode)")
            XCTAssertEqual(vowel(mode, strokes: [stroke(180, 40), stroke(0, 40)]), .ㅔ, "←→ \(mode)")
            XCTAssertEqual(vowel(mode, strokes: [stroke(90, 40), stroke(270, 40)]), .ㅚ, "↑↓ \(mode)")
        }
    }

    /// ㅢ 는 남은 대각선 쌍의 왕복으로 들어간다 — 오른손형 ↙↗, 왼손형 ↘↖.
    func test_e2e_euiThroughRemainingDiagonalPair() {
        XCTAssertEqual(vowel(.sixWayRight, strokes: [stroke(225, 40), stroke(45, 40)]), .ㅢ)
        XCTAssertEqual(vowel(.sixWayLeft, strokes: [stroke(315, 40), stroke(135, 40)]), .ㅢ)
    }
}

import XCTest

final class GestureAnalyzerTests: XCTestCase {

    // MARK: - Reversal Threshold Tests

    func testReversalDetectedAtLowerThreshold() {
        // With reversalThreshold=10, opposite direction change should be detected at 10px
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Start at origin, move up 25px (above threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up (iOS y-axis: lower y = up)

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Now reverse down by only 12px from direction change point (above reversal=10, below threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 87))  // 12px down from y=75

        XCTAssertEqual(analyzer.getDirections(), [.up, .down], "Opposite reversal should be detected at reversal threshold (10px)")
    }

    func testNonReversalRequiresFullThreshold() {
        // Non-opposite direction changes should still require the full threshold
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Start at origin, move up 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Try to move right by only 12px (non-opposite direction, below threshold=20)
        analyzer.addPoint(CGPoint(x: 112, y: 75))  // 12px right from direction change point

        XCTAssertEqual(analyzer.getDirections(), [.up], "Non-opposite direction change should require full threshold")
    }

    func testTripleReversalForYoVowel() {
        // Simulate ㅛ gesture: up → down → up with small amplitude
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // First direction: up 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 25px up

        XCTAssertEqual(analyzer.getDirections(), [.up])

        // Second direction (reversal): down 12px
        analyzer.addPoint(CGPoint(x: 100, y: 87))  // 12px down from y=75

        XCTAssertEqual(analyzer.getDirections(), [.up, .down])

        // Third direction (reversal): up 12px
        analyzer.addPoint(CGPoint(x: 100, y: 75))  // 12px up from y=87

        let finalDirs = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirs, [.up, .down, .up], "Triple reversal should produce ㅛ pattern (↑↓↑)")
    }

    func testTripleReversalForYuVowel() {
        // Simulate ㅠ gesture: down → up → down with small amplitude
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // First direction: down 25px
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 125))  // 25px down

        XCTAssertEqual(analyzer.getDirections(), [.down])

        // Second direction (reversal): up 12px
        analyzer.addPoint(CGPoint(x: 100, y: 113))  // 12px up from y=125

        XCTAssertEqual(analyzer.getDirections(), [.down, .up])

        // Third direction (reversal): down 12px
        analyzer.addPoint(CGPoint(x: 100, y: 125))  // 12px down from y=113

        let finalDirs = analyzer.finalizeGesture()
        XCTAssertEqual(finalDirs, [.down, .up, .down], "Triple reversal should produce ㅠ pattern (↓↑↓)")
    }

    func testFirstDirectionAlwaysRequiresFullThreshold() {
        // First direction should always need the full threshold, never reversal threshold
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        // Move only 12px (above reversal=10 but below threshold=20)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 88))  // 12px up

        XCTAssertEqual(analyzer.getDirections(), [], "First direction should require full threshold")
    }

    // MARK: - Finalize Gesture Normalization Tests

    func testFinalizeKeepsMeaningfulMiddleDiagonalForThreeStrokeTurn() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 126))   // ↓
        analyzer.addPoint(CGPoint(x: 122, y: 148))   // ↘
        analyzer.addPoint(CGPoint(x: 96, y: 148))    // ←

        XCTAssertEqual(analyzer.getDirections(), [.down, .downRight, .left])
        XCTAssertEqual(analyzer.finalizeGesture(), [.down, .downRight, .left])
    }

    func testTinyDiagonalJitterInVerticalStrokeIsAbsorbed() {
        // A small ↗ wobble inside an otherwise vertical stroke must be
        // treated as motor noise — not as the start of a compound vowel.
        // This mirrors the user-facing "고도조소 → 과솨롸와" report:
        // intent is ㅗ, finger drift drags the stroke a few degrees off
        // vertical, the analyzer must keep the gesture as a single ↑.
        // Larger, intentional ↗ turns are still recognised — see
        // `testPronouncedDiagonalTurnIsPreserved`.
        let analyzer = GestureAnalyzer(threshold: 8, reversalThreshold: 6, directionChangeThreshold: 8)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 70))    // ↑ 30px
        analyzer.addPoint(CGPoint(x: 109, y: 61))    // ~9px diagonal wobble (≈45°)
        analyzer.addPoint(CGPoint(x: 109, y: 45))    // back to ↑

        XCTAssertEqual(
            analyzer.finalizeGesture(),
            [.up],
            "정수직 stroke 안의 작은 ↗ 흔들림은 ↑로 흡수되어야 한다 (ㅗ→ㅘ 오인식 방지)"
        )
    }

    func testPronouncedDiagonalTurnIsPreserved() {
        // When the second stroke is unambiguously diagonal (clearly past
        // the ↑ sector), the analyzer must record both segments so
        // compound vowels like ㅢ (↘↑) or downstream resolvers can fold
        // them correctly.
        let analyzer = GestureAnalyzer(threshold: 8, reversalThreshold: 6, directionChangeThreshold: 8)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 70))    // ↑ 30px
        analyzer.addPoint(CGPoint(x: 140, y: 30))    // clear ↗ ~45° (40px right, 40px up)

        XCTAssertEqual(analyzer.finalizeGesture().first, .up)
        XCTAssertGreaterThanOrEqual(analyzer.finalizeGesture().count, 2,
                                    "명확한 ↗ 턴은 두 stroke 로 보존되어야 한다")
    }

    func testFinalizeKeepsDownRightLeftSequenceForWePattern() {
        let analyzer = GestureAnalyzer(threshold: 20, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 128))   // ↓
        analyzer.addPoint(CGPoint(x: 124, y: 152))   // ↘
        analyzer.addPoint(CGPoint(x: 98, y: 152))    // ←

        XCTAssertEqual(analyzer.finalizeGesture(), [.down, .downRight, .left])
    }

    // MARK: - Vertical Stroke Stability (ㅗ → ㅘ 오인식 방지)

    /// 정수직 ↑ 끝부분이 약 10–15° 휘어 감기는 자연스러운 손 움직임은
    /// 단일 [.up] 으로 유지되어야 한다 ("고도조소" 입력 시 ↗ 가 추가로 잡혀
    /// `[.up, .upRight]` → ㅘ 로 폴드되는 현상을 막는 회귀 테스트).
    func testNearVerticalCurveWithMildEndDriftStaysAsUp() {
        let analyzer = GestureAnalyzer(threshold: 30, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 70))   // up 30px → ↑ 등록
        analyzer.addPoint(CGPoint(x: 100, y: 30))   // 계속 ↑ (lastChangePoint=(100,70) 유지)
        analyzer.addPoint(CGPoint(x: 110, y: 22))   // 끝 휨: vec from (100,70)=(10,-48), angle≈78°

        let final = analyzer.finalizeGesture()
        XCTAssertEqual(
            final,
            [.up],
            "정수직 위 + 끝부분 ~12° 휨은 단일 ↑ stroke 로 유지되어야 함 (ㅗ → ㅘ 오인식 방지)"
        )
    }

    /// 의도적 ㅘ 입력(↑ 후 명확히 →)은 여전히 [.up, .upRight] 또는 [.up, .right]
    /// 으로 두 stroke 잡혀야 한다.
    func testIntentionalRightTurnStillProducesTwoStrokes() {
        let analyzer = GestureAnalyzer(threshold: 30, reversalThreshold: 10, directionChangeThreshold: 15)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 60))   // up 40 → ↑
        analyzer.addPoint(CGPoint(x: 145, y: 55))   // 명확한 우향 turn (45px right, 5px up)

        let final = analyzer.finalizeGesture()
        XCTAssertEqual(final.first, .up, "첫 stroke 는 ↑")
        XCTAssertGreaterThanOrEqual(final.count, 2, "의도적 우향 turn 은 두 stroke 로 인식")
        XCTAssertTrue(
            final.last == .right || final.last == .upRight,
            "두 번째 stroke 는 → 또는 ↗ (둘 다 normalize 후 ㅘ 매칭)"
        )
    }

    // MARK: - Edge Column Diagonal Recognition (5열 ↗→ㅣ, 1열 ↖→ㅣ)

    /// 5열에서 ↗ stroke (대각선 오른쪽위) 를 ㅣ 로 의도한 swipe 가 ↑ 로 빠져
    /// `[.up, .upRight]` → ㅘ 가 되는 회귀를 막는 테스트.
    /// 새 default override (col 5: rotation -3°, iDelta 5°) 로 ~69° 까지의
    /// ↗ swipe 가 단일 ↗ stroke 로 보존되어야 한다.
    /// 75°+ 의 매우 가파른 ↗ 는 여전히 ↑ 로 분류된다 — 그 영역까지 ↗ 를
    /// 넓히면 ↗(ㅏ) 영역 침범이 생기므로 사용자가 굿기 테스트 슬라이더로
    /// 추가 튜닝하도록 둔다.
    func testColumn5SteepDiagonalStaysAsUpRight() {
        let analyzer = GestureAnalyzer(settings: .default, columnId: 5)

        // 시작점에서 (24, -60) 방향으로 swipe.
        // angle = atan2(60, 24) ≈ 68.2°. magnitude ≈ 64.6, threshold(default normal)=20.
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 124, y: 40))

        XCTAssertEqual(
            analyzer.finalizeGesture(),
            [.upRight],
            "5열의 ~68° ↗ swipe 는 단일 ↗ stroke 로 분류되어 ㅣ 매칭 (ㅘ 오인식 방지)"
        )
    }

    /// 1열에서 ↖ stroke 를 ㅣ 로 의도한 swipe 의 대칭 케이스.
    func testColumn1SteepDiagonalStaysAsUpLeft() {
        let analyzer = GestureAnalyzer(settings: .default, columnId: 1)

        // (-24, -60) → angle ≈ 180 - 68 = 111.8°.
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 76, y: 40))

        XCTAssertEqual(
            analyzer.finalizeGesture(),
            [.upLeft],
            "1열의 ~112° ↖ swipe 는 단일 ↖ stroke 로 분류되어 ㅣ 매칭"
        )
    }

    /// 5열에서도 정수직 ↑ 는 여전히 ↑ 로 분류되어 ㅗ 매칭 가능해야 한다.
    func testColumn5VerticalStaysAsUp() {
        let analyzer = GestureAnalyzer(settings: .default, columnId: 5)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 40))   // 정확한 ↑

        XCTAssertEqual(
            analyzer.finalizeGesture(),
            [.up],
            "5열의 정수직 ↑ 는 여전히 ↑ 로 분류 (ㅗ 매칭)"
        )
    }

    // MARK: - isOpposite Tests

    func testIsOpposite() {
        XCTAssertTrue(GestureDirection.up.isOpposite(to: .down))
        XCTAssertTrue(GestureDirection.down.isOpposite(to: .up))
        XCTAssertTrue(GestureDirection.left.isOpposite(to: .right))
        XCTAssertTrue(GestureDirection.right.isOpposite(to: .left))
        XCTAssertTrue(GestureDirection.upLeft.isOpposite(to: .downRight))
        XCTAssertTrue(GestureDirection.downRight.isOpposite(to: .upLeft))
        XCTAssertTrue(GestureDirection.upRight.isOpposite(to: .downLeft))
        XCTAssertTrue(GestureDirection.downLeft.isOpposite(to: .upRight))
    }

    func testIsNotOpposite() {
        XCTAssertFalse(GestureDirection.up.isOpposite(to: .right))
        XCTAssertFalse(GestureDirection.up.isOpposite(to: .upRight))
        XCTAssertFalse(GestureDirection.downRight.isOpposite(to: .upRight))
        XCTAssertFalse(GestureDirection.left.isOpposite(to: .downLeft))
    }
}

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

    // MARK: - Four-Way Mode (대각선 비활성 + 카디널 90° 자동 분할)

    /// 4방향 모드에서는 대각선 섹터가 사라지고 각 카디널이 90° (±45°) 를
    /// 차지한다. 8방향에서 ↗(ㅣ) 로 빠지던 55° 벡터가 4방향에서는 ↑(ㅗ)
    /// 로 스냅되어야 한다 — "ㅗ 각도 넓혀도 대각선이 먼저 먹어 적용 안 됨"
    /// 리포트의 근본 해결.
    func testFourWayModeSnaps55DegreeVectorToCardinalUp() {
        // 55°: dx=cos55·100, dy=-sin55·100 (iOS y축 반전 → 위쪽은 음수)
        let vector = CGVector(dx: 57.36, dy: -81.92)

        let eightWay = GestureDirection.from(
            vector: vector,
            sectors: DirectionSector.defaultSectors,
            rotationOffset: 0,
            threshold: 20
        )
        XCTAssertEqual(eightWay, .upRight, "기준: 8방향에서 55° 는 ↗ 대각선에 잡힌다")

        let fourWay = GestureDirection.from(
            vector: vector,
            sectors: DirectionSector.defaultSectors,
            rotationOffset: 0,
            threshold: 20,
            fourWay: true
        )
        XCTAssertEqual(fourWay, .up, "4방향 모드: 55° 는 대각선 없이 가장 가까운 카디널 ↑ 로 스냅")
    }

    /// 4방향 모드의 경계/카디널 정확성: 정확한 카디널은 그대로, 대각선
    /// 부근(예: 30° = ↗ 영역)도 가장 가까운 카디널로 흡수된다.
    func testFourWayModeCoversFullQuadrants() {
        let sectors = DirectionSector.defaultSectors
        func dir(_ deg: Double) -> GestureDirection? {
            let r = deg * .pi / 180
            return GestureDirection.from(
                vector: CGVector(dx: cos(r) * 100, dy: -sin(r) * 100),
                sectors: sectors, rotationOffset: 0, threshold: 20, fourWay: true
            )
        }
        XCTAssertEqual(dir(0), .right,  "0° → →")
        XCTAssertEqual(dir(30), .right, "30° (8방향이면 ↗) → 4방향에선 가까운 → 로 흡수")
        XCTAssertEqual(dir(90), .up,    "90° → ↑")
        XCTAssertEqual(dir(135 + 5), .left, "140° → ←")
        XCTAssertEqual(dir(270), .down, "270° → ↓")
    }

    /// 엔진 통합: fourWayMode 가 켜진 설정으로 분석하면 대각선 드리프트가
    /// 섞인 swipe 도 단일 카디널 stroke 로 정리된다.
    func testFourWayModeAnalyzerSnapsDiagonalDriftToCardinal() {
        var settings = GestureSettings.default
        settings.swipeProfile.fourWayMode = true
        let analyzer = GestureAnalyzer(settings: settings, columnId: 0)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 157, y: 18))  // ~55° (dx≈57, dy≈-82)

        XCTAssertEqual(
            analyzer.finalizeGesture(),
            [.up],
            "4방향 모드: 55° 드리프트도 단일 ↑ stroke 로 인식되어 ㅗ 매칭"
        )
    }

    /// fourWayMode 가 꺼진 기본 설정은 기존 8방향 동작을 그대로 유지한다
    /// (회귀 방지).
    func testEightWayModeUnchangedWhenFourWayDisabled() {
        let analyzer = GestureAnalyzer(settings: .default, columnId: 0)
        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 157, y: 18))  // ~55° → ↗
        XCTAssertEqual(
            analyzer.finalizeGesture(),
            [.upRight],
            "기본(8방향) 모드는 55° 를 여전히 ↗ 로 인식 (회귀 없음)"
        )
    }

    // MARK: - Forward-compatible SwipeProfile decoding

    /// fourWayMode 가 없던 구버전 JSON 도 디코딩되어야 하며, sectors 등
    /// 기존 값이 보존되고 fourWayMode 는 false 로 기본 적용되어야 한다.
    /// (없으면 `load(...) ?? .default` 가 전체 설정을 초기화한다.)
    func testLegacySwipeProfileJSONWithoutFourWayModeDecodes() throws {
        let json = Data("""
        {"mode":"both","swipeLength":"normal",
         "sectors":[{"centerAngle":0,"halfWidth":30}],
         "upLeftMapping":"vowelI","upRightMapping":"vowelI",
         "downLeftMapping":"vowelEu","downRightMapping":"vowelEu"}
        """.utf8)

        let profile = try JSONDecoder().decode(SwipeProfile.self, from: json)

        XCTAssertFalse(profile.fourWayMode, "구버전 JSON 은 fourWayMode 가 false 로 기본 적용")
        XCTAssertEqual(profile.sectors.first?.halfWidth, 30, "기존 sectors 값이 보존되어야 한다")
        XCTAssertEqual(profile.mode, .both)
    }

    // MARK: - Multi-stroke turn sensitivity (T4)
    //
    // sensitivity 0 = 기존 동작(원점 복귀 필요, ㅗㅜㅏㅓ 안정). 높일수록 큰 각도
    // turn 을 낮은 변위로 등록(⚡️ 궤적)하되 진폭 비율 가드로 단일 모음 과승격을 막는다.
    // 값: effectiveThreshold 20, effReversal 10, changeThreshold 15 (keyWidth 50).

    func testSensitivity0KeepsRightAngleTurnUnregistered() {
        var settings = GestureSettings.default
        settings.multiStrokeTurnSensitivity = 0
        let analyzer = GestureAnalyzer(settings: settings, columnId: 0)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))   // ↑ 25
        analyzer.addPoint(CGPoint(x: 112, y: 75))   // → 12 (gap 90, change 15 미달)

        XCTAssertEqual(analyzer.getDirections(), [.up],
                       "sens 0: 직각 12px turn 은 미등록 (기존 동작 보존)")
    }

    func testSensitivity2RegistersRightAngleTurnWithoutOriginReturn() {
        var settings = GestureSettings.default
        settings.multiStrokeTurnSensitivity = 2
        let analyzer = GestureAnalyzer(settings: settings, columnId: 0)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 75))   // ↑ 25
        analyzer.addPoint(CGPoint(x: 112, y: 75))   // → 12 (gap 90)

        XCTAssertEqual(analyzer.getDirections(), [.up, .right],
                       "sens 2: 직각 turn 이 12px 만으로 등록 (원점 복귀 불필요 ⚡️)")
    }

    func testSensitivity2AmplitudeGuardBlocksTinyJitterPromotion() {
        var settings = GestureSettings.default
        settings.multiStrokeTurnSensitivity = 2
        let analyzer = GestureAnalyzer(settings: settings, columnId: 0)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 60))   // ↑ 40 (의도적 ㅗ)
        analyzer.addPoint(CGPoint(x: 100, y: 72))   // ↓ 12 (40*0.4=16 미만 → 진폭가드 컷)

        XCTAssertEqual(analyzer.finalizeGesture(), [.up],
                       "sens 2: ㅗ 끝의 작은 떨림은 진폭 가드로 컷되어 ㅛ 과승격 방지")
    }

    func testSensitivity0RegistersTinyReversalLikeBefore() {
        var settings = GestureSettings.default
        settings.multiStrokeTurnSensitivity = 0
        let analyzer = GestureAnalyzer(settings: settings, columnId: 0)

        analyzer.addPoint(CGPoint(x: 100, y: 100))
        analyzer.addPoint(CGPoint(x: 100, y: 60))   // ↑ 40
        analyzer.addPoint(CGPoint(x: 100, y: 72))   // ↓ 12

        XCTAssertEqual(analyzer.getDirections(), [.up, .down],
                       "sens 0: 12px 반대 turn 은 그대로 등록 (진폭 가드 비활성 = 기존 동작)")
    }

    func testLegacyGestureSettingsJSONWithoutSensitivityDecodes() throws {
        let json = Data(#"{"swipeProfile":{"mode":"both"},"directionChangeThreshold":15,"reversalThresholdRatio":0.5}"#.utf8)
        let gs = try JSONDecoder().decode(GestureSettings.self, from: json)
        XCTAssertEqual(gs.multiStrokeTurnSensitivity, 0, "구버전 JSON 은 sensitivity 0 기본")
        XCTAssertEqual(gs.directionChangeThreshold, 15, "기존 필드 보존")
    }

    // MARK: - 자음 대각선 진입 후 후속 stroke 정확도 (referencePoint 분리 fix)
    //
    // 긴 대각선 진입 stroke(↗/↙) 뒤의 후속 카디널이 진입 방향에 흡수되거나
    // (↗→ → [.upRight]) 전환 중간에 유령 방향이 끼어드는(↙↑ → [.downLeft,.left,.up])
    // root cause 회귀 테스트. driveKeyMulti 와 동일한 8점 점열을 직접 주입한다.

    /// driveKeyMulti 와 동일: 시작점(100,100) + 각 stroke 4보간점.
    private func feedStrokes(_ analyzer: GestureAnalyzer, _ strokes: [(CGFloat, CGFloat)]) {
        var p = CGPoint(x: 100, y: 100)
        analyzer.addPoint(p)
        for s in strokes {
            for i in 1...4 {
                let f = CGFloat(i) / 4
                analyzer.addPoint(CGPoint(x: p.x + s.0 * f, y: p.y + s.1 * f))
            }
            p = CGPoint(x: p.x + s.0, y: p.y + s.1)
        }
    }

    func testConsonantDiagonalUpRightThenRightKeepsBothStrokes() {
        // col 4 (ㄱ): ↗ 70pt 진입 후 → 70pt. 후속 → 가 ↗ 에 흡수되지 않아야 한다.
        let analyzer = GestureAnalyzer(settings: .default, columnId: 4)
        feedStrokes(analyzer, [(70, -70), (70, 0)])
        XCTAssertEqual(
            analyzer.finalizeGesture(), [.upRight, .right],
            "↗ 진입 후 → 는 흡수되지 않고 별도 stroke (자음 대각선 ㅏ 파생)"
        )
    }

    func testConsonantDiagonalDownLeftThenUpHasNoPhantomLeft() {
        // col 4 (ㄱ): ↙ 70pt 진입 후 ↑ 70pt. 전환 중간에 유령 ← 가 끼지 않아야 한다.
        let analyzer = GestureAnalyzer(settings: .default, columnId: 4)
        feedStrokes(analyzer, [(-70, 70), (0, -70)])
        XCTAssertEqual(
            analyzer.finalizeGesture(), [.downLeft, .up],
            "↙ 진입 후 ↑ 전환에 유령 ← 가 끼지 않음 (ㅗ 파생, 기존 ↙←↑ 왜곡 제거)"
        )
    }

    func testConsonantDiagonalUpRightThenUpKeepsBothStrokes() {
        let analyzer = GestureAnalyzer(settings: .default, columnId: 4)
        feedStrokes(analyzer, [(70, -70), (0, -70)])
        XCTAssertEqual(
            analyzer.finalizeGesture(), [.upRight, .up],
            "↗ 진입 후 ↑ 는 별도 stroke (ㅕ 파생)"
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

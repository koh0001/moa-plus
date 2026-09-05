import XCTest

/// 이슈 #29 — ㅘ·ㅝ 직각 경로(↑→, ↓←)를 끄는 "세로 왕복 전용" 옵션.
///
/// 제보자 습관은 ㅗ = ↑ 한 번, ㅘ = ↑↓→ 인데, 위로 긋는 끝이 오른쪽 위로 흘러
/// ↗ 가 별도 획으로 등록되면 `normalizeTrailingStroke` 가 → 로 접어 `↑→=ㅘ` 로
/// 확정된다("모"→"뫄"). 기본값은 현재 방식 그대로 두고, 옵션을 켠 사용자만
/// 직각 경로를 잃는다 — 세로 왕복(↑↓→ 등)은 두 모드 모두에서 유지.
final class CompoundVowelPathTests: XCTestCase {

    // MARK: - 설정 디코딩 (수용 기준: 새 설정이 없는 기존 저장 데이터는 현재 방식)

    func test_legacyJSONWithoutCompoundVowelPath_decodesToRightAngleAndVertical() throws {
        let json = Data(#"{"swipeProfile":{"mode":"both"},"directionChangeThreshold":15}"#.utf8)
        let gs = try JSONDecoder().decode(GestureSettings.self, from: json)
        XCTAssertEqual(gs.compoundVowelPath, .rightAngleAndVertical,
                       "v2.2.0 이전 JSON 은 필드가 없으므로 현재 방식으로 폴백")
        XCTAssertEqual(gs.directionChangeThreshold, 15, "기존 필드 보존")
    }

    func test_compoundVowelPath_roundTripsThroughJSON() throws {
        var gs = GestureSettings()
        gs.compoundVowelPath = .verticalOnly
        let data = try JSONEncoder().encode(gs)
        let decoded = try JSONDecoder().decode(GestureSettings.self, from: data)
        XCTAssertEqual(decoded.compoundVowelPath, .verticalOnly)
    }

    func test_defaultGestureSettings_keepRightAnglePaths() {
        XCTAssertEqual(GestureSettings.default.compoundVowelPath, .rightAngleAndVertical,
                       "기본값을 바꾸면 업데이트만으로 기존 사용자의 ㅘ 경로가 사라진다")
        XCTAssertEqual(VowelResolver().compoundVowelPath, .rightAngleAndVertical)
    }

    // MARK: - VowelResolver (자음 키 / 슬롯 B 모음 키 트라이)

    private func resolver(_ path: CompoundVowelPath) -> VowelResolver {
        let r = VowelResolver()
        r.compoundVowelPath = path
        return r
    }

    func test_verticalOnly_upRight_staysO() {
        XCTAssertEqual(resolver(.verticalOnly).resolve(directions: [.up, .right]).vowel, .ㅗ)
    }

    /// 이슈 #29 제보 로그 `raw ↑86(89°) ↗33(74°) ⇒ ㅘ` 의 재현. 분석기가 넘긴
    /// [↑, ↗] 를 기본 모드는 → 로 접어 ㅘ, 세로 왕복 전용은 ㅗ 로 둔다.
    func test_verticalOnly_upThenUpRightTail_staysO() {
        XCTAssertEqual(resolver(.rightAngleAndVertical).resolve(directions: [.up, .upRight]).vowel, .ㅘ,
                       "기본 모드 회귀 가드 — 현재 동작 유지")
        XCTAssertEqual(resolver(.verticalOnly).resolve(directions: [.up, .upRight]).vowel, .ㅗ)
    }

    func test_verticalOnly_downLeft_staysU() {
        XCTAssertEqual(resolver(.verticalOnly).resolve(directions: [.down, .left]).vowel, .ㅜ)
        XCTAssertEqual(resolver(.verticalOnly).resolve(directions: [.down, .downLeft]).vowel, .ㅜ)
    }

    func test_verticalOnly_rightAngleWaeWe_dropToBaseVowel() {
        XCTAssertEqual(resolver(.verticalOnly).resolve(directions: [.up, .right, .left]).vowel, .ㅗ)
        XCTAssertEqual(resolver(.verticalOnly).resolve(directions: [.down, .left, .right]).vowel, .ㅜ)
    }

    func test_verticalOnly_verticalChainsStillProduceCompounds() {
        let r = resolver(.verticalOnly)
        XCTAssertEqual(r.resolve(directions: [.up, .down, .right]).vowel, .ㅘ)
        XCTAssertEqual(r.resolve(directions: [.up, .down, .right, .left]).vowel, .ㅙ)
        XCTAssertEqual(r.resolve(directions: [.down, .up, .left]).vowel, .ㅝ)
        XCTAssertEqual(r.resolve(directions: [.down, .up, .left, .right]).vowel, .ㅞ)
    }

    func test_verticalOnly_otherVowelsUnaffected() {
        let r = resolver(.verticalOnly)
        XCTAssertEqual(r.resolve(directions: [.up, .down]).vowel, .ㅚ)
        XCTAssertEqual(r.resolve(directions: [.down, .up]).vowel, .ㅟ)
        XCTAssertEqual(r.resolve(directions: [.up, .down, .up]).vowel, .ㅛ)
        XCTAssertEqual(r.resolve(directions: [.right, .left]).vowel, .ㅐ)
        XCTAssertEqual(r.resolve(directions: [.left, .right]).vowel, .ㅔ)
        XCTAssertEqual(r.resolve(directions: [.downLeft, .upRight]).vowel, .ㅢ)
    }

    /// 수용 기준: 긋기 실시간 테스트(미리보기)와 실제 키보드의 결과가 같아야 한다.
    func test_verticalOnly_peekVowelAgreesWithResolve() {
        let r = resolver(.verticalOnly)
        XCTAssertEqual(r.peekVowel(directions: [.up, .right]), .ㅗ)
        XCTAssertEqual(r.peekVowel(directions: [.up, .down, .right]), .ㅘ)
    }

    func test_rightAngleAndVertical_isUnchanged() {
        let r = resolver(.rightAngleAndVertical)
        XCTAssertEqual(r.resolve(directions: [.up, .right]).vowel, .ㅘ)
        XCTAssertEqual(r.resolve(directions: [.up, .right, .left]).vowel, .ㅙ)
        XCTAssertEqual(r.resolve(directions: [.down, .left]).vowel, .ㅝ)
        XCTAssertEqual(r.resolve(directions: [.down, .left, .right]).vowel, .ㅞ)
        XCTAssertEqual(r.resolve(directions: [.up, .down, .right]).vowel, .ㅘ)
    }

    /// 모드를 제스처 사이에 바꿔도 리졸버가 즉시 따라간다 (뷰모델이 제스처 시작마다 주입).
    func test_switchingPathOnLiveResolver_takesEffect() {
        let r = VowelResolver()
        XCTAssertEqual(r.resolve(directions: [.up, .right]).vowel, .ㅘ)
        r.compoundVowelPath = .verticalOnly
        XCTAssertEqual(r.resolve(directions: [.up, .right]).vowel, .ㅗ)
        r.compoundVowelPath = .rightAngleAndVertical
        XCTAssertEqual(r.resolve(directions: [.up, .right]).vowel, .ㅘ)
    }

    // MARK: - E2E: 자음 키 제스처 → 조합 문자열 (주입 지점 가드)
    //
    // 리졸버 단위 테스트는 `compoundVowelPath` 를 직접 세팅하므로, 뷰모델이 제스처
    // 시작마다 설정을 리졸버에 주입하는 줄(`gestureStarted`)을 지워도 전부 통과한다.
    // 여기서는 실제 경로(gestureStarted → Moved → Ended → composingText)로 제보자의
    // 트레이스를 재생해 그 줄을 가드한다.

    /// ㅁ (row 2, col 1) — 제보 문장 "모아키키보드" 의 첫 글자.
    private static let mieumKey = (row: 2, column: 1)

    /// `GestureOverDetectionCharacterizationTests.drivePath` 와 같은 하니스.
    private func drive(_ vm: KeyboardViewModel, key: (row: Int, column: Int),
                       segments: [CGVector], stepsPerSegment: Int = 8) {
        var point = CGPoint(x: 150, y: 150)
        vm.gestureStarted(row: key.row, column: key.column, at: point)
        for segment in segments {
            let origin = point
            for i in 1...stepsPerSegment {
                let f = CGFloat(i) / CGFloat(stepsPerSegment)
                vm.gestureMoved(to: CGPoint(x: origin.x + segment.dx * f, y: origin.y + segment.dy * f))
            }
            point = CGPoint(x: origin.x + segment.dx, y: origin.y + segment.dy)
        }
        vm.gestureEnded(row: key.row, column: key.column)
    }

    /// 이슈 #29 제보 로그 첫 줄: `[ㅁ] raw ↑42(98°) ↗88(56°) ⇒ ㅘ` — "모" 가 "뫄" 로.
    /// 화면 좌표는 y 가 아래로 커지므로 위쪽 획은 dy < 0.
    private static let reporterTrace: [CGVector] = [
        CGVector(dx: -6, dy: -42),   // ↑ 42pt @ 98°
        CGVector(dx: 49, dy: -73),   // ↗ 88pt @ 56°
    ]

    func test_e2e_reporterTrace_defaultMode_reproducesMwa() {
        withCompoundVowelPath(.rightAngleAndVertical) { vm in
            drive(vm, key: Self.mieumKey, segments: Self.reporterTrace)
            XCTAssertEqual(vm.composingText, "뫄", "기본 모드는 제보와 같이 ↑↗ 를 ㅘ 로 (현재 동작 보존)")
        }
    }

    func test_e2e_reporterTrace_verticalOnly_keepsMo() {
        withCompoundVowelPath(.verticalOnly) { vm in
            drive(vm, key: Self.mieumKey, segments: Self.reporterTrace)
            XCTAssertEqual(vm.composingText, "모", "세로 왕복 전용에서는 ↑ 뒤 ↗ 꼬리가 ㅗ 를 바꾸지 못해야 한다")
        }
    }

    func test_e2e_verticalChain_verticalOnly_stillMakesMwa() {
        withCompoundVowelPath(.verticalOnly) { vm in
            drive(vm, key: Self.mieumKey, segments: [
                CGVector(dx: 0, dy: -60),   // ↑
                CGVector(dx: 0, dy: 60),    // ↓ (원점 복귀)
                CGVector(dx: 60, dy: 0),    // →
            ])
            XCTAssertEqual(vm.composingText, "뫄", "세로 왕복 ↑↓→ 는 두 모드 모두에서 ㅘ")
        }
    }

    // MARK: - ㅡ 전용 키 (resolveVowelFromPrimitiveDrag) — 사용자 결정: 모음 키에도 적용

    private func withCompoundVowelPath(_ path: CompoundVowelPath, _ body: (KeyboardViewModel) -> Void) {
        let original = KeyboardSettings.shared.gestureSettings
        defer { KeyboardSettings.shared.gestureSettings = original }
        var gs = original
        gs.compoundVowelPath = path
        KeyboardSettings.shared.gestureSettings = gs
        body(KeyboardViewModel())
    }

    func test_verticalOnly_dashKey_rightAngle_staysBaseVowel() {
        withCompoundVowelPath(.verticalOnly) { vm in
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .right]), .ㅗ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .left]), .ㅜ)
        }
    }

    /// ㅡ 키는 원래 ↑↓→ 가 ㅚ 에서 멈췄다(ㅚ+→ 간선 없음). 직각을 끄면 ㅘ 를 만들
    /// 길이 없어지므로 세로 왕복 전용 모드에서만 ㅚ+→=ㅘ, ㅟ+←=ㅝ 체인을 연다.
    func test_verticalOnly_dashKey_verticalChain_yieldsCompounds() {
        withCompoundVowelPath(.verticalOnly) { vm in
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .down, .right]), .ㅘ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .down, .right, .left]), .ㅙ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .up, .left]), .ㅝ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .up, .left, .right]), .ㅞ)
        }
    }

    func test_verticalOnly_dashKey_otherMappingsUnaffected() {
        withCompoundVowelPath(.verticalOnly) { vm in
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .left]), .ㅚ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .right]), .ㅟ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .down, .up]), .ㅛ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right, .left]), .ㅐ)
        }
    }

    func test_rightAngleAndVertical_dashKey_isUnchanged() {
        withCompoundVowelPath(.rightAngleAndVertical) { vm in
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .right]), .ㅘ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .left]), .ㅝ)
            XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .down, .right]), .ㅚ,
                           "기본 모드의 ㅡ 키 ↑↓→ 는 예전처럼 ㅚ 에서 멈춘다 — 기존 동작 보존")
        }
    }
}

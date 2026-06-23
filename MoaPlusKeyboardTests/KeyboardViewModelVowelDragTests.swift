import XCTest

/// Tests for `KeyboardViewModel.resolveVowelFromPrimitiveDrag` (PR G6, G11, G14).
/// Covers single-stroke base vowels and multi-stroke compound vowels on the
/// ㅣ (`.bar`) and ㅡ (`.dash`) primitive keys.
final class KeyboardViewModelVowelDragTests: XCTestCase {

    var vm: KeyboardViewModel!

    override func setUp() {
        super.setUp()
        vm = KeyboardViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - Multi-stroke vowel drag (PR G14)

    func test_dashUpRight_yieldsWa() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .right]), .ㅘ)
    }

    func test_dashUpRightLeft_yieldsWae() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .right, .left]), .ㅙ)
    }

    func test_dashUpLeft_yieldsOe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .left]), .ㅚ)
    }

    func test_dashDownLeft_yieldsWeo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .left]), .ㅝ)
    }

    func test_dashDownLeftRight_yieldsWe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .left, .right]), .ㅞ)
    }

    func test_dashDownRight_yieldsWi() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down, .right]), .ㅟ)
    }

    func test_barLeftRight_yieldsE() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.left, .right]), .ㅔ)
    }

    func test_barRightLeft_yieldsAe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right, .left]), .ㅐ)
    }

    func test_barUpRight_yieldsYe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.up, .right]), .ㅖ)
    }

    func test_barUpLeft_yieldsYe() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.up, .left]), .ㅖ)
    }

    func test_barDownRight_yieldsYae() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.down, .right]), .ㅒ)
    }

    func test_barDownLeft_yieldsYae() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.down, .left]), .ㅒ)
    }

    // MARK: - Diagonal first stroke normalization (PR G14)

    func test_dashUpRightDiagonal_normalizesToUp() {
        // First stroke ↗ should normalize to ↑ → ㅗ
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.upRight]), .ㅗ)
    }

    func test_dashUpRightDiagonalThenRight_yieldsWa() {
        // ↗ → ㅗ, then → → ㅘ
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.upRight, .right]), .ㅘ)
    }

    // MARK: - Single-stroke regression (PR G6)

    func test_barLeft_stillYieldsEo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.left]), .ㅓ)
    }

    func test_barRight_stillYieldsA() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right]), .ㅏ)
    }

    func test_barUp_stillYieldsYeo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.up]), .ㅕ)
    }

    func test_barDown_stillYieldsYa() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.down]), .ㅑ)
    }

    func test_dashUp_stillYieldsO() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up]), .ㅗ)
    }

    func test_dashDown_stillYieldsU() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.down]), .ㅜ)
    }

    func test_dashLeft_stillYieldsYo() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.left]), .ㅛ)
    }

    func test_dashRight_stillYieldsYu() {
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.right]), .ㅠ)
    }

    // MARK: - Edge cases

    func test_emptyDirections_yieldsNil() {
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: []))
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: []))
    }

    func test_dotPrimitive_alwaysYieldsNil() {
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .dot, directions: [.up]))
        XCTAssertNil(vm.resolveVowelFromPrimitiveDrag(primitive: .dot, directions: [.up, .right]))
    }

    func test_secondStrokeNoCompound_keepsPriorVowel() {
        // ㅏ has no compound for `.right`; should remain ㅏ.
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .bar, directions: [.right, .right]), .ㅏ)
        // ㅗ + ↑ has no compound; should remain ㅗ.
        XCTAssertEqual(vm.resolveVowelFromPrimitiveDrag(primitive: .dash, directions: [.up, .up]), .ㅗ)
    }

    // MARK: - Slot B vowel key (B1 preset, multi-stroke pipeline)
    //
    // Drives the gesture trio (start/move/end) with synthetic point streams,
    // exercising the same GestureAnalyzer + VowelResolver pipeline used by
    // consonant keys. The view layer normally feeds these from DragGesture;
    // here we pump points directly.

    /// Start point used for every synthetic gesture in this section.
    private static let slotBOrigin = CGPoint(x: 100, y: 100)

    /// Magnitude that comfortably exceeds the default swipe threshold so the
    /// analyzer registers each stroke. Threshold is keyWidth-derived; the
    /// unit-test default keyWidth is 50 pt, giving thresholds well below 80.
    private static let slotBStrokeLength: CGFloat = 80

    /// Drive the slot-B gesture trio with the supplied direction sequence.
    /// Each direction is a single straight stroke from the previous endpoint.
    private func driveSlotBGesture(_ directions: [(dx: CGFloat, dy: CGFloat)]) {
        vm.slotBVowelGestureStarted(at: Self.slotBOrigin)
        var current = Self.slotBOrigin
        for delta in directions {
            // Emit a few intermediate points so the analyzer sees a clean
            // straight-line stroke rather than a single jump.
            let steps = 4
            for i in 1...steps {
                let frac = CGFloat(i) / CGFloat(steps)
                let p = CGPoint(x: current.x + delta.dx * frac,
                                y: current.y + delta.dy * frac)
                vm.slotBVowelGestureMoved(to: p)
            }
            current = CGPoint(x: current.x + delta.dx, y: current.y + delta.dy)
        }
        vm.slotBVowelGestureEnded()
    }

    private static let strokeRight: (dx: CGFloat, dy: CGFloat) = (slotBStrokeLength, 0)
    private static let strokeLeft: (dx: CGFloat, dy: CGFloat) = (-slotBStrokeLength, 0)
    private static let strokeUp: (dx: CGFloat, dy: CGFloat) = (0, -slotBStrokeLength)
    private static let strokeDown: (dx: CGFloat, dy: CGFloat) = (0, slotBStrokeLength)

    func test_slotBVowelKey_tapInsertsDot() {
        // No movement at all → empty direction sequence → ㆍ.
        vm.slotBVowelGestureStarted(at: Self.slotBOrigin)
        vm.slotBVowelGestureEnded()
        XCTAssertEqual(vm.composingText, "ㆍ")
    }

    func test_slotBVowelKey_rightDragInsertsA() {
        driveSlotBGesture([Self.strokeRight])
        XCTAssertEqual(vm.composingText, "ㅏ")
    }

    func test_slotBVowelKey_leftDragInsertsEo() {
        driveSlotBGesture([Self.strokeLeft])
        XCTAssertEqual(vm.composingText, "ㅓ")
    }

    func test_slotBVowelKey_upDragInsertsO() {
        driveSlotBGesture([Self.strokeUp])
        XCTAssertEqual(vm.composingText, "ㅗ")
    }

    func test_slotBVowelKey_downDragInsertsU() {
        driveSlotBGesture([Self.strokeDown])
        XCTAssertEqual(vm.composingText, "ㅜ")
    }

    // MARK: Multi-stroke compound vowels (the bug fix)

    func test_slotBVowelKey_upRight_yieldsWa() {
        // ↑→ pattern → ㅘ (same as consonant-drag pipeline)
        driveSlotBGesture([Self.strokeUp, Self.strokeRight])
        XCTAssertEqual(vm.composingText, "ㅘ")
    }

    func test_slotBVowelKey_downLeft_yieldsWeo() {
        // ↓← pattern → ㅝ
        driveSlotBGesture([Self.strokeDown, Self.strokeLeft])
        XCTAssertEqual(vm.composingText, "ㅝ")
    }

    func test_slotBVowelKey_rightLeftRight_yieldsYa() {
        // →←→ pattern → ㅑ (y-vowel)
        driveSlotBGesture([Self.strokeRight, Self.strokeLeft, Self.strokeRight])
        XCTAssertEqual(vm.composingText, "ㅑ")
    }

    func test_slotBVowelKey_leftRight_yieldsE() {
        // ←→ pattern → ㅔ
        driveSlotBGesture([Self.strokeLeft, Self.strokeRight])
        XCTAssertEqual(vm.composingText, "ㅔ")
    }

    // MARK: - ㅣ/ㅡ 전용 키 입력: 4방향/8방향 모드 무관 정상 동작
    //
    // 사용자 질문 "모든 모드에서 ㅡ/ㅣ 입력 문제 없나?" 에 대한 회귀 보장.
    // ㅣ(.bar)/ㅡ(.dash) 전용 키는 KeyGridView 의 일반 제스처 파이프라인
    // (gestureStarted → gestureMoved → gestureEnded)로 들어온다. 탭은 긋기
    // 설정과 무관하게 ㅣ/ㅡ 를 그대로 내고, 긋기 모음 매핑은 전부 카디널
    // 기반이라 4방향 모드(대각선→카디널 스냅)에서도 동일하게 동작한다.

    /// ㅣ키 = row 2, col 6 (.bar). ㅡ키 = row 3, col 5 (.dash).
    private static let barKey = (row: 2, column: 6)
    private static let dashKey = (row: 3, column: 5)

    /// 임시로 fourWayMode 를 적용하고 클로저 실행 후 원복. KeyboardViewModel 이
    /// 매 제스처마다 `KeyboardSettings.shared` 를 직접 읽으므로 싱글톤을 통해
    /// 주입한다.
    private func withFourWayMode(_ enabled: Bool, _ body: () -> Void) {
        let original = KeyboardSettings.shared.gestureSettings
        defer { KeyboardSettings.shared.gestureSettings = original }
        var gs = original
        gs.swipeProfile.fourWayMode = enabled
        KeyboardSettings.shared.gestureSettings = gs
        body()
    }

    /// 단일 직선 긋기로 키를 구동한다 (tap = delta (0,0)).
    private func driveKeyGesture(row: Int, column: Int, dx: CGFloat, dy: CGFloat) {
        let origin = CGPoint(x: 100, y: 100)
        vm.gestureStarted(row: row, column: column, at: origin)
        if dx != 0 || dy != 0 {
            for i in 1...4 {
                let f = CGFloat(i) / 4
                vm.gestureMoved(to: CGPoint(x: origin.x + dx * f, y: origin.y + dy * f))
            }
        }
        vm.gestureEnded(row: row, column: column)
    }

    func test_fourWayMode_barKeyTap_insertsBar() {
        withFourWayMode(true) {
            driveKeyGesture(row: Self.barKey.row, column: Self.barKey.column, dx: 0, dy: 0)
        }
        XCTAssertEqual(vm.composingText, "ㅣ", "4방향 모드에서도 ㅣ키 탭은 ㅣ 입력")
    }

    func test_fourWayMode_dashKeyTap_insertsDash() {
        withFourWayMode(true) {
            driveKeyGesture(row: Self.dashKey.row, column: Self.dashKey.column, dx: 0, dy: 0)
        }
        XCTAssertEqual(vm.composingText, "ㅡ", "4방향 모드에서도 ㅡ키 탭은 ㅡ 입력")
    }

    func test_eightWayMode_barKeyTap_insertsBar() {
        withFourWayMode(false) {
            driveKeyGesture(row: Self.barKey.row, column: Self.barKey.column, dx: 0, dy: 0)
        }
        XCTAssertEqual(vm.composingText, "ㅣ", "기본(8방향) 모드에서도 ㅣ키 탭은 ㅣ (회귀 없음)")
    }

    func test_fourWayMode_barKeyDiagonalDrag_snapsToCardinalVowel() {
        // 55° 긋기: 8방향이면 ↗(normalize→↑) , 4방향이면 ↑ — 둘 다 ㅣ키 ↑ = ㅕ.
        // 4방향 모드에서 대각선 드리프트가 카디널로 스냅되어 의도한 모음이 나옴.
        withFourWayMode(true) {
            driveKeyGesture(row: Self.barKey.row, column: Self.barKey.column, dx: 57.4, dy: -81.9)
        }
        XCTAssertEqual(vm.composingText, "ㅕ", "4방향 모드: ㅣ키 비스듬 긋기도 ↑로 스냅되어 ㅕ")
    }

    func test_fourWayMode_dashKeyDownDrag_insertsU() {
        withFourWayMode(true) {
            driveKeyGesture(row: Self.dashKey.row, column: Self.dashKey.column, dx: 0, dy: 80)
        }
        XCTAssertEqual(vm.composingText, "ㅜ", "4방향 모드: ㅡ키 ↓ 긋기는 ㅜ")
    }

    // MARK: - 확장형(slot B 모음 키)에서 ㅣ/ㅡ 는 대각선 긋기 의존 → 4방향 영향
    //
    // 확장형(.fullPackage)과 클래식(.classic11)은 ㅣ/ㅡ 전용 키가 없고,
    // ㅣ=↗, ㅡ=↘ 대각선 긋기(VowelResolver의 DiagonalMapping)로 입력한다.
    // 4방향 모드는 대각선을 카디널로 스냅하므로 이 경로에서 ㅣ/ㅡ 가 막힌다.
    // 이 두 테스트는 그 사실을 명문화(회귀 감지)한다.

    private static let strokeUpRight: (dx: CGFloat, dy: CGFloat) = (57, -57)   // ↗ ~45°
    private static let strokeDownRight: (dx: CGFloat, dy: CGFloat) = (57, 57)  // ↘ ~-45°

    func test_eightWay_slotBUpRightDrag_yieldsBar() {
        withFourWayMode(false) { driveSlotBGesture([Self.strokeUpRight]) }
        XCTAssertEqual(vm.composingText, "ㅣ", "8방향: slot B ↗ 긋기 = ㅣ (확장형 ㅣ 입력 경로)")
    }

    func test_fourWay_slotBUpRightDrag_cannotYieldBar() {
        withFourWayMode(true) { driveSlotBGesture([Self.strokeUpRight]) }
        XCTAssertNotEqual(vm.composingText, "ㅣ",
            "4방향: slot B ↗ 가 카디널로 스냅되어 ㅣ 입력 불가 — 확장형/클래식 ㅣ 입력이 막힘을 증명")
    }

    func test_eightWay_slotBDownRightDrag_yieldsDash() {
        withFourWayMode(false) { driveSlotBGesture([Self.strokeDownRight]) }
        XCTAssertEqual(vm.composingText, "ㅡ", "8방향: slot B ↘ 긋기 = ㅡ (확장형 ㅡ 입력 경로)")
    }

    func test_fourWay_slotBDownRightDrag_cannotYieldDash() {
        withFourWayMode(true) { driveSlotBGesture([Self.strokeDownRight]) }
        XCTAssertNotEqual(vm.composingText, "ㅡ",
            "4방향: slot B ↘ 가 카디널로 스냅되어 ㅡ 입력 불가")
    }
}

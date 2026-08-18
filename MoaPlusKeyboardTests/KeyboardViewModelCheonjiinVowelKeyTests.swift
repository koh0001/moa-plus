import XCTest

/// 모음 키 `.cheonjiin` 동작(순정/삼성 모아키 방식, 이슈 #25) 회귀 가드.
///
/// 순정은 모음 키를 누르면 키 위에 `ㅣ · ㅡ` 3칸 팝업을 띄우고 손가락이 놓인
/// 칸을 고르게 한다. 그 선택 기하가 곧 "가로 변위로 3분할" 이므로 구현은
/// **손 뗀 지점의 가로 순변위**만 본다:
///
/// | 손 뗀 위치 | 결과 |
/// |-----------|------|
/// | 왼쪽 (임계 이상) | ㅣ |
/// | 오른쪽 (임계 이상) | ㅡ |
/// | 그 외 (탭 · 상하 · 임계 미만) | ㆍ |
///
/// 나머지 모음은 전부 천지인 합성(`HangulComposer.combineVowels`)으로 쌓는다.
final class KeyboardViewModelCheonjiinVowelKeyTests: XCTestCase {

    var vm: KeyboardViewModel!

    override func setUp() {
        super.setUp()
        vm = KeyboardViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - Harness

    private static let origin = CGPoint(x: 100, y: 100)
    /// 기본 긋기 길이(보통 = 중앙키 폭 40%)의 임계를 확실히 넘는 변위.
    /// 유닛 테스트 기본 keyWidth 는 50pt → 임계 20pt.
    private static let far: CGFloat = 80
    /// 임계(20pt) 아래의 미세 이동 — 가운데 칸으로 판정돼야 한다.
    private static let jitter: CGFloat = 6

    /// `layoutCustomization.vowelKeyBehavior` 를 임시로 바꾸고 원복한다.
    /// ViewModel 이 제스처마다 `KeyboardSettings.shared` 를 직접 읽으므로
    /// 싱글톤을 통해 주입한다 (기존 `withFourWayMode` 와 같은 패턴).
    private func withVowelKeyBehavior(_ behavior: VowelKeyBehavior, _ body: () -> Void) {
        let original = KeyboardSettings.shared.layoutCustomization
        defer { KeyboardSettings.shared.layoutCustomization = original }
        var lc = original
        lc.vowelKeyBehavior = behavior
        KeyboardSettings.shared.layoutCustomization = lc
        body()
    }

    private func withFourWayMode(_ enabled: Bool, _ body: () -> Void) {
        let original = KeyboardSettings.shared.gestureSettings
        defer { KeyboardSettings.shared.gestureSettings = original }
        var gs = original
        gs.swipeProfile.fourWayMode = enabled
        KeyboardSettings.shared.gestureSettings = gs
        body()
    }

    /// 시작점에서 (dx, dy) 만큼 한 번에 긋고 손을 뗀다.
    /// dx/dy 가 0 이면 이동 이벤트 없이 탭 (`DragGesture(minimumDistance: 0)` 는
    /// 탭에서도 시작점으로 onChanged 를 한 번 보내지만, 결과는 동일해야 한다).
    private func drag(dx: CGFloat, dy: CGFloat) {
        vm.slotBVowelGestureStarted(at: Self.origin)
        if dx != 0 || dy != 0 {
            for i in 1...4 {
                let f = CGFloat(i) / 4
                vm.slotBVowelGestureMoved(to: CGPoint(x: Self.origin.x + dx * f,
                                                      y: Self.origin.y + dy * f))
            }
        }
        vm.slotBVowelGestureEnded()
    }

    /// 여러 지점을 순서대로 지나며 끄는 제스처 (마지막 지점에서 손을 뗀다).
    private func dragThrough(_ offsets: [(dx: CGFloat, dy: CGFloat)]) {
        vm.slotBVowelGestureStarted(at: Self.origin)
        for o in offsets {
            vm.slotBVowelGestureMoved(to: CGPoint(x: Self.origin.x + o.dx,
                                                  y: Self.origin.y + o.dy))
        }
        vm.slotBVowelGestureEnded()
    }

    // MARK: - 기본값 (회귀 가드)

    func test_default_isGestureMulti() {
        XCTAssertEqual(LayoutCustomization().vowelKeyBehavior, .gestureMulti,
                       "기본값은 기존 8방향 동작이어야 한다 — 기존 사용자의 손버릇을 깨면 안 됨")
    }

    // MARK: - 3분할 판정

    func test_cheonjiin_tap_insertsDot() {
        withVowelKeyBehavior(.cheonjiin) { drag(dx: 0, dy: 0) }
        XCTAssertEqual(vm.composingText, "ㆍ")
    }

    func test_cheonjiin_leftDrag_insertsBar() {
        withVowelKeyBehavior(.cheonjiin) { drag(dx: -Self.far, dy: 0) }
        XCTAssertEqual(vm.composingText, "ㅣ", "← = ㅣ (이슈 #25)")
    }

    func test_cheonjiin_rightDrag_insertsDash() {
        withVowelKeyBehavior(.cheonjiin) { drag(dx: Self.far, dy: 0) }
        XCTAssertEqual(vm.composingText, "ㅡ", "→ = ㅡ (이슈 #25)")
    }

    func test_cheonjiin_upDrag_insertsDot() {
        // 순정 팝업의 가운데 칸(ㆍ)이 키 바로 위에 있다 — ↑ 는 ㆍ 선택이다.
        withVowelKeyBehavior(.cheonjiin) { drag(dx: 0, dy: -Self.far) }
        XCTAssertEqual(vm.composingText, "ㆍ")
    }

    func test_cheonjiin_downDrag_insertsDot() {
        withVowelKeyBehavior(.cheonjiin) { drag(dx: 0, dy: Self.far) }
        XCTAssertEqual(vm.composingText, "ㆍ")
    }

    func test_cheonjiin_upLeftDrag_insertsBar() {
        // 3칸이 가로로만 나뉘므로 세로 성분은 무시한다. ↖ 도 ㅣ.
        withVowelKeyBehavior(.cheonjiin) { drag(dx: -Self.far, dy: -Self.far) }
        XCTAssertEqual(vm.composingText, "ㅣ")
    }

    func test_cheonjiin_downRightDrag_insertsDash() {
        withVowelKeyBehavior(.cheonjiin) { drag(dx: Self.far, dy: Self.far) }
        XCTAssertEqual(vm.composingText, "ㅡ")
    }

    func test_cheonjiin_subThresholdJitter_insertsDot() {
        // 탭하려다 손가락이 살짝 밀린 경우 — 임계 미만이면 가운데(ㆍ) 유지.
        withVowelKeyBehavior(.cheonjiin) { drag(dx: -Self.jitter, dy: Self.jitter) }
        XCTAssertEqual(vm.composingText, "ㆍ")
    }

    // MARK: - 선택기(selector) 의미론

    func test_cheonjiin_wanderThenReturnToCenter_insertsDot() {
        // 왼쪽까지 갔다가 가운데로 돌아와 떼면 ㆍ. 순정 팝업은 "지나간 경로"가
        // 아니라 "손 뗀 칸"으로 정해지는 선택기다 — 획 시퀀스가 아니다.
        withVowelKeyBehavior(.cheonjiin) {
            dragThrough([(-Self.far, 0), (-Self.far / 2, 0), (0, 0)])
        }
        XCTAssertEqual(vm.composingText, "ㆍ")
    }

    func test_cheonjiin_wanderThenSettleRight_insertsDash() {
        withVowelKeyBehavior(.cheonjiin) {
            dragThrough([(-Self.far, 0), (0, 0), (Self.far, 0)])
        }
        XCTAssertEqual(vm.composingText, "ㅡ")
    }

    func test_cheonjiin_multiStrokePatternDoesNotProduceCompoundVowel() {
        // 8방향 모드였다면 ↑→ = ㅘ. 순정 모드에서는 최종 가로 변위(+)만 보므로 ㅡ.
        withVowelKeyBehavior(.cheonjiin) {
            dragThrough([(0, -Self.far), (Self.far, -Self.far)])
        }
        XCTAssertEqual(vm.composingText, "ㅡ", "순정 모드는 멀티스트로크 합성 모음을 만들지 않는다")
    }

    // MARK: - 천지인 합성 (나머지 모음이 나오는 실제 경로)

    func test_cheonjiin_barThenDot_yieldsA() {
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: -Self.far, dy: 0)   // ㅣ
            drag(dx: 0, dy: 0)           // ㆍ
        }
        XCTAssertEqual(vm.composingText, "ㅏ", "ㅣ + ㆍ = ㅏ")
    }

    func test_cheonjiin_dashThenDot_yieldsU() {
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: Self.far, dy: 0)    // ㅡ
            drag(dx: 0, dy: 0)           // ㆍ
        }
        XCTAssertEqual(vm.composingText, "ㅜ", "ㅡ + ㆍ = ㅜ")
    }

    func test_cheonjiin_dotThenBar_yieldsEo() {
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: 0, dy: 0)           // ㆍ
            drag(dx: -Self.far, dy: 0)   // ㅣ
        }
        XCTAssertEqual(vm.composingText, "ㅓ", "ㆍ + ㅣ = ㅓ")
    }

    func test_cheonjiin_dotThenDash_yieldsO() {
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: 0, dy: 0)           // ㆍ
            drag(dx: Self.far, dy: 0)    // ㅡ
        }
        XCTAssertEqual(vm.composingText, "ㅗ", "ㆍ + ㅡ = ㅗ")
    }

    // MARK: dotPending — 순정 모드에서 ㅕ/ㅛ 로 가는 **유일한** 경로
    //
    // 8방향 모드라면 ㅕ 는 한 번의 긋기(←→←)로도 나오지만, 순정 모드는 좌우
    // 3분할뿐이라 ㆍㆍ 누적(`HangulComposer.State.dotPending`)이 유일한 길이다.
    // 이 경로가 막히면 순정 모드 사용자는 ㅕ·ㅛ·여 를 아예 입력할 수 없다.

    func test_cheonjiin_dotDotBar_yieldsYeo() {
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: 0, dy: 0)           // ㆍ
            drag(dx: 0, dy: 0)           // ㆍ (pending 2)
            drag(dx: -Self.far, dy: 0)   // ㅣ
        }
        XCTAssertEqual(vm.composingText, "ㅕ", "ㆍ + ㆍ + ㅣ = ㅕ")
    }

    func test_cheonjiin_dotDotDash_yieldsYo() {
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: 0, dy: 0)           // ㆍ
            drag(dx: 0, dy: 0)           // ㆍ (pending 2)
            drag(dx: Self.far, dy: 0)    // ㅡ
        }
        XCTAssertEqual(vm.composingText, "ㅛ", "ㆍ + ㆍ + ㅡ = ㅛ")
    }

    func test_cheonjiin_consonantThenDotDotBar_yieldsYeoSyllable() {
        withVowelKeyBehavior(.cheonjiin) {
            vm.inputConsonant(.ㅇ)
            drag(dx: 0, dy: 0)           // ㆍ
            drag(dx: 0, dy: 0)           // ㆍ (pending 2)
            drag(dx: -Self.far, dy: 0)   // ㅣ
        }
        XCTAssertEqual(vm.composingText, "여", "ㅇ + ㆍ + ㆍ + ㅣ = 여")
    }

    func test_cheonjiin_consonantThenBarThenDot_yieldsGa() {
        withVowelKeyBehavior(.cheonjiin) {
            vm.inputConsonant(.ㄱ)
            drag(dx: -Self.far, dy: 0)   // ㅣ
            drag(dx: 0, dy: 0)           // ㆍ
        }
        XCTAssertEqual(vm.composingText, "가", "ㄱ + ㅣ + ㆍ = 가")
    }

    // MARK: - 4방향 전용 모드와의 조합
    //
    // 8방향 모드에서 클래식/확장형의 ㅣ/ㅡ 는 대각선 ↗/↘ 로만 들어와
    // 4방향 전용 모드를 켜면 입력이 막힌다
    // (`KeyboardViewModelVowelDragTests.test_fourWay_slotB*` 가 그 사실을 고정).
    // 순정 모드는 좌우 카디널만 쓰므로 그 제약이 사라진다.

    func test_cheonjiin_worksUnderFourWayMode() {
        withVowelKeyBehavior(.cheonjiin) {
            withFourWayMode(true) { drag(dx: -Self.far, dy: 0) }
        }
        XCTAssertEqual(vm.composingText, "ㅣ", "4방향 전용 모드에서도 순정 모음 키로 ㅣ 입력 가능")
    }

    func test_cheonjiin_dashWorksUnderFourWayMode() {
        withVowelKeyBehavior(.cheonjiin) {
            withFourWayMode(true) { drag(dx: Self.far, dy: 0) }
        }
        XCTAssertEqual(vm.composingText, "ㅡ", "4방향 전용 모드에서도 순정 모음 키로 ㅡ 입력 가능")
    }

    // MARK: - 미리보기 (설정 화면 · 긋기 오버레이)

    func test_cheonjiin_previewMode_emitsSelectedPrimitive() {
        var emitted: [Jungseong] = []
        vm.previewMode = true
        vm.onPreviewVowel = { emitted.append($0) }
        withVowelKeyBehavior(.cheonjiin) {
            drag(dx: -Self.far, dy: 0)
            drag(dx: Self.far, dy: 0)
            drag(dx: 0, dy: 0)
        }
        XCTAssertEqual(emitted, [.ㅣ, .ㅡ, .ㆍ])
        XCTAssertEqual(vm.composingText, "", "미리보기 모드에서는 조합기에 들어가지 않는다")
    }

    func test_cheonjiin_gestureStateClearedAfterRelease() {
        withVowelKeyBehavior(.cheonjiin) { drag(dx: -Self.far, dy: 0) }
        XCTAssertNil(vm.gestureState.startPoint)
        XCTAssertNil(vm.gestureState.previewVowel)
        XCTAssertTrue(vm.gestureState.directions.isEmpty)
    }

    func test_cheonjiin_previewVowelUpdatesWhileDragging() {
        withVowelKeyBehavior(.cheonjiin) {
            vm.slotBVowelGestureStarted(at: Self.origin)
            vm.slotBVowelGestureMoved(to: CGPoint(x: Self.origin.x - Self.far, y: Self.origin.y))
            XCTAssertEqual(vm.gestureState.previewVowel, .ㅣ)
            XCTAssertEqual(vm.gestureState.directions, [.left])

            vm.slotBVowelGestureMoved(to: CGPoint(x: Self.origin.x + Self.far, y: Self.origin.y))
            XCTAssertEqual(vm.gestureState.previewVowel, .ㅡ)
            XCTAssertEqual(vm.gestureState.directions, [.right])

            // 가운데로 돌아오면 미리보기 없음 (탭과 같은 상태).
            vm.slotBVowelGestureMoved(to: Self.origin)
            XCTAssertNil(vm.gestureState.previewVowel)
            XCTAssertTrue(vm.gestureState.directions.isEmpty)

            vm.slotBVowelGestureEnded()
        }
    }
}

import XCTest
@testable import MoaPlusKeyboard

/// v2.0 실기기 실측(2026-08, V2_DEVICE_TEST_CHECKLIST 결과)에서 보고된
/// **손 떼는 꼬리(release tail) 승격 오타**의 회귀 테스트.
///
/// 실측 결과:
///   - a5: ㅚ(↑↓) 가 위쪽 꼬리로 ↑↓↑=ㅛ 로 승격 ("외"→"요")
///   - b2: ㅚ 끝의 왼쪽 꼬리가 ↑↓←=ㅕ 로 승격 ("외"→"여")
///   - b6: ㅕ(←→←) 끝의 오른쪽 꼬리가 ←→←→=ㅖ 로 승격 ("녕"→"녱")
///   - T1: 획을 길게 그어도 발생 — 절대 크기 컷만으로는 못 거른다는 증거
///
/// 원인과 수정:
///   - 반전 등록 임계가 키폭의 20%로 순정보다 민감했다. 순정 하한은 adb 터치
///     주입 실측(2026-08-14, 갤럭시 S22+)으로 **42px = 키 너비 150px 의 28%**
///     확정 (41px 미등록/42px 등록) → `reversalThresholdRatio` 0.5 → 0.70.
///   - S2 판독 + adb 실측으로 순정의 되돌림 판정이 **절대 크기 임계**임이 확증됨
///     (진입 300px/150px 어느 쪽이든 같은 42px 경계, 비율 0.2 되돌림도 ㅚ 인정)
///     — 그래서 "직전 획 대비 비율" 단독 트림은 쓰지 않는다. 순정 이탈이 된다.
///   - 방향 판정 window 는 등록 임계와 분리해 키폭 20%로 유지 — 같이 키우면
///     의도적 키폭 50% 되돌림까지 뭉개진다 (아래 moderateIntentionalReversal).
///
/// 여기 단언은 전부 **기본 설정(민감도 0, 보통 길이)** 기준 — 실기기 사용자의
/// 기본 상태를 재현한다. 키폭은 테스트 기본 50pt (임계 20 / 반전 등록 14 /
/// 방향 window 10). 촘촘한 보간(느린 손) 기준이라, 성긴 샘플(빠른 튕김)에서는
/// 14pt 이상 꼬리가 등록될 수 있는데 이는 순정 절대 임계와 같은 동작이다.
final class DeviceMeasuredTailRegressionTests: XCTestCase {

    var vm: KeyboardViewModel!

    /// ㅇ (row 2, col 3) — 실측 문장 "안녕하세요…" 의 모음이 대부분 여기서 나온다.
    private static let ieungKey = (row: 2, column: 3)
    /// ㄴ (row 2, col 2) — "녕"/"녱" 재현용.
    private static let nieunKey = (row: 2, column: 2)

    override func setUp() {
        super.setUp()
        resetToDefaultGestureSettings()
        vm = KeyboardViewModel()
    }

    override func tearDown() {
        vm = nil
        resetToDefaultGestureSettings()
        super.tearDown()
    }

    /// 시뮬레이터 App Group 오염(메인 앱 실행 잔재)과 무관하게 항상 기본
    /// 제스처 설정으로 판정하도록 강제한다.
    private func resetToDefaultGestureSettings() {
        KeyboardSettings.shared.gestureSettings = .default
    }

    private func drivePath(row: Int, column: Int, segments: [CGVector], stepsPerSegment: Int = 8) {
        var point = CGPoint(x: 150, y: 150)
        vm.gestureStarted(row: row, column: column, at: point)
        for segment in segments {
            let origin = point
            for i in 1...stepsPerSegment {
                let f = CGFloat(i) / CGFloat(stepsPerSegment)
                vm.gestureMoved(to: CGPoint(x: origin.x + segment.dx * f, y: origin.y + segment.dy * f))
            }
            point = CGPoint(x: origin.x + segment.dx, y: origin.y + segment.dy)
        }
        vm.gestureEnded(row: row, column: column)
    }

    private func run(key: (row: Int, column: Int) = ieungKey,
                     _ segments: [CGVector], steps: Int = 8) -> String {
        vm = KeyboardViewModel()
        drivePath(row: key.row, column: key.column, segments: segments, stepsPerSegment: steps)
        return vm.composingText
    }

    // MARK: - a5: ㅚ 위쪽 꼬리 → ㅛ 승격

    func test_a5_upwardTailAfterOe_doesNotPromoteToYo() {
        // ↑55 ↓55 + 손 떼며 위로 튕긴 13pt 꼬리. 실측에서 "외"가 "요"로 바뀌던
        // 경로 — 구 임계(키폭 20% = 10pt)는 이 크기를 획으로 등록했다.
        let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: 0, dy: -13)]
        XCTAssertEqual(run(path), "외", "↑↓ 끝 13pt 위 꼬리는 노이즈 — ㅛ 로 승격되면 안 됨")
    }

    func test_a5_tailSizeBoundary_matchesMoakeyAbsoluteThreshold() {
        // 순정 하한(키폭 28% = 14pt, adb 실측 42px/150px) 아래 꼬리는 노이즈로
        // 무시된다. 13pt = 임계 바로 아래.
        for tail in [CGFloat(11), 12, 13] {
            let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: 0, dy: -tail)]
            XCTAssertEqual(run(path), "외", "↑↓ + ↑\(tail)pt 꼬리는 '외' 여야 함")
        }
        // 하한 위(18pt = 키폭 36%)는 **순정도 획으로 인정하는 크기**다 — S2 판독
        // (300px+ 진입 후 60~80px 되돌림도 전부 ㅚ 인정 = 절대 임계) 기준으로
        // ㅛ 가 되는 것이 순정 정합. 여기서 더 깎으면 의도적 ㅛ 가 안 나온다.
        let bigTail = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: 0, dy: -18)]
        XCTAssertEqual(run(bigTail), "요", "키폭 36% 되돌림은 순정처럼 획으로 인정")
    }

    // MARK: - b2: ㅚ 왼쪽 꼬리 → ㅕ 승격

    func test_b2_leftTailAfterOe_doesNotPromoteToYeo() {
        // ↑↓ 후 왼쪽으로 흘리며 떼기(체크리스트 B2 시나리오 그대로).
        // ↑↓←=ㅕ 간선 추가(v2.0)의 예고된 회귀 축.
        let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: -20, dy: 0)]
        XCTAssertEqual(run(path), "외", "↑↓ 끝 20pt 왼쪽 꼬리는 노이즈 — ㅕ 로 승격되면 안 됨")
    }

    // MARK: - b6: ㅕ 오른쪽 꼬리 → ㅖ 승격 ("녕"→"녱")

    func test_b6_rightTailAfterYeo_doesNotPromoteToYe() {
        // ㄴ 키에서 ←→← (ㅕ) 후 오른쪽 13pt 꼬리. 실측 "안녕"→"안녱" 오타 —
        // 구 임계(10pt)가 이 대역을 획으로 등록해 ㅖ 로 승격시켰다.
        // (순정 하한 이상의 큰 꼬리는 순정도 ㅖ 로 등록한다 — a5 boundary 테스트 참고.)
        let path = [CGVector(dx: -55, dy: 0), CGVector(dx: 55, dy: 0),
                    CGVector(dx: -55, dy: 0), CGVector(dx: 13, dy: 0)]
        XCTAssertEqual(run(key: Self.nieunKey, path), "녀", "←→← 끝 13pt 오른쪽 꼬리는 노이즈 — ㅖ 로 승격되면 안 됨")
    }

    // MARK: - a5 잔여(build 17 실측): 모서리 튕김이 ㅘ/ㅕ 를 ㅛ 로 가로챔

    /// ↑↓ 후 →/← 로 꺾는 모서리에서 손가락이 살짝 위로 들리며 작은 ↑ 가
    /// 등록되면 ↑↓↑→ 가 되어 트라이가 ㅛ 에서 멈춘다 ("ㅘ·ㅕ를 ㅛ가 가로챔").
    /// 릴리즈 꼬리와 달리 중간 획이라 후행 트림 소관이 아님 — corner bounce
    /// 흡수 패스가 다음 획에 벡터째 합쳐야 한다.
    func test_a5_cornerBounceBeforeRight_doesNotInterceptWa() {
        for bounce in [CGFloat(15), 18, 20] {
            let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55),
                        CGVector(dx: 0, dy: -bounce), CGVector(dx: 55, dy: 0)]
            XCTAssertEqual(run(path), "와", "↑↓ 모서리 ↑\(bounce)pt 튕김 후 → 는 '와' 여야 함 (ㅛ 가로채기 금지)")
        }
    }

    func test_a5_cornerBounceBeforeLeft_doesNotInterceptYeo() {
        let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55),
                    CGVector(dx: 0, dy: -18), CGVector(dx: -55, dy: 0)]
        XCTAssertEqual(run(path), "여", "↑↓ 모서리 ↑18pt 튕김 후 ← 는 '여' 여야 함")
    }

    /// 모서리 자리(3획째 이후)의 상한은 키폭 70%(35pt)까지 — 실기기 스크린샷
    /// 실측에서 갈고리가 키폭 40~60% 크기로도 관찰됐다. 단 비율 가드(양옆의
    /// 50% 미만)는 유지되므로 흡수량은 양옆 획 크기에 비례한다.
    func test_a5_largerCornerBounce_absorbedWhenNeighborsAreLong() {
        let path = [CGVector(dx: 0, dy: -80), CGVector(dx: 0, dy: 80),
                    CGVector(dx: 0, dy: -32), CGVector(dx: 80, dy: 0)]
        XCTAssertEqual(run(path), "와", "긴 획 사이의 32pt 모서리 갈고리는 흡수돼야 함")
    }

    /// 첫 되돌림 자리(2획째)는 보수적 상한(키폭 42%) 유지 — [↑,↓25,←] 의
    /// ↓25 는 ㅕ 의 **의도적 되돌림**이라 흡수하면 안 된다.
    func test_intentionalSmallReturn_atSecondStroke_isNotAbsorbed() {
        let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 25), CGVector(dx: -55, dy: 0)]
        XCTAssertEqual(run(path), "여", "2획째 25pt 되돌림은 의도적 획 — ㅗ 로 뭉개지면 안 됨")
    }

    func test_a5_adjacentCurveCorner_doesNotBreakWa() {
        // ↓→ 코너를 ↘ 로 스치는 곡선 전환 — 인접 곡선 흡수 갈래.
        let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55),
                    CGVector(dx: 13, dy: 13), CGVector(dx: 55, dy: 0)]
        XCTAssertEqual(run(path), "와", "↓→ 코너의 ↘ 스침은 다음 획에 흡수돼야 함")
    }

    /// 의도적 ↑↓↑↓(ㅠ) 체인은 획 크기가 비슷해 흡수 대상이 아니다.
    func test_verticalChainYu_notCollapsedByBounceGuard() {
        let path = [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55),
                    CGVector(dx: 0, dy: -50), CGVector(dx: 0, dy: 50)]
        XCTAssertEqual(run(path), "유", "비슷한 크기의 체인 획은 흡수되면 안 됨")
    }

    // MARK: - 회귀 가드: 의도적 입력은 그대로 살아야 한다

    /// 세로 체인(v2.0 신규 경로) 자체는 온전해야 한다 — 실측 a5 에서 "입력은 되나"
    /// 라고 확인된 부분.
    func test_intentionalVerticalChains_stillWork() {
        XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55)]), "외")
        XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: 55, dy: 0)]), "와")
        XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55),
                            CGVector(dx: 55, dy: 0), CGVector(dx: -30, dy: 0)]), "왜",
                       "ㅙ 의 짧은 마지막 획(30pt, 직전 대비 0.55)은 트림되면 안 됨")
        XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: -55, dy: 0)]), "여")
        XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55),
                            CGVector(dx: -55, dy: 0), CGVector(dx: 55, dy: 0)]), "예")
    }

    /// 반전 임계 상향(10→15pt) 후에도 **적당한 크기의 의도적 되돌림**은 등록돼야
    /// 한다. 순정 실측 하한이 키폭 29% ≈ 15pt 이므로 그보다 넉넉한 25pt 로 확인.
    func test_moderateIntentionalReversal_stillRegisters() {
        XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 25)]), "외",
                       "25pt 되돌림(키폭 50%)은 의도적 획 — ㅗ 로 뭉개지면 안 됨")
        XCTAssertEqual(run([CGVector(dx: 55, dy: 0), CGVector(dx: -25, dy: 0)]), "애",
                       "→← 25pt 되돌림은 ㅐ")
    }

    /// 4획 모음의 짧아지기 쉬운 마지막 획 — 기존 특성화 가드 재확인.
    func test_fourStrokeVowels_shortFinalStroke_survives() {
        XCTAssertEqual(run([CGVector(dx: 55, dy: 0), CGVector(dx: -55, dy: 0),
                            CGVector(dx: 55, dy: 0), CGVector(dx: -30, dy: 0)]), "얘")
        XCTAssertEqual(run([CGVector(dx: -55, dy: 0), CGVector(dx: 55, dy: 0),
                            CGVector(dx: -55, dy: 0), CGVector(dx: 30, dy: 0)]), "예")
    }

    /// 빠른 입력(성긴 샘플링) ㅛ/ㅠ — 실측 B4 "기존보다 나빠지지 않으면 됨" 가드.
    /// 모음 전용 키(ㅡ) 단독 입력이라 결과는 자음 없는 standalone 모음이다.
    func test_fastYoYu_sparseSampling_stillWork() {
        let dashKey = (row: 3, column: 5)
        XCTAssertEqual(run(key: dashKey,
                           [CGVector(dx: 0, dy: -50), CGVector(dx: 0, dy: 50), CGVector(dx: 0, dy: -50)],
                           steps: 2), "ㅛ")
        XCTAssertEqual(run(key: dashKey,
                           [CGVector(dx: 0, dy: 50), CGVector(dx: 0, dy: -50), CGVector(dx: 0, dy: 50)],
                           steps: 2), "ㅠ")
    }
}

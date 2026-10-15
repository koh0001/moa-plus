import XCTest
import CoreGraphics

/// 이슈 #42 — 긋기 설정 두 가지가 저장·표시만 되고 판정에 반영되지 않던 문제.
///
/// 1. **방향별 모음 매핑 "비활성"**: ↗/↘ 를 비활성으로 꺼도 ㅣ/ㅡ 가 입력됐다. 정규화가 끈
///    대각선을 원시 방향 그대로 넘기고(`VowelResolver.normalizedDirection`), 트라이에 단독
///    `↗=ㅣ` `↘=ㅡ` 가 있어 그 노드에 닿았기 때문이다. ↖/↙ 는 트라이 루트에 노드가 없어 단독
///    획은 꺼졌지만 그 대신 ↙↗ = ㅢ 같은 멀티 스트로크까지 건너뛰어졌다. 결정: 끈 대각선은
///    **단독 획**으로 모음을 만들지 않고, 그 대각선으로 시작하는 멀티 스트로크(↘↖=ㅢ, ↙↗=ㅢ,
///    ↘↑=ㅢ, 첫 획 재해석)는 그대로 둔다. 기본 매핑은 무변화.
/// 2. **4방향 전용 모드**: 설정 화면이 "긋기 각도·방향 설정은 무시" 라며 전체 회전 슬라이더를
///    끄는데, 분석기는 저장된 `axisRotation` 을 계속 빼고 사분면을 나눴다. 열별 회전(세로 라인별
///    보정)은 4방향에서도 켜진 채 남는 별도 설정이라 유지한다.
final class GestureSettingsApplyTests: XCTestCase {

    // MARK: - 1. 비활성 대각선 — 리졸버

    private func resolver(_ configure: (inout SwipeProfile) -> Void) -> VowelResolver {
        var profile = SwipeProfile()
        configure(&profile)
        let r = VowelResolver()
        r.swipeProfile = profile
        return r
    }

    func test_disabledUpRight_singleStroke_producesNoVowel() {
        let r = resolver { $0.upRightMapping = .disabled }
        XCTAssertNil(r.resolve(directions: [.upRight]).vowel, "끈 ↗ 단독 획은 ㅣ 가 아니라 무입력")
        XCTAssertNil(r.peekVowel(directions: [.upRight]), "미리보기도 입력과 같아야 한다")
        XCTAssertNil(r.resolveSingleStroke(direction: .upRight),
                     "단일 획 API 도 무입력 (프로덕션 호출처는 없음 — 슬롯 B 는 아래 E2E 가 지킨다)")
        // 끈 첫 획은 건너뛰므로 뒤 획이 아직 모음을 만들 수 있다 — ↖ 를 끈 것과 같다.
        XCTAssertTrue(r.hasPotentialMatch(directions: [.upRight]), "끈 ↗ 뒤 획(↓ = ㅜ 등)이 남아 있다")
        let mirror = resolver { $0.upLeftMapping = .disabled }
        XCTAssertEqual(r.hasPotentialMatch(directions: [.upRight]),
                       mirror.hasPotentialMatch(directions: [.upLeft]), "끈 ↖ 와 같은 판정")
    }

    func test_disabledDownRight_singleStroke_producesNoVowel() {
        let r = resolver { $0.downRightMapping = .disabled }
        XCTAssertNil(r.resolve(directions: [.downRight]).vowel, "끈 ↘ 단독 획은 ㅡ 가 아니라 무입력")
        XCTAssertNil(r.peekVowel(directions: [.downRight]))
        XCTAssertNil(r.resolveSingleStroke(direction: .downRight))
        XCTAssertTrue(r.hasPotentialMatch(directions: [.downRight]), "↘↖ = ㅢ 로 이어질 수 있다")
    }

    /// 끈 ↘ 로 시작하는 멀티 스트로크는 유지 — 사용자 결정.
    func test_disabledDownRight_multiStroke_stillMakesEui() {
        let r = resolver { $0.downRightMapping = .disabled }
        XCTAssertEqual(r.resolve(directions: [.downRight, .upLeft]).vowel, .ㅢ, "↘↖ = ㅢ")
        XCTAssertEqual(r.resolve(directions: [.downRight, .up]).vowel, .ㅢ, "↘↑ = ㅢ")
        // 분석기가 첫 획 재해석 후보를 줘도 반전 동률은 ㅢ 우선 (순정 실측).
        XCTAssertEqual(r.resolve(directions: [.downRight, .upLeft], firstStrokeCardinal: .down).vowel, .ㅢ)
        XCTAssertEqual(r.resolve(directions: [.downRight, .upLeft], firstStrokeCardinal: .right).vowel, .ㅢ)
        XCTAssertEqual(r.peekVowel(directions: [.downRight, .upLeft]), .ㅢ)
    }

    /// 첫 획 재해석은 첫 획을 카디널로 바꾸므로 끈 대각선과 무관하게 유지된다.
    func test_disabledUpRight_reinterpretationPaths_keepWorking() {
        let r = resolver { $0.upRightMapping = .disabled }
        XCTAssertEqual(r.resolve(directions: [.upRight, .downLeft], firstStrokeCardinal: .right).vowel, .ㅐ,
                       "↗↙ 왕복 = ㅐ")
        XCTAssertEqual(r.resolve(directions: [.upRight, .right], firstStrokeCardinal: .right).vowel, .ㅏ,
                       "휘어진 한 획 ↗→ = ㅏ (`CurvedFirstStrokeTests`)")
    }

    /// 재해석 후보가 없을 때(둘째 획이 짧음) 트라이가 건너뛴 꼬리 뒤로 끈 ↗ 의 ㅣ 가 되살아나면
    /// 단독 획과 같은 버그다. 대신 끈 첫 획만 빠지고 뒤 획이 모음이 된다 — ↖/↙ 를 끈 경우
    /// (트라이 루트에 노드가 없어 첫 획만 건너뜀)와 같은 결과 (리뷰 반영).
    func test_disabledUpRight_withTail_dropsOnlyTheDisabledStroke() {
        let r = resolver { $0.upRightMapping = .disabled }
        XCTAssertEqual(r.resolve(directions: [.upRight, .downLeft]).vowel, .ㅜ, "↗(끔) ↙ → ↓ = ㅜ, ㅣ 아님")
        XCTAssertEqual(r.resolve(directions: [.upRight, .left]).vowel, .ㅓ, "↗(끔) ← → ← = ㅓ")
        XCTAssertEqual(r.peekVowel(directions: [.upRight, .left]), .ㅓ, "미리보기도 입력과 같다")
        XCTAssertTrue(r.hasPotentialMatch(directions: [.upRight, .left]))
    }

    func test_disabledDownRight_withTail_dropsOnlyTheDisabledStroke() {
        let r = resolver { $0.downRightMapping = .disabled }
        XCTAssertEqual(r.resolve(directions: [.downRight, .down]).vowel, .ㅜ, "↘(끔) ↓ → ↓ = ㅜ, ㅡ 아님")
        XCTAssertEqual(r.resolve(directions: [.downRight, .right]).vowel, .ㅏ, "↘(끔) → → → = ㅏ")
        XCTAssertEqual(r.resolve(directions: [.downRight, .up]).vowel, .ㅢ, "↘↑ = ㅢ 는 그대로 (건너뛰지 않음)")
    }

    /// 같은 "비활성" 설정은 네 대각선 모두 같은 규칙 — 끈 ↗/↘ 는 거울상인 끈 ↖/↙ 와 같은 모음을
    /// 낸다. 고치기 전에는 ↗/↘ 쪽만 제스처 전체가 무입력이 됐다.
    func test_disabledDiagonals_behaveLikeTheirMirrors() {
        let right = resolver {
            $0.upRightMapping = .disabled
            $0.downRightMapping = .disabled
        }
        let left = resolver {
            $0.upLeftMapping = .disabled
            $0.downLeftMapping = .disabled
        }
        // (끈 ↗/↘ 시퀀스, 끈 ↖/↙ 시퀀스, 기대 모음) — 뒤 획만 모음을 만든다.
        let cases: [([GestureDirection], [GestureDirection], Jungseong)] = [
            ([.upRight, .left],    [.upLeft, .left],     .ㅓ),
            ([.upRight, .right],   [.upLeft, .right],    .ㅏ),
            ([.upRight, .down],    [.upLeft, .down],     .ㅜ),
            ([.upRight, .downLeft], [.upLeft, .downRight], .ㅜ),
            ([.downRight, .down],  [.downLeft, .down],   .ㅜ),
            ([.downRight, .left],  [.downLeft, .left],   .ㅓ),
            ([.downRight, .right], [.downLeft, .right],  .ㅏ),
            ([.upRight, .left, .right], [.upLeft, .left, .right], .ㅔ),
        ]
        for (rightSeq, leftSeq, expected) in cases {
            XCTAssertEqual(right.resolve(directions: rightSeq).vowel, expected, "\(rightSeq)")
            XCTAssertEqual(left.resolve(directions: leftSeq).vowel, expected, "\(leftSeq)")
        }
        // 단독 획은 양쪽 모두 무입력.
        for d in [GestureDirection.upRight, .downRight] { XCTAssertNil(right.resolve(directions: [d]).vowel) }
        for d in [GestureDirection.upLeft, .downLeft] { XCTAssertNil(left.resolve(directions: [d]).vowel) }
    }

    /// 실제 입력은 2획 이상이면 대개 첫 획 재해석 후보(`firstStrokeCardinal`)를 함께 넘긴다.
    /// 재해석은 이 가드의 결과와 비교되므로, 꼬리가 같은 한 끈 ↗/↘ 와 끈 ↖/↙ 는 어떤 후보에서도
    /// 같은 모음을 내야 한다 — 가드가 모음만 지우던 때는 재해석이 동률에서도 이겨 갈라졌다
    /// (가파른 ↗← = ㅗ, ↖← = ㅓ). 미리보기도 확정과 같아야 한다.
    func test_disabledDiagonals_matchMirrors_underFirstStrokeReinterpretation() {
        let right = resolver {
            $0.upRightMapping = .disabled
            $0.downRightMapping = .disabled
        }
        let left = resolver {
            $0.upLeftMapping = .disabled
            $0.downLeftMapping = .disabled
        }
        // 꼬리(원시 방향)가 같은 쌍만 — 대각선 꼬리는 재해석된 첫 획에 따라 다른 카디널로 접힌다.
        let pairs: [([GestureDirection], [GestureDirection])] = [
            ([.upRight, .left],          [.upLeft, .left]),
            ([.upRight, .right],         [.upLeft, .right]),
            ([.upRight, .down],          [.upLeft, .down]),
            ([.upRight, .left, .right],  [.upLeft, .left, .right]),
            ([.downRight, .down],        [.downLeft, .down]),
            ([.downRight, .left],        [.downLeft, .left]),
            ([.downRight, .right],       [.downLeft, .right]),
        ]
        let candidates: [GestureDirection?] = [nil, .up, .down, .left, .right]
        for (rightSeq, leftSeq) in pairs {
            for cardinal in candidates {
                let r = right.resolve(directions: rightSeq, firstStrokeCardinal: cardinal).vowel
                let l = left.resolve(directions: leftSeq, firstStrokeCardinal: cardinal).vowel
                XCTAssertEqual(r, l, "\(rightSeq) vs \(leftSeq), 재해석 후보 \(String(describing: cardinal))")
                XCTAssertEqual(right.peekVowel(directions: rightSeq, firstStrokeCardinal: cardinal), r,
                               "미리보기 = 확정 \(rightSeq) \(String(describing: cardinal))")
            }
        }
        // 대표 사례: 가파른 ↗(↑ 스냅) + ← 는 1 대 1 동률이라 원래 해석(ㅓ), ↗↙ 왕복(→ 스냅)은 2 대 1 로 ㅐ.
        XCTAssertEqual(right.resolve(directions: [.upRight, .left], firstStrokeCardinal: .up).vowel, .ㅓ)
        XCTAssertEqual(right.resolve(directions: [.upRight, .downLeft], firstStrokeCardinal: .right).vowel, .ㅐ)
    }

    /// 판정은 **원래 첫 획**의 매핑으로 한다 — ↖(ㅣ) 는 정규화에서 ↗ 로 접히므로, 정규화된 첫
    /// 획으로 보면 끈 ↗ 로 오인해 ↖ 까지 꺼진다.
    func test_disabledUpRight_doesNotAffectUpLeft() {
        let r = resolver { $0.upRightMapping = .disabled }
        XCTAssertEqual(r.resolve(directions: [.upLeft]).vowel, .ㅣ)
        XCTAssertEqual(r.resolve(directions: [.upLeft, .downLeft]).vowel, .ㅣ, "↖ → ↗ 정규화 경로")
    }

    func test_disabledDownRight_doesNotAffectDownLeft() {
        let r = resolver { $0.downRightMapping = .disabled }
        XCTAssertEqual(r.resolve(directions: [.downLeft]).vowel, .ㅡ)
        XCTAssertEqual(r.resolve(directions: [.downLeft, .right]).vowel, .ㅡ, "↙ → ↘ 정규화 경로")
        XCTAssertEqual(r.resolve(directions: [.downLeft, .upRight]).vowel, .ㅢ, "↙↗ = ㅢ")
    }

    /// 기본 매핑(↗↖ = ㅣ, ↙↘ = ㅡ)은 그대로 — 클래식/확장형의 유일한 ㅣ/ㅡ 경로.
    func test_defaultMappings_unchanged() {
        let r = VowelResolver()
        XCTAssertEqual(r.resolve(directions: [.upRight]).vowel, .ㅣ)
        XCTAssertEqual(r.resolve(directions: [.upLeft]).vowel, .ㅣ)
        XCTAssertEqual(r.resolve(directions: [.downRight]).vowel, .ㅡ)
        XCTAssertEqual(r.resolve(directions: [.downLeft]).vowel, .ㅡ)
        XCTAssertEqual(r.resolve(directions: [.downRight, .upLeft]).vowel, .ㅢ)
        XCTAssertEqual(r.resolve(directions: [.upRight, .downLeft]).vowel, .ㅣ,
                       "재해석 후보 없는 ↗ + 꼬리 = ㅣ (기본 동작 보존)")
        XCTAssertEqual(r.peekVowel(directions: [.upRight]), .ㅣ)
        XCTAssertEqual(r.resolveSingleStroke(direction: .upRight), .ㅣ)
        XCTAssertEqual(r.resolveSingleStroke(direction: .downRight), .ㅡ)
        XCTAssertTrue(r.hasPotentialMatch(directions: [.upRight]))
    }

    /// 끈 ↖/↙ 의 단독 획 무입력·첫 획만 빠지는 경로·재해석은 그대로 (↙↗ = ㅢ 는 아래 테스트).
    func test_disabledUpLeftAndDownLeft_singleStrokeAndDropFirstPaths() {
        let r = resolver {
            $0.upLeftMapping = .disabled
            $0.downLeftMapping = .disabled
        }
        XCTAssertNil(r.resolve(directions: [.upLeft]).vowel)
        XCTAssertNil(r.resolve(directions: [.downLeft]).vowel)
        XCTAssertNil(r.resolveSingleStroke(direction: .upLeft))
        XCTAssertEqual(r.resolve(directions: [.upLeft, .downRight], firstStrokeCardinal: .left).vowel, .ㅔ,
                       "↖↘ = ㅔ 재해석 유지")
        XCTAssertEqual(r.resolve(directions: [.upLeft, .down]).vowel, .ㅜ,
                       "끈 첫 획만 빠지고 뒤 획이 모음 (기존 동작과 같은 결과)")
    }

    /// ㅢ 는 끈 대각선이 어느 쪽이든 유지 — 끈 ↙ 의 ↙↗ 는 끈 ↘ 의 ↘↖ 와 같다 (리뷰 반영).
    /// 고치기 전에는 끈 ↙ 를 원시 방향 그대로 넘겨 트라이 루트에서 건너뛰어졌고, 남은 ↗(→ ↑) 가
    /// ㅗ 가 됐다 — "단독 획만 끈다" 는 결정과 어긋난다.
    func test_disabledDownLeft_euiStillWorks_likeDisabledDownRight() {
        let left = resolver { $0.downLeftMapping = .disabled }
        let right = resolver { $0.downRightMapping = .disabled }
        XCTAssertNil(left.resolve(directions: [.downLeft]).vowel, "단독 획은 여전히 무입력")
        XCTAssertEqual(left.resolve(directions: [.downLeft, .upRight]).vowel, .ㅢ, "↙(끔)↗ = ㅢ")
        XCTAssertEqual(left.resolve(directions: [.downLeft, .up]).vowel, .ㅢ, "↙(끔)↑ = ㅢ")
        XCTAssertEqual(right.resolve(directions: [.downRight, .upLeft]).vowel, .ㅢ, "↘(끔)↖ = ㅢ")
        // 실제 입력은 첫 획 재해석 후보를 함께 넘긴다 — 반전 동률은 ㅢ 우선 (기본 매핑과 같음).
        let candidates: [GestureDirection?] = [nil, .down, .left]
        for cardinal in candidates {
            XCTAssertEqual(left.resolve(directions: [.downLeft, .upRight], firstStrokeCardinal: cardinal).vowel, .ㅢ,
                           "↙(끔)↗, 재해석 후보 \(String(describing: cardinal))")
            XCTAssertEqual(left.peekVowel(directions: [.downLeft, .upRight], firstStrokeCardinal: cardinal), .ㅢ,
                           "미리보기 = 확정")
        }
        // 뒤 획만 모음을 만드는 경로는 그대로.
        XCTAssertEqual(left.resolve(directions: [.downLeft, .down]).vowel, .ㅜ)
        XCTAssertEqual(left.resolve(directions: [.downLeft, .right]).vowel, .ㅏ)
    }

    /// 6방향 프리셋은 쓰지 않는 대각선을 매핑이 아니라 섹터 폭 0 으로 끈다 — 살아 있는 쌍 무변화.
    func test_sixWayPresets_liveDiagonalsUnchanged() {
        let right = VowelResolver()
        right.swipeProfile = SwipeProfile().applyingPreset(.sixWayRight)
        XCTAssertEqual(right.resolve(directions: [.upRight]).vowel, .ㅣ)
        XCTAssertEqual(right.resolve(directions: [.downLeft]).vowel, .ㅡ)
        XCTAssertEqual(right.resolve(directions: [.downLeft, .upRight]).vowel, .ㅢ)

        let left = VowelResolver()
        left.swipeProfile = SwipeProfile().applyingPreset(.sixWayLeft)
        XCTAssertEqual(left.resolve(directions: [.upLeft]).vowel, .ㅣ)
        XCTAssertEqual(left.resolve(directions: [.downRight]).vowel, .ㅡ)
        XCTAssertEqual(left.resolve(directions: [.downRight, .upLeft]).vowel, .ㅢ)
    }

    // MARK: - 1. 비활성 대각선 — 뷰모델 E2E (자음 키 · 슬롯 B)
    //
    // 리졸버 단위 테스트는 `swipeProfile` 을 직접 넣으므로, 뷰모델이 제스처 시작마다 설정을
    // 주입하는 경로까지는 지키지 못한다. 실제 경로(gestureStarted → Moved → Ended)로 재생한다.

    /// ㅁ (row 2, col 1).
    private static let mieumKey = (row: 2, column: 1)

    private func withGestureSettings(_ configure: (inout GestureSettings) -> Void,
                                     _ body: (KeyboardViewModel) -> Void) {
        let settings = KeyboardSettings.shared
        let originalGesture = settings.gestureSettings
        let originalDerivation = settings.consonantDiagonalDerivationEnabled
        let originalLayout = settings.layoutCustomization
        defer {
            settings.gestureSettings = originalGesture
            settings.consonantDiagonalDerivationEnabled = originalDerivation
            settings.layoutCustomization = originalLayout
        }
        var gs = GestureSettings.default
        configure(&gs)
        settings.gestureSettings = gs
        settings.consonantDiagonalDerivationEnabled = false   // 순정 모아키 (기본값)
        var lc = originalLayout
        lc.vowelKeyBehavior = .gestureMulti                   // 기본값
        settings.layoutCustomization = lc
        body(KeyboardViewModel())
    }

    /// `CompoundVowelPathTests.drive` 와 같은 하니스. 화면 좌표는 y 가 아래로 커진다.
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

    private func driveSlotB(_ vm: KeyboardViewModel, segment: CGVector) {
        let origin = CGPoint(x: 100, y: 100)
        vm.slotBVowelGestureStarted(at: origin)
        for i in 1...8 {
            let f = CGFloat(i) / 8
            vm.slotBVowelGestureMoved(to: CGPoint(x: origin.x + segment.dx * f, y: origin.y + segment.dy * f))
        }
        vm.slotBVowelGestureEnded()
    }

    private static let upRight60 = CGVector(dx: 42, dy: -42)
    private static let downRight60 = CGVector(dx: 42, dy: 42)
    private static let upLeft60 = CGVector(dx: -42, dy: -42)
    private static let downLeft60 = CGVector(dx: -42, dy: 42)

    func test_e2e_consonantKey_defaultUpRight_isMi() {
        withGestureSettings({ _ in }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.upRight60])
            XCTAssertEqual(vm.composingText, "미")
        }
    }

    func test_e2e_consonantKey_disabledUpRight_leavesConsonantOnly() {
        withGestureSettings({ $0.swipeProfile.upRightMapping = .disabled }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.upRight60])
            XCTAssertEqual(vm.composingText, "ㅁ", "끈 ↗ 는 모음 없이 자음만 (↖ 를 끈 것과 같은 동작)")
        }
    }

    func test_e2e_consonantKey_disabledDownRight_leavesConsonantOnly_butEuiStillWorks() {
        withGestureSettings({ $0.swipeProfile.downRightMapping = .disabled }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.downRight60])
            XCTAssertEqual(vm.composingText, "ㅁ", "끈 ↘ 단독 획 = 무입력")
        }
        withGestureSettings({ $0.swipeProfile.downRightMapping = .disabled }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.downRight60, Self.upLeft60])
            XCTAssertEqual(vm.composingText, "믜", "끈 ↘ 로 시작하는 ↘↖ = ㅢ 는 유지")
        }
    }

    /// 끈 ↙ 도 ↙↗ = ㅢ — 끄지 않은 것과 같다 (리뷰 반영, 사용자 결정 2026-10-16). 고치기 전에는 끈 ↙ 가
    /// 트라이에서 건너뛰어져(남은 ↗ = ↑ 한 간선) 첫 획 재해석 ←→ = ㅔ 에 밀려 "메" 가 됐다(실측).
    func test_e2e_consonantKey_disabledDownLeft_euiStillWorks() {
        withGestureSettings({ _ in }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.downLeft60, Self.upRight60])
            XCTAssertEqual(vm.composingText, "믜", "기본: ↙↗ = ㅢ")
        }
        withGestureSettings({ $0.swipeProfile.downLeftMapping = .disabled }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.downLeft60, Self.upRight60])
            XCTAssertEqual(vm.composingText, "믜", "끈 ↙ 로 시작하는 ↙↗ = ㅢ 는 유지")
        }
        withGestureSettings({ $0.swipeProfile.downLeftMapping = .disabled }) { vm in
            drive(vm, key: Self.mieumKey, segments: [Self.downLeft60])
            XCTAssertEqual(vm.composingText, "ㅁ", "끈 ↙ 단독 획 = 무입력")
        }
    }

    func test_e2e_slotBVowelKey_disabledUpRight_insertsNothing() {
        withGestureSettings({ _ in }) { vm in
            driveSlotB(vm, segment: Self.upRight60)
            XCTAssertEqual(vm.composingText, "ㅣ", "기본: 모음 키 ↗ = ㅣ")
        }
        withGestureSettings({ $0.swipeProfile.upRightMapping = .disabled }) { vm in
            driveSlotB(vm, segment: Self.upRight60)
            XCTAssertEqual(vm.composingText, "", "끈 ↗ 는 모음 키에서도 무입력")
        }
    }

    // MARK: - 2. 4방향 전용 모드 — 전체 회전 무시

    /// 한 번에 곧게 그은 획의 분석 결과.
    private func strokes(at degrees: Double, settings: GestureSettings, column: Int = 0) -> [GestureDirection] {
        let analyzer = GestureAnalyzer(settings: settings, columnId: column)
        let start = CGPoint(x: 200, y: 200)
        let r = degrees * .pi / 180
        let dx = 80 * CGFloat(cos(r)), dy = -80 * CGFloat(sin(r))
        analyzer.addPoint(start)
        for i in 1...10 {
            let t = CGFloat(i) / 10
            analyzer.addPoint(CGPoint(x: start.x + dx * t, y: start.y + dy * t))
        }
        return analyzer.finalizeGesture()
    }

    private func fourWay(axisRotation: Double) -> GestureSettings {
        var gs = GestureSettings.default
        gs.swipeProfile.fourWayMode = true
        gs.swipeProfile.axisRotation = axisRotation
        return gs
    }

    func test_effectiveAxisRotation_isZeroOnlyInFourWayMode() {
        var p = SwipeProfile()
        p.axisRotation = 12.5
        XCTAssertEqual(p.effectiveAxisRotation, 12.5)
        p.fourWayMode = true
        XCTAssertEqual(p.effectiveAxisRotation, 0)
        XCTAssertEqual(p.axisRotation, 12.5, "저장값은 지우지 않는다 — 4방향을 끄면 그대로 돌아온다")
    }

    /// 인식기와 긋기 실시간 테스트가 같이 쓰는 회전 식 — 전체 회전(4방향이면 0) + 열별 회전, 열 0 은 전체만.
    func test_recognizerRotationOffset_sumsGlobalAndColumnRotation() {
        var gs = GestureSettings.default
        gs.swipeProfile.axisRotation = 20
        XCTAssertEqual(gs.recognizerRotationOffset(forColumn: 1), 23, accuracy: 1e-9, "전체 20° + 1열 기본 3°")
        XCTAssertEqual(gs.recognizerRotationOffset(forColumn: 3), 20, accuracy: 1e-9, "가운데 열은 열 회전 0°")
        XCTAssertEqual(gs.recognizerRotationOffset(forColumn: 0), 20, accuracy: 1e-9, "열 정보 없음 = 전체 회전만")
        gs.swipeProfile.fourWayMode = true
        XCTAssertEqual(gs.recognizerRotationOffset(forColumn: 1), 3, accuracy: 1e-9, "4방향: 전체 회전 0, 열 회전 유지")
        XCTAssertEqual(gs.recognizerRotationOffset(forColumn: 0), 0, accuracy: 1e-9)
        gs.columnCorrectionEnabled = false
        XCTAssertEqual(gs.recognizerRotationOffset(forColumn: 1), 0, accuracy: 1e-9, "보정을 끄면 열 회전도 0")
    }

    /// 저장된 전체 회전 20° 는 4방향에서 0° 와 똑같이 판정돼야 한다 (전 각도 스윕).
    func test_fourWay_storedAxisRotation_classifiesAsZero() {
        let rotated = fourWay(axisRotation: 20)
        let zero = fourWay(axisRotation: 0)
        for deg in stride(from: 2.5, to: 360, by: 5) {
            XCTAssertEqual(strokes(at: deg, settings: rotated), strokes(at: deg, settings: zero), "\(deg)°")
        }
        XCTAssertEqual(strokes(at: 60, settings: rotated), [.up], "60° = ↑ (회전 20° 를 빼면 40° = → 였다)")
        XCTAssertEqual(strokes(at: 330, settings: rotated), [.right], "330° = → (회전을 빼면 310° = ↓ 였다)")
    }

    /// 4방향이 꺼져 있으면 전체 회전은 예전처럼 적용된다.
    func test_eightWay_axisRotation_stillRotates() {
        var gs = GestureSettings.default
        XCTAssertEqual(strokes(at: 70, settings: gs), [.up], "기준: 회전 0° 에서 70° = ↑")
        gs.swipeProfile.axisRotation = 20
        XCTAssertEqual(strokes(at: 70, settings: gs), [.upRight], "회전 20°: 70° → 50° = ↗")
    }

    /// 열별 회전은 세로 라인별 보정 토글이 다스리는 별도 설정 — 4방향에서도 유지되고 토글로 끈다.
    func test_fourWay_columnRotation_stillApplies() {
        var gs = fourWay(axisRotation: 20)
        gs.columnOverrides[0].rotationOffsetDeg = 10   // 1열
        XCTAssertEqual(strokes(at: 50, settings: gs, column: 1), [.right], "열 회전 10°: 50° → 40° = →")
        XCTAssertEqual(strokes(at: 50, settings: gs, column: 0), [.up], "열 보정 없는 키는 회전 없음")
        gs.columnCorrectionEnabled = false
        XCTAssertEqual(strokes(at: 50, settings: gs, column: 1), [.up], "보정을 끄면 열 회전도 0")
    }

    /// 실제 경로: 자음 키 ㅁ(1열, 기본 열 회전 +3°)에서 60° 긋기.
    /// 고치기 전에는 전체 회전 20° 를 빼 37° = → 로 판정돼 "마" 가 됐다.
    func test_e2e_fourWay_consonantKey_ignoresAxisRotation() {
        withGestureSettings({
            $0.swipeProfile.fourWayMode = true
            $0.swipeProfile.axisRotation = 20
        }) { vm in
            drive(vm, key: Self.mieumKey, segments: [CGVector(dx: 40, dy: -69)])   // 80pt @ 60°
            XCTAssertEqual(vm.composingText, "모")
        }
    }
}

import XCTest
@testable import MoaPlusKeyboard

/// 순정 삼성 모아키 관찰 영상(`moakey_screen_recording/`, 2026-08 판독)에서
/// **확정된** 규칙을 고정하는 테스트. 각 케이스 주석의 근거는
/// `docs/MOAKEY_VIDEO_FINDINGS.md` 의 섹션 번호를 가리킨다.
///
/// ⚠️ 여기 단언들은 순정 실측이 근거다 — 깨뜨리는 변경은 순정 이탈이다.
final class MoakeyVideoVerifiedSpecTests: XCTestCase {

    // MARK: - VowelResolver: 세로 체인 확장 (영상 A8-A13 §2)

    private var resolver: VowelResolver!

    override func setUp() {
        super.setUp()
        resolver = VowelResolver()
    }

    override func tearDown() {
        resolver = nil
        super.tearDown()
    }

    /// 팝업 체인 고→괴→과 실측: ㅚ(↑↓) 뒤 →는 ㅘ.
    func testVerticalChain_upDownRight_isWa() {
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .right]).vowel, .ㅘ)
    }

    /// 팝업 체인 고→괴→과→괘 실측: ↑↓→← = ㅙ. (기존 ↑→← 도 그대로 성립)
    func testVerticalChain_upDownRightLeft_isWae() {
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .right, .left]).vowel, .ㅙ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right, .left]).vowel, .ㅙ)
    }

    /// 팝업 체인 보→뵈→뵤→뷰 실측: ㅛ(↑↓↑) 뒤 ↓는 ㅠ.
    func testVerticalChain_upDownUpDown_isYu() {
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .up, .down]).vowel, .ㅠ)
    }

    /// 역방향 4획째(↓↑↓↑)는 순정에서 무시된다 — ㅠ 유지.
    func testDownUpDownUp_staysYu() {
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .down, .up]).vowel, .ㅠ)
    }

    /// 세로 체인 ← 갈래 (영상 R7: ↑↓←→=ㅖ 5/5, ↓↑←→=ㅞ. 팝업 체인
    /// 오→외→여→예 / 두→뒤→둬→뒈로 중간 상태까지 확인).
    func testVerticalChainLeftBranch() {
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .left]).vowel, .ㅕ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .down, .left, .right]).vowel, .ㅖ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .left]).vowel, .ㅝ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up, .left, .right]).vowel, .ㅞ)
    }

    // MARK: - VowelResolver: 첫 획 카디널 재해석 (영상 C §3, A8-A13 §3, F 미해결 항목)

    /// ★리뷰 "ㅐ 방향이 순정과 다름"의 원인 교정. 순정: 자음 키에서 ↗(≤45°)로
    /// 나갔다 ↙로 되돌아오면 ㅐ (C 섹션 4/4, 팝업 ㅣ→ㅐ 승격 확인).
    func testUpRightRoundTrip_withCardinalRight_isAe() {
        let r = resolver.resolve(directions: [.upRight, .downLeft], firstStrokeCardinal: .right)
        XCTAssertEqual(r.vowel, .ㅐ)
    }

    /// ↗ 후 ← (영상 A12 시도 11: 내/ㅐ).
    func testUpRightThenLeft_withCardinalRight_isAe() {
        let r = resolver.resolve(directions: [.upRight, .left], firstStrokeCardinal: .right)
        XCTAssertEqual(r.vowel, .ㅐ)
    }

    /// ↗ 후 ←→← 4획 (영상 A12 시도 10: 얘/ㅒ).
    func testUpRightThenLeftRightLeft_withCardinalRight_isYae() {
        let r = resolver.resolve(directions: [.upRight, .left, .right, .left], firstStrokeCardinal: .right)
        XCTAssertEqual(r.vowel, .ㅒ)
    }

    /// ↖ 후 ↘ (영상 A8 시도 6: 게/ㅔ, F1 #8·F3 #3: ←후↖/↑ = ㅔ 상호 확인).
    func testUpLeftThenDownRight_withCardinalLeft_isE() {
        let r = resolver.resolve(directions: [.upLeft, .downRight], firstStrokeCardinal: .left)
        XCTAssertEqual(r.vowel, .ㅔ)
    }

    /// ↙(수직 쪽) ↑↓ (영상 A9 시도 5: 규/ㅠ) — 재해석이 ㅢ(2간선)보다 많은
    /// 3간선을 매칭해 이긴다.
    func testDownLeftSteep_upDown_withCardinalDown_isYu() {
        let r = resolver.resolve(directions: [.downLeft, .up, .down], firstStrokeCardinal: .down)
        XCTAssertEqual(r.vowel, .ㅠ)
    }

    /// ↙(수평 쪽) →← (영상 A11 시도 4: 겨/ㅕ).
    func testDownLeftShallow_rightLeft_withCardinalLeft_isYeo() {
        let r = resolver.resolve(directions: [.downLeft, .right, .left], firstStrokeCardinal: .left)
        XCTAssertEqual(r.vowel, .ㅕ)
    }

    // MARK: - 수평 획 뒤 직각 스냅 (영상 R2 6/6, F1 #8·F3 #3, B2 #7)

    /// → 후 ↓/↑ = ㅐ (직각 획이 수평 반전 ←로 스냅).
    func testRightThenPerpendicular_isAe() {
        XCTAssertEqual(resolver.resolve(directions: [.right, .down]).vowel, .ㅐ)
        XCTAssertEqual(resolver.resolve(directions: [.right, .up]).vowel, .ㅐ)
    }

    /// ← 후 ↑/↓ = ㅔ (F1 #8: ←↖=ㅔ, B2 #7: ←↓=ㅔ).
    func testLeftThenPerpendicular_isE() {
        XCTAssertEqual(resolver.resolve(directions: [.left, .up]).vowel, .ㅔ)
        XCTAssertEqual(resolver.resolve(directions: [.left, .down]).vowel, .ㅔ)
    }

    /// → ↓ → = ㅑ (R2 #5: 갸 — 직각 스냅 후 축 위에서 계속 번갈아 감).
    func testRightDownRight_isYa() {
        XCTAssertEqual(resolver.resolve(directions: [.right, .down, .right]).vowel, .ㅑ)
    }

    /// 수직 시작의 직각 후속은 스냅하지 않는다 — 트라이에 유효 간선이 실재
    /// (↑→=ㅘ, ↓←=ㅝ, R1 8/8 재확인).
    func testVerticalFirstPerpendicular_notSnapped() {
        XCTAssertEqual(resolver.resolve(directions: [.up, .right]).vowel, .ㅘ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .left]).vowel, .ㅝ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .down]).vowel, .ㅚ)
        XCTAssertEqual(resolver.resolve(directions: [.down, .up]).vowel, .ㅟ)
    }

    // MARK: - 재해석이 이기면 안 되는 회귀 가드

    /// ★★ㅢ 회귀 가드 (영상 B3 4/4, E3): ↙ 후 ↗ 반전은 천지인 ㅡ+ㅣ = ㅢ.
    /// 재해석 후보(←→=ㅔ)와 간선 수가 같으므로(2=2) 기존 해석이 이겨야 한다.
    func testDownLeftThenUpRight_staysUi() {
        let r = resolver.resolve(directions: [.downLeft, .upRight], firstStrokeCardinal: .left)
        XCTAssertEqual(r.vowel, .ㅢ)
    }

    /// 특성화 보존: ↙↑→ 는 기존 ㅢ 유지 (재해석 ←(skip↑)→=ㅔ 는 2간선 동률).
    func testDownLeftUpRight_characterizationPreserved() {
        let r = resolver.resolve(directions: [.downLeft, .up, .right], firstStrokeCardinal: .left)
        XCTAssertEqual(r.vowel, .ㅢ)
    }

    /// 단독 대각선은 재해석 대상이 아니다 (↗=ㅣ, ↙=ㅡ — 클래식/확장형의 유일한
    /// ㅣ/ㅡ 경로. 영상 B1/B2 17회 예외 없음).
    func testSingleDiagonals_unchanged() {
        XCTAssertEqual(resolver.resolve(directions: [.upRight]).vowel, .ㅣ)
        XCTAssertEqual(resolver.resolve(directions: [.upLeft]).vowel, .ㅣ)
        XCTAssertEqual(resolver.resolve(directions: [.downLeft]).vowel, .ㅡ)
        XCTAssertEqual(resolver.resolve(directions: [.downRight]).vowel, .ㅡ)
    }

    /// firstStrokeCardinal 이 없으면(구 호출 경로) 동작 불변.
    func testWithoutCardinal_behaviourUnchanged() {
        XCTAssertEqual(resolver.resolve(directions: [.upRight, .downLeft]).vowel, .ㅣ)
        XCTAssertEqual(resolver.resolve(directions: [.up, .right]).vowel, .ㅘ)
    }

    // MARK: - E2E: 자음 키 드래그 → 조합 (KeyboardViewModel + GestureAnalyzer)

    /// ㅇ (row 2, col 3).
    private static let ieungKey = (row: 2, column: 3)

    private func driveIeung(_ segments: [CGVector], stepsPerSegment: Int = 8) -> String {
        let vm = KeyboardViewModel()
        var point = CGPoint(x: 150, y: 150)
        vm.gestureStarted(row: Self.ieungKey.row, column: Self.ieungKey.column, at: point)
        for segment in segments {
            let origin = point
            for i in 1...stepsPerSegment {
                let f = CGFloat(i) / CGFloat(stepsPerSegment)
                vm.gestureMoved(to: CGPoint(x: origin.x + segment.dx * f,
                                            y: origin.y + segment.dy * f))
            }
            point = CGPoint(x: origin.x + segment.dx, y: origin.y + segment.dy)
        }
        vm.gestureEnded(row: Self.ieungKey.row, column: Self.ieungKey.column)
        return vm.composingText
    }

    private func withDefaultGestureSettings(_ body: () -> Void) {
        let original = KeyboardSettings.shared.gestureSettings
        let originalDiagonal = KeyboardSettings.shared.consonantDiagonalDerivationEnabled
        defer {
            KeyboardSettings.shared.gestureSettings = original
            KeyboardSettings.shared.consonantDiagonalDerivationEnabled = originalDiagonal
        }
        KeyboardSettings.shared.gestureSettings = .default
        KeyboardSettings.shared.consonantDiagonalDerivationEnabled = false
        body()
    }

    /// ↗(약 40°) 나감 + ↙ 복귀 = 애 (영상 C1: 순정 촬영자의 습관 경로 4/4).
    func testE2E_diagonalRoundTrip_producesAe() {
        withDefaultGestureSettings {
            let text = driveIeung([CGVector(dx: 60, dy: -50), CGVector(dx: -70, dy: 58)])
            XCTAssertEqual(text, "애")
        }
    }

    /// ↖ 나감 + ↘ 복귀 = 에 (영상 A8 시도 6 대칭 경로).
    func testE2E_upLeftRoundTrip_producesE() {
        withDefaultGestureSettings {
            let text = driveIeung([CGVector(dx: -60, dy: -50), CGVector(dx: 70, dy: 58)])
            XCTAssertEqual(text, "에")
        }
    }

    /// ↑↓→ = 와 (영상 A12 시도 6 팝업 고→괴→과).
    func testE2E_upDownRight_producesWa() {
        withDefaultGestureSettings {
            let text = driveIeung([CGVector(dx: 0, dy: -60),
                                   CGVector(dx: 0, dy: 66),
                                   CGVector(dx: 60, dy: 0)])
            XCTAssertEqual(text, "와")
        }
    }

    /// ↙ 후 ↗ 반전 = 의 (영상 B3 4/4 — E2E 회귀 가드).
    func testE2E_downLeftReversal_producesUi() {
        withDefaultGestureSettings {
            let text = driveIeung([CGVector(dx: -60, dy: 50), CGVector(dx: 66, dy: -58)])
            XCTAssertEqual(text, "의")
        }
    }

    /// 단독 대각선 = 이/으 (영상 B1/B2 — E2E 회귀 가드).
    func testE2E_singleDiagonals_produceIAndEu() {
        withDefaultGestureSettings {
            XCTAssertEqual(driveIeung([CGVector(dx: 55, dy: -50)]), "이")
            XCTAssertEqual(driveIeung([CGVector(dx: -55, dy: 50)]), "으")
        }
    }

    /// ↑↓←→ (진짜 획 4개) = 예 (영상 R7 5/5).
    func testE2E_upDownLeftRight_producesYe() {
        withDefaultGestureSettings {
            let text = driveIeung([CGVector(dx: 0, dy: -60),
                                   CGVector(dx: 0, dy: 66),
                                   CGVector(dx: -60, dy: 0),
                                   CGVector(dx: 66, dy: 0)])
            XCTAssertEqual(text, "예")
        }
    }

    /// ★ㅚ 꼬리 회귀 가드 (R7 판독 경고): ↑↓←=ㅕ 간선이 생겨도, 손 떼며
    /// 생기는 작은 ← 꼬리(15pt)가 ㅚ를 ㅕ로 승격시키면 안 된다. ㅗ가 통째로
    /// 사라지는 오타라 ㅚ→ㅘ 계열보다 심각하다.
    func testE2E_upDownWithSmallLeftTail_staysOe() {
        withDefaultGestureSettings {
            let text = driveIeung([CGVector(dx: 0, dy: -60),
                                   CGVector(dx: 0, dy: 66),
                                   CGVector(dx: -15, dy: 2)])
            XCTAssertEqual(text, "외")
        }
    }

    // MARK: - HangulComposer: ㆍ 토글 (영상 H2)

    /// ㅗ↔ㅛ / ㅜ↔ㅠ 무한 토글 (영상 H2: 키 하이라이트로 확정).
    func testDotToggle_yoAndO() {
        let composer = HangulComposer()
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅗ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "교")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "고", "ㅛ+ㆍ=ㅗ (순정 토글)")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "교", "ㅗ+ㆍ=ㅛ 재승격")
    }

    func testDotToggle_yuAndU() {
        let composer = HangulComposer()
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅜ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "규")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "구", "ㅠ+ㆍ=ㅜ (순정 토글)")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "규")
    }

    /// 자음 없는 standalone 모음에서도 토글 (영상 H2 전반부).
    func testDotToggle_standaloneVowel() {
        let composer = HangulComposer()
        _ = composer.inputJungseong(.ㅡ)
        _ = composer.inputJungseong(.ㆍ)   // ㅡ+ㆍ=ㅜ
        _ = composer.inputJungseong(.ㆍ)   // ㅜ+ㆍ=ㅠ
        XCTAssertEqual(composer.currentComposingCharacter, "ㅠ")
        _ = composer.inputJungseong(.ㆍ)   // ㅠ+ㆍ=ㅜ (토글)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅜ")
    }

    // MARK: - HangulComposer: 자소 단위 백스페이스 (영상 G5)

    /// 가갬 →⌫ 가개 →⌫ 가ㄱ →⌫ 가 (영상 G5 타임라인 그대로).
    func testBackspace_jasoUnit_sequence() {
        let composer = HangulComposer()
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄱ)   // 받침 시도 → 각? 아니, 다음 입력 대기
        _ = composer.inputJungseong(.ㅏ)  // 받침 ㄱ 이월 → 가가
        _ = composer.inputJungseong(.ㅣ)  // ㅏ+ㅣ=ㅐ → 가개
        _ = composer.inputChoseong(.ㅁ)   // 받침 → 가갬
        XCTAssertEqual(composer.composedText + (composer.currentComposingCharacter.map(String.init) ?? ""), "가갬")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "개", "받침 ㅁ 만 삭제")
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ", "중성 ㅐ 통째 삭제 — ㅏ로 되감지 않음")
        _ = composer.deleteBackward()
        XCTAssertNil(composer.currentComposingCharacter, "초성 ㄱ 삭제")
        XCTAssertEqual(composer.composedText, "가")
    }
}

import XCTest
import CoreGraphics
@testable import MoaPlusKeyboard

/// 메일 제보(2026-09-24, "오타가 너무 심해서 쓸 수가 없다") 로그의 궤적 재생.
///
/// 한 번에 살짝 휘어 그은 획이 방향 구역 경계를 넘으며 두 획으로 나뉘고(`↗→`, `↖←`),
/// 첫 획 재해석(↗29° → →)이 `[→, →]` = ㅏ 로 입력 전체를 설명하는데도 원래 해석
/// `[↗, →]` 과 **맞은 간선 수가 1 로 같아** 원래 해석(ㅣ)이 이겼다 — "오타" 가 "오티" 로.
/// 규칙: 맞은 간선 수가 같으면 **버린 획이 적은 해석**을 고른다. ↙↗=ㅢ 는 두 해석 모두
/// 획을 버리지 않으므로 기존대로 원래 해석이 이긴다(`MoakeyVideoVerifiedSpecTests`).
final class CurvedFirstStrokeTests: XCTestCase {

    /// 꼭짓점 사이를 4pt 간격으로 채워 분석기에 넣고 모음을 돌려준다.
    private func vowel(_ strokes: [(len: CGFloat, deg: Double)], column: Int = 2) -> Jungseong? {
        let settings = GestureSettings.default
        let analyzer = GestureAnalyzer(settings: settings, columnId: column)
        var p = CGPoint(x: 200, y: 200)
        analyzer.addPoint(p)
        for s in strokes {
            let r = s.deg * .pi / 180
            let dx = s.len * CGFloat(cos(r)), dy = -s.len * CGFloat(sin(r))
            let steps = max(1, Int((s.len / 4).rounded()))
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                analyzer.addPoint(CGPoint(x: p.x + dx * t, y: p.y + dy * t))
            }
            p = CGPoint(x: p.x + dx, y: p.y + dy)
        }
        let detail = analyzer.finalizeGestureDetailed()
        let resolver = VowelResolver()
        resolver.swipeProfile = settings.swipeProfile
        return resolver.resolve(directions: detail.directions,
                                firstStrokeCardinal: detail.firstStrokeCardinal).vowel
    }

    // MARK: - 리졸버 규칙 (분석기 무관)

    func test_resolver_curvedRightStroke_isA() {
        let r = VowelResolver()
        XCTAssertEqual(r.resolve(directions: [.upRight, .right], firstStrokeCardinal: .right).vowel, .ㅏ)
    }

    func test_resolver_curvedLeftStroke_isEo() {
        let r = VowelResolver()
        XCTAssertEqual(r.resolve(directions: [.upLeft, .left], firstStrokeCardinal: .left).vowel, .ㅓ)
    }

    /// 두 해석 모두 획을 버리지 않는 동점은 여전히 원래 해석 — 천지인 ㅡ+ㅣ=ㅢ.
    func test_resolver_reversalTie_keepsEui() {
        let r = VowelResolver()
        XCTAssertEqual(r.resolve(directions: [.downLeft, .upRight], firstStrokeCardinal: .left).vowel, .ㅢ)
    }

    /// 단독 대각선은 재해석 대상이 아니다 (후속 획이 없음).
    func test_resolver_singleDiagonal_staysI() {
        let r = VowelResolver()
        XCTAssertEqual(r.resolve(directions: [.upRight], firstStrokeCardinal: .right).vowel, .ㅣ)
    }

    // MARK: - 제보 로그 궤적 재생 (분석기 + 리졸버)

    /// `[ㅌ] raw ↗27(29°) →74(8°) ⇒ ㅣ` — "오타" 가 "오티" 로.
    func test_e2e_reportTrace_ta_notTi() {
        XCTAssertEqual(vowel([(27, 29), (74, 8)]), .ㅏ)
    }

    /// `[ㅌ] raw ↗36(19°) →49(13°) ⇒ ㅣ`
    func test_e2e_reportTrace_shallowCurve_isA() {
        XCTAssertEqual(vowel([(36, 19), (49, 13)]), .ㅏ)
    }

    /// `[ㅇ] raw ↖23(139°) ←52(183°) ⇒ ㅣ` — "어" 가 "이" 로.
    func test_e2e_reportTrace_eo_notI() {
        XCTAssertEqual(vowel([(23, 139), (52, 183)]), .ㅓ)
    }

    /// 회귀: 곧은 ↗ 는 그대로 ㅣ, 곧은 → 는 ㅏ.
    func test_e2e_straightStrokes_unchanged() {
        XCTAssertEqual(vowel([(60, 45)]), .ㅣ)
        XCTAssertEqual(vowel([(60, 5)]), .ㅏ)
    }
}

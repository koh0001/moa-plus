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

    // MARK: - 짧은 이어짐 (같은 제보자 재제보, 2026-10-06 로그 v2.2.5 → 수정 v2.2.6)
    //
    // 위 수정은 두 번째 조각이 키폭의 0.6배(54pt 기준 32.4pt) 이상일 때만 켜졌다
    // (`reinterpretMinSecondStrokeRatio`). 휘어 그은 획의 나머지가 짧으면(20~26pt) 재해석이
    // 꺼져 첫 조각 이름(↙=ㅡ, ↗=ㅣ)이 그대로 남았다. 곧은 조각으로는 이 분할이 재현되지
    // 않아(첫 조각부터 → 로 잡힘) 실제처럼 휘는 경로로 재생한다 — 아래 경로는 현재 분석기에서
    // 로그와 같은 분할을 만든다.

    /// 조각마다 진행 방향이 `from`→`to` 로 선형 회전하는 경로를 3pt 간격으로 넣는다.
    private func replay(_ pieces: [(len: CGFloat, from: Double, to: Double)],
                        column: Int) -> (strokes: [GestureDirection], magnitudes: [CGFloat],
                                         vowel: Jungseong?, preview: Jungseong?,
                                         raw: [GestureDirection]) {
        let settings = GestureSettings.default
        let analyzer = GestureAnalyzer(settings: settings, columnId: column)
        analyzer.keyWidth = 54
        var p = CGPoint(x: 200, y: 200)
        analyzer.addPoint(p)
        for piece in pieces {
            let n = max(1, Int((piece.len / 3).rounded()))
            let step = piece.len / CGFloat(n)
            for i in 0..<n {
                let deg = piece.from + (piece.to - piece.from) * (Double(i) + 0.5) / Double(n)
                let r = deg * .pi / 180
                p = CGPoint(x: p.x + step * CGFloat(cos(r)), y: p.y - step * CGFloat(sin(r)))
                analyzer.addPoint(p)
            }
        }
        let resolver = VowelResolver()
        resolver.swipeProfile = settings.swipeProfile
        let preview = resolver.peekVowel(directions: analyzer.getDirections(),
                                         firstStrokeCardinal: analyzer.currentFirstStrokeCardinal())
        let strokes = analyzer.finalizedStrokeInfos()
        let detail = analyzer.finalizeGestureDetailed()
        let vowel = resolver.resolve(directions: detail.directions,
                                     firstStrokeCardinal: detail.firstStrokeCardinal).vowel
        return (strokes.map(\.direction), strokes.map(\.magnitude), vowel, preview,
                analyzer.currentStrokeInfos().map(\.direction))
    }

    /// `[ㄴ] ↙30(199°) ←26(194°) →59(1°) ⇒ ㅡ` — 지우고 `←→ ⇒ ㅔ` 로 다시 침 ("네요" 가 "느요").
    func test_e2e_report1006_ne_shortLeftContinuation_isE() {
        let r = replay([(10, 184, 184), (20, 206, 206), (24, 194, 194), (6, 194, 30), (56, 1, 1)], column: 2)
        XCTAssertEqual(r.strokes, [.downLeft, .left, .right], "로그와 같은 분할이어야 이 경로를 검증한다")
        XCTAssertLessThan(r.magnitudes[1], 54 * 0.6)
        XCTAssertEqual(r.vowel, .ㅔ)
        XCTAssertEqual(r.preview, .ㅔ, "미리보기도 확정과 같아야 한다")
    }

    /// `[ㅁ] ↙21(211°) ←20(172°) ⇒ ㅡ` — 지우고 `← ⇒ ㅓ` 로 다시 침 ("머" 가 "므").
    func test_e2e_report1006_meo_shortLeftContinuation_isEo() {
        let r = replay([(19, 215, 210), (7, 210, 170), (16, 170, 170)], column: 1)
        XCTAssertEqual(r.strokes, [.downLeft, .left])
        XCTAssertLessThan(r.magnitudes[1], 54 * 0.6)
        XCTAssertEqual(r.vowel, .ㅓ)
        XCTAssertEqual(r.preview, .ㅓ)
    }

    /// `[ㄱ] ↗37(18°) →26(13°) ⇒ ㅣ` — 두 조각이 모두 거의 수평(합 16°).
    func test_e2e_report1006_ga_shortRightContinuation_isA() {
        let r = replay([(10, 0, 0), (22, 27, 27), (32, 13, 13)], column: 4)
        XCTAssertEqual(r.strokes, [.upRight, .right])
        XCTAssertLessThan(r.magnitudes[1], 54 * 0.6)
        XCTAssertEqual(r.vowel, .ㅏ)
        XCTAssertEqual(r.preview, .ㅏ)
    }

    /// 반례 — 0.6 기준을 그냥 풀면 깨진다. `[ㅋ] ↗21(31°) →28(16°) ↗52(29°) ⇒ ㅣ` ("버거킹" 의 키).
    /// 짧은 → 는 흔들림이고 이어진 세 조각의 합(≈26°)은 1열 ↗ 구역 안이다.
    func test_e2e_report1006_ki_wobblyUpRight_staysI() {
        let r = replay([(16, 38, 38), (30, 14, 14), (54, 30, 30)], column: 1)
        XCTAssertEqual(r.strokes, [.upRight, .right, .upRight])
        XCTAssertLessThan(r.magnitudes[1], 54 * 0.6)
        XCTAssertEqual(r.vowel, .ㅣ)
        XCTAssertEqual(r.preview, .ㅣ)
    }

    /// 이어진 조각 **전부**를 합친다 — 앞 두 조각만 합치면 ≈14°(→)로 ㅏ, 전부 합치면 ≈32°(↗)로 ㅣ.
    /// 위 반례는 앞 두 조각 합(≈23°)도 1열 ↗ 안이라 이 규칙을 지키지 못한다.
    func test_e2e_shortContinuation_sumsWholeRun_notFirstTwo() {
        let r = replay([(24, 24, 24), (22, 0, 0), (50, 50, 50)], column: 3)
        XCTAssertEqual(r.strokes, [.upRight, .right, .upRight])
        XCTAssertLessThan(r.magnitudes[1], 54 * 0.6)
        XCTAssertEqual(r.vowel, .ㅣ)
        XCTAssertEqual(r.preview, .ㅣ)
    }

    // MARK: - 세로로 시작해 대각선으로 휜 한 획 (메일 제보 2026-11, "대각선 ㅣ 가 와로")
    //
    // 가파르게 시작한 ↗ 가 `↑ + ↗` 로 나뉘고 리졸버가 ↑ 뒤 ↗ 를 → 로 접어 ↑→ = ㅘ 가 됐다.
    // 실제 꺾임은 16~30° 뿐이다(순정은 ≤55° 를 한 획으로 본다). 꺾은 모서리(이슈 #29 궤적 38~42°,
    // `GestureAnalyzerTests.testPronouncedDiagonalTurnIsPreserved` 45°)는 그대로 — `CompoundVowelPathTests`.

    /// 85°→35° 로 휘는 ↗ — 수정 전 3·5열에서 ㅘ ("기" 가 "과").
    func test_e2e_steepStartUpRightArc_isI_notWa() {
        for column in [3, 5] {
            for pieces in [[(len: CGFloat(70), from: 85.0, to: 35.0)],
                           [(len: CGFloat(25), from: 75.0, to: 75.0), (len: CGFloat(45), from: 45.0, to: 45.0)]] {
                let r = replay(pieces, column: column)
                XCTAssertEqual(r.raw, [.up, .upRight], "열 \(column): 분할이 있어야 이 경로를 검증한다")
                XCTAssertEqual(r.vowel, .ㅣ, "열 \(column)")
                XCTAssertEqual(r.preview, .ㅣ, "열 \(column): 미리보기도 확정과 같아야 한다")
            }
        }
    }

    /// 같은 경로의 나머지 세 대각선 — 수정 전 ↖ = ㅗ, ↘ = ㅜ, ↙ = ㅝ ("으" 가 "워").
    func test_e2e_steepStartOtherDiagonalArcs_keepDiagonalVowel() {
        let cases: [(pieces: [(len: CGFloat, from: Double, to: Double)], columns: [Int], vowel: Jungseong)] = [
            ([(70, 95, 145)], [1, 3], .ㅣ),
            ([(70, 275, 320)], [1, 3, 5], .ㅡ),
            ([(70, 265, 220)], [1, 3, 5], .ㅡ),
        ]
        for c in cases {
            for column in c.columns {
                let r = replay(c.pieces, column: column)
                XCTAssertEqual(r.raw.count, 2, "열 \(column) \(c.pieces): 분할이 있어야 이 경로를 검증한다")
                XCTAssertEqual(r.vowel, c.vowel, "열 \(column) \(c.pieces)")
                XCTAssertEqual(r.preview, c.vowel, "열 \(column) \(c.pieces)")
            }
        }
    }

    /// 반례 — 일부러 꺾은 ㅘ 는 그대로. → 를 40° 까지 들어 그어도(꺾임 ≈46~50°) ㅘ.
    func test_e2e_intentionalRightAngleWa_staysWa() {
        for column in [1, 3, 5] {
            for rightDeg in [0.0, 25.0, 40.0] {
                let r = replay([(40, 90, 90), (40, rightDeg, rightDeg)], column: column)
                XCTAssertEqual(r.vowel, .ㅘ, "열 \(column), → \(rightDeg)°")
                XCTAssertEqual(r.preview, .ㅘ, "열 \(column), → \(rightDeg)°")
            }
        }
    }
}

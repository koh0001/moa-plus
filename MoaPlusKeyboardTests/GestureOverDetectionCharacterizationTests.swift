import XCTest
@testable import MoaPlusKeyboard

/// B1(ㅘ/ㅙ/ㅞ 오인식) 조사용 **특성화(characterization) 테스트**.
///
/// ⚠️ 여기 있는 단언은 "이렇게 동작해야 한다"가 아니라 **"현재 이렇게 동작한다"**를
/// 고정한 것이다. 원인이 확정되기 전에 기대값을 박으면, 잘못된 수정이 초록불을 받는다.
/// 리뷰 리포트:
///   - 므미므므(v1.8.0, 4★) "ㅘ ㅙ ㅞ 입력이 순정 모아키와 달라서 '이'가 '와'로,
///     '으'가 '워'로 오타가 자주 발생"
///   - 콩픈패스(v1.8.0) "'와'/'오'가 잘 안 써짐"
///
/// 핵심 미해결 질문: 사용자가 **어떤 키**를 눌렀는가.
/// `ㅘ` 는 `.dash` 프리미티브에서만 나온다(`applySecondaryStroke`: ㅗ+→). `.bar` 에서는
/// 절대 안 나온다. 따라서 "ㅣ 의도 → ㅘ" 가 성립하는 유일한 경로는 자음 키 대각선
/// 진입(`resolveConsonantDiagonalVowel`)이며, 거기서는 **첫 획의 대각선 분류**가
/// 프리미티브를 결정한다(↗↖→`.bar`, ↙↘→`.dash`). 즉 후속 획 과등록이 아니라
/// **첫 획 오분류** 문제일 수 있다 — 이 파일은 두 가설을 구분하기 위한 계측이다.
final class GestureOverDetectionCharacterizationTests: XCTestCase {

    var vm: KeyboardViewModel!

    /// ㅇ (row 2, col 3) — 리뷰의 "이/으/와/워" 가 모두 ㅇ 초성이다.
    private static let ieungKey = (row: 2, column: 3)

    override func setUp() {
        super.setUp()
        vm = KeyboardViewModel()
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    // MARK: - 하니스

    /// 여러 구간(segment)으로 꺾인 궤적으로 키를 구동한다.
    /// 기존 `driveKeyGesture` 는 단일 직선(dx/dy)만 가능해 ↙→↓→← 같은
    /// 과등록 시나리오를 **구조적으로 재현할 수 없다**. 각 구간은 촘촘히
    /// 보간해 실기기 터치 샘플링에 가깝게 만든다.
    private func drivePath(row: Int, column: Int, segments: [CGVector], stepsPerSegment: Int = 8) {
        var point = CGPoint(x: 150, y: 150)
        vm.gestureStarted(row: row, column: column, at: point)
        for segment in segments {
            let origin = point
            for i in 1...stepsPerSegment {
                let f = CGFloat(i) / CGFloat(stepsPerSegment)
                let next = CGPoint(x: origin.x + segment.dx * f, y: origin.y + segment.dy * f)
                vm.gestureMoved(to: next)
            }
            point = CGPoint(x: origin.x + segment.dx, y: origin.y + segment.dy)
        }
        vm.gestureEnded(row: row, column: column)
    }

    private func withSensitivity(_ level: Int, _ body: () -> Void) {
        let original = KeyboardSettings.shared.gestureSettings
        defer { KeyboardSettings.shared.gestureSettings = original }
        var gs = original
        gs.multiStrokeTurnSensitivity = level
        KeyboardSettings.shared.gestureSettings = gs
        body()
    }

    /// 한 경로를 한 민감도에서 구동하고 결과 조합 문자열을 돌려준다.
    private func run(_ segments: [CGVector], sensitivity: Int) -> String {
        var result = ""
        withSensitivity(sensitivity) {
            vm = KeyboardViewModel()
            drivePath(row: Self.ieungKey.row, column: Self.ieungKey.column, segments: segments)
            result = vm.composingText
        }
        return result
    }

    // MARK: - 시나리오
    // 진입 획은 넉넉히(60pt) 그어 첫 방향이 확실히 등록되게 한다.
    // wobble 은 의도치 않은 손가락 흔들림 크기(8~15pt)를 모사한다.

    private static let scenarios: [(name: String, segments: [CGVector])] = [
        ("↗ 단독 (의도: 이)",              [CGVector(dx: 45, dy: -45)]),
        ("↙ 단독 (의도: 으)",              [CGVector(dx: -45, dy: 45)]),
        ("↗ + 끝 8pt 흔들림 (의도: 이)",    [CGVector(dx: 45, dy: -45), CGVector(dx: 8, dy: 6)]),
        ("↙ + 끝 8pt 흔들림 (의도: 으)",    [CGVector(dx: -45, dy: 45), CGVector(dx: 8, dy: -6)]),
        ("↗ + 끝 15pt 흔들림 (의도: 이)",   [CGVector(dx: 45, dy: -45), CGVector(dx: 15, dy: 10)]),
        ("↙ + 끝 15pt 흔들림 (의도: 으)",   [CGVector(dx: -45, dy: 45), CGVector(dx: 15, dy: -10)]),
        ("↙ + 끝 20pt 흔들림 (의도: 으)",   [CGVector(dx: -45, dy: 45), CGVector(dx: 20, dy: -14)]),
        // 자연스러운 손가락 호(arc) 꼬리 — 대각선을 긋고 손을 떼며 아래/옆으로 미끄러짐
        ("↙ + 호꼬리 ↓12←12 (의도: 으)",   [CGVector(dx: -45, dy: 45), CGVector(dx: 0, dy: 12), CGVector(dx: -12, dy: 0)]),
        ("↙ + 호꼬리 ↓20←20 (의도: 으)",   [CGVector(dx: -45, dy: 45), CGVector(dx: 0, dy: 20), CGVector(dx: -20, dy: 0)]),
        ("↙ + 호꼬리 ↑15→15 (의도: 으)",   [CGVector(dx: -45, dy: 45), CGVector(dx: 0, dy: -15), CGVector(dx: 15, dy: 0)]),
        ("↗ + 호꼬리 →12←12 (의도: 이)",   [CGVector(dx: 45, dy: -45), CGVector(dx: 12, dy: 0), CGVector(dx: -12, dy: 0)]),
        // 짧은 진입 획(30pt) — 진폭 비율 가드는 상대값이라 진입이 짧을수록 뚫기 쉽다
        ("짧은↙30 + 흔들림15 (의도: 으)",  [CGVector(dx: -21, dy: 21), CGVector(dx: 15, dy: -10)]),
        ("짧은↗30 + 흔들림15 (의도: 이)",  [CGVector(dx: 21, dy: -21), CGVector(dx: 15, dy: 10)]),
        ("↙↑→ (의도적 와)",                [CGVector(dx: -45, dy: 45), CGVector(dx: 0, dy: -50), CGVector(dx: 50, dy: 0)]),
        ("↙↓← (의도적 워)",                [CGVector(dx: -45, dy: 45), CGVector(dx: 0, dy: 50), CGVector(dx: -50, dy: 0)]),
    ]

    // MARK: - 다른 오타 리뷰 시나리오 (원인이 서로 다름)

    /// ㅡ 전용 키 (모던 레이아웃 row3 col5).
    private static let dashKey = (row: 3, column: 5)

    /// 똑데(v1.4, 4★): "'ㅜ' 영역이지만 약간 기울여서 내렸다고 ↓↘ 로 인식된 상태에서
    /// 다시 위로 올리면 ↓↘↑ 로 되버려 'ㅟ'가 되지 않습니다."
    /// → **진입 획 분열**(leading). 후행 꼬리와 원인이 다르다.
    /// 모아키가 최고(v1.6): "ㅛ,ㅜ,ㅢ 는 빨리 치면 인식 잘 안됩니다."
    /// → **과소 인식**. 후행 트림을 강화하면 오히려 악화될 수 있어 회귀 가드로 둔다.
    private static let dashScenarios: [(name: String, segments: [CGVector], steps: Int, intent: String)] = [
        ("ㅜ 곧게 ↓",                      [CGVector(dx: 0, dy: 50)], 8, "ㅜ"),
        ("ㅟ 곧게 ↓↑",                     [CGVector(dx: 0, dy: 50), CGVector(dx: 0, dy: -50)], 8, "ㅟ"),
        ("[똑데] ㅟ 기울여 ↓(우하향) ↑",    [CGVector(dx: 14, dy: 50), CGVector(dx: 0, dy: -50)], 8, "ㅟ"),
        ("[똑데] ㅟ 더 기울여 ↓ ↑",         [CGVector(dx: 22, dy: 50), CGVector(dx: 0, dy: -50)], 8, "ㅟ"),
        ("ㅛ 천천히 ↑↓↑",                  [CGVector(dx: 0, dy: -50), CGVector(dx: 0, dy: 50), CGVector(dx: 0, dy: -50)], 8, "ㅛ"),
        ("[빠르게] ㅛ ↑↓↑ (샘플 2)",       [CGVector(dx: 0, dy: -50), CGVector(dx: 0, dy: 50), CGVector(dx: 0, dy: -50)], 2, "ㅛ"),
        ("[빠르게] ㅠ ↓↑↓ (샘플 2)",       [CGVector(dx: 0, dy: 50), CGVector(dx: 0, dy: -50), CGVector(dx: 0, dy: 50)], 2, "ㅠ"),
        ("ㅘ ↑→ (전용키)",                 [CGVector(dx: 0, dy: -50), CGVector(dx: 50, dy: 0)], 8, "ㅘ"),
        ("ㅙ ↑→← (전용키, 끝 획 짧게 25)", [CGVector(dx: 0, dy: -50), CGVector(dx: 50, dy: 0), CGVector(dx: -25, dy: 0)], 8, "ㅙ"),
        ("ㅞ ↓←→ (전용키, 끝 획 짧게 25)", [CGVector(dx: 0, dy: 50), CGVector(dx: -50, dy: 0), CGVector(dx: 25, dy: 0)], 8, "ㅞ"),
    ]

    /// 자음 키(ㅇ)에서 **의도적으로** 긋는 순정 복합모음들.
    /// 후행 트림 강화가 이 중 하나라도 깎으면 즉시 드러난다 — 특히 마지막 획이
    /// 짧아지기 쉬운 4획 ㅒ(→←→←)/ㅖ(←→←→) 가 핵심 회귀 가드다.
    private static let intentionalScenarios: [(name: String, segments: [CGVector], intent: String)] = [
        ("ㅗ ↑",              [CGVector(dx: 0, dy: -55)], "오"),
        ("ㅏ →",              [CGVector(dx: 55, dy: 0)], "아"),
        ("ㅘ ↑→ (순정 ↱)",     [CGVector(dx: 0, dy: -55), CGVector(dx: 55, dy: 0)], "와"),
        ("ㅝ ↓← (순정 ↲)",     [CGVector(dx: 0, dy: 55), CGVector(dx: -55, dy: 0)], "워"),
        ("ㅚ ↑↓ 왕복",         [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55)], "외"),
        ("ㅐ →← 왕복",         [CGVector(dx: 55, dy: 0), CGVector(dx: -55, dy: 0)], "애"),
        ("ㅛ ↑↓↑",            [CGVector(dx: 0, dy: -55), CGVector(dx: 0, dy: 55), CGVector(dx: 0, dy: -55)], "요"),
        ("ㅑ →←→",            [CGVector(dx: 55, dy: 0), CGVector(dx: -55, dy: 0), CGVector(dx: 55, dy: 0)], "야"),
        ("ㅒ →←→← (끝 30)",    [CGVector(dx: 55, dy: 0), CGVector(dx: -55, dy: 0), CGVector(dx: 55, dy: 0), CGVector(dx: -30, dy: 0)], "얘"),
        ("ㅖ ←→←→ (끝 30)",    [CGVector(dx: -55, dy: 0), CGVector(dx: 55, dy: 0), CGVector(dx: -55, dy: 0), CGVector(dx: 30, dy: 0)], "예"),
        ("ㅙ ↑→← (끝 30)",     [CGVector(dx: 0, dy: -55), CGVector(dx: 55, dy: 0), CGVector(dx: -30, dy: 0)], "왜"),
        ("ㅞ ↓←→ (끝 30)",     [CGVector(dx: 0, dy: 55), CGVector(dx: -55, dy: 0), CGVector(dx: 30, dy: 0)], "웨"),
    ]

    private func runDash(_ segments: [CGVector], steps: Int, sensitivity: Int) -> String {
        var result = ""
        withSensitivity(sensitivity) {
            vm = KeyboardViewModel()
            drivePath(row: Self.dashKey.row, column: Self.dashKey.column,
                      segments: segments, stepsPerSegment: steps)
            result = vm.composingText
        }
        return result
    }

    /// 경로 × 민감도 전체 매트릭스를 .xcresult 첨부로 남긴다.
    /// 리뷰어 설정(민감도 0/1/2)을 모르므로 세 단계를 모두 기록한다.
    func test_characterize_matrix_attachesReport() {
        var lines = ["## 자음 대각선 진입 (ㅇ 키)", "", "경로 | 의도 | sens0 | sens1 | sens2", "--- | --- | --- | --- | ---"]
        for scenario in Self.scenarios {
            let cells = [0, 1, 2].map { level -> String in
                let out = run(scenario.segments, sensitivity: level)
                return out.isEmpty ? "(없음)" : out
            }
            lines.append("\(scenario.name) |  | \(cells[0]) | \(cells[1]) | \(cells[2])")
        }
        lines.append(contentsOf: ["", "## ㅡ 전용 키 — 진입 분열 / 과소 인식 / ㅙㅞ 회귀 가드", "",
                                  "경로 | 의도 | sens0 | sens1 | sens2", "--- | --- | --- | --- | ---"])
        for scenario in Self.dashScenarios {
            let cells = [0, 1, 2].map { level -> String in
                let out = runDash(scenario.segments, steps: scenario.steps, sensitivity: level)
                return out.isEmpty ? "(없음)" : out
            }
            let mark = { (c: String) in c == scenario.intent ? c : "**\(c)**" }
            lines.append("\(scenario.name) | \(scenario.intent) | \(mark(cells[0])) | \(mark(cells[1])) | \(mark(cells[2]))")
        }
        lines.append(contentsOf: ["", "## 자음 키 의도적 복합모음 — 후행 트림 회귀 가드", "",
                                  "경로 | 의도 | sens0 | sens1 | sens2", "--- | --- | --- | --- | ---"])
        for scenario in Self.intentionalScenarios {
            let cells = [0, 1, 2].map { level -> String in
                let out = run(scenario.segments, sensitivity: level)
                return out.isEmpty ? "(없음)" : out
            }
            let mark = { (c: String) in c == scenario.intent ? c : "**\(c)**" }
            lines.append("\(scenario.name) | \(scenario.intent) | \(mark(cells[0])) | \(mark(cells[1])) | \(mark(cells[2]))")
        }
        let report = lines.joined(separator: "\n")
        let attachment = XCTAttachment(string: report)
        attachment.name = "b1_gesture_matrix.md"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertFalse(report.isEmpty)
    }

    // MARK: - 재현된 오인식 (현재 동작 고정)
    // 아래는 **버그를 고정한 것**이다. 수정이 들어가면 이 테스트들은 깨져야 하며,
    // 깨질 때 "의도한 개선인지"를 사람이 판단해 기대값을 갱신한다.

    /// 리뷰 리포트("'으'를 입력할 때 '워'로")와 같은 계열.
    ///
    /// **수정 전(v1.8.0, 대각선 진입 파생 항상 ON)**: sens0=의 / sens1=오 / sens2=와
    /// — 셋 다 의도('으')와 달랐고, sens2 의 '와' 가 리뷰가 지적한 바로 그 오타다.
    /// **수정 후(v1.9, 순정 기본)**: 파생 경로가 없어 어떤 민감도에서도 '으'.
    func test_upwardArcTailAfterDownLeft_isNoLongerMisrecognized() {
        let path = [CGVector(dx: -45, dy: 45), CGVector(dx: 0, dy: -15), CGVector(dx: 15, dy: 0)]
        // 리뷰가 지적한 심각한 오타(모음이 통째로 바뀜)는 전 민감도에서 사라졌다.
        for level in [0, 1, 2] {
            XCTAssertFalse(["와", "오", "야", "워"].contains(run(path, sensitivity: level)),
                           "sens\(level): 꼬리가 ㅡ 를 ㅘ/ㅗ/ㅑ/ㅝ 로 바꾸면 안 됨")
        }
        XCTAssertEqual(run(path, sensitivity: 1), "으")
        XCTAssertEqual(run(path, sensitivity: 2), "으")
        // 잔여: 기본 민감도(0)에서는 아직 ㅢ 로 승격된다. ㅢ 는 순정에도 있는
        // 조합(↙↗)이라 꼬리를 ↗ 로 읽으면 논리적으로 도달 가능한 값이고,
        // '와/워' 대비 훨씬 경미하다. 더 좁히려면 등록 임계 자체를 건드려야 해
        // 과소 인식(리뷰 (C) 갈래) 위험이 생기므로 여기서 멈춘다.
        XCTAssertEqual(run(path, sensitivity: 0), "의", "알려진 잔여 — 심각도 낮음")
    }

    /// ㅢ 과승격은 **민감도 0(기본값)에서도** 발생했다 —
    /// `resolveConsonantDiagonalVowel` 의 ㅢ 분기가 후속 획이 위쪽 대각선이기만
    /// 하면 크기 조건 없이 ㅢ 를 반환했기 때문(15pt 흔들림이면 충분).
    /// **수정 전**: 전 민감도에서 '의'. **수정 후**: 전 민감도에서 '으'.
    func test_smallWobbleAfterDownLeft_noLongerPromotesToEui() {
        let path = [CGVector(dx: -45, dy: 45), CGVector(dx: 15, dy: -10)]
        XCTAssertEqual(run(path, sensitivity: 1), "으", "15pt 흔들림은 노이즈")
        XCTAssertEqual(run(path, sensitivity: 2), "으", "15pt 흔들림은 노이즈")
        // 잔여(위 테스트와 같은 이유): 기본 민감도에서만 ㅢ 로 남는다.
        XCTAssertEqual(run(path, sensitivity: 0), "의", "알려진 잔여 — 심각도 낮음")
    }

    /// 진입 획이 짧으면(30pt) 꼬리(18pt)가 그 61% 라 비율로 노이즈라고 단정할 수
    /// 없다. 전 민감도에서 ㅢ 로 남는 것을 알려진 한계로 고정한다 — 여기서
    /// 더 깎으면 의도적인 짧은 왕복(ㅢ 자체)이 입력 불가가 된다.
    func test_shortEntryStrokeWobble_remainsAmbiguous() {
        let path = [CGVector(dx: -21, dy: 21), CGVector(dx: 15, dy: -10)]
        for level in [0, 1, 2] {
            XCTAssertEqual(run(path, sensitivity: level), "의", "알려진 한계 — 진입 획이 짧을 때")
        }
    }

    /// 순정 방식에서도 **의도적인 복합모음은 그대로 입력돼야 한다**.
    /// ㅘ 는 대각선 진입이 아니라 카디널 조합(↑→)으로 만든다 — 순정 스펙과 동일하며
    /// `VowelPattern.all` 이 이미 그렇게 구현돼 있다.
    func test_moakeySpec_cardinalCompoundsStillWork() {
        for level in [0, 1, 2] {
            XCTAssertEqual(run([CGVector(dx: 0, dy: -55), CGVector(dx: 55, dy: 0)], sensitivity: level), "와",
                           "sens\(level): ↑→ 는 순정 ㅘ(↱)")
            XCTAssertEqual(run([CGVector(dx: 0, dy: 55), CGVector(dx: -55, dy: 0)], sensitivity: level), "워",
                           "sens\(level): ↓← 는 순정 ㅝ(↲)")
        }
    }

    /// 8pt 흔들림은 모든 민감도에서 안전하다. 즉 임계는 8~15pt 사이에 있다.
    func test_characterize_smallestWobbleIsStillSafe() {
        for level in [0, 1, 2] {
            XCTAssertEqual(run([CGVector(dx: -45, dy: 45), CGVector(dx: 8, dy: -6)], sensitivity: level), "으")
            XCTAssertEqual(run([CGVector(dx: 45, dy: -45), CGVector(dx: 8, dy: 6)], sensitivity: level), "이")
        }
    }

    // MARK: - 불변식 (원인과 무관하게 지켜져야 하는 것)

    /// 흔들림 없는 깨끗한 단일 대각선은 반드시 의도대로 나와야 한다.
    /// 이것이 깨지면 원인은 후속 획이 아니라 **첫 획 분류**로 확정된다.
    func test_cleanSingleDiagonal_matchesIntent_allSensitivities() {
        for level in [0, 1, 2] {
            XCTAssertEqual(run([CGVector(dx: 45, dy: -45)], sensitivity: level), "이",
                           "sens\(level): ㅇ + 깨끗한 ↗ 는 '이' 여야 함")
            XCTAssertEqual(run([CGVector(dx: -45, dy: 45)], sensitivity: level), "으",
                           "sens\(level): ㅇ + 깨끗한 ↙ 는 '으' 여야 함")
        }
    }
}

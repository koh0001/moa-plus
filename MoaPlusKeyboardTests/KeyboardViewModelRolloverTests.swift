import XCTest
@testable import MoaPlusKeyboard

/// 두 엄지 롤오버 — 앞 키를 떼기 전에 다음 키를 누르는 빠른 입력 (이슈 #31/#32).
///
/// 뷰모델은 진행 중인 긋기를 하나만 들고 있다. 고치기 전에는 두 번째 키의 `gestureStarted` 가
/// 긋기 상태를 덮어써, 아직 눌려 있던 첫 키 손가락의 미세한 움직임이 **두 번째 키 위치에서 시작한
/// 긋기**로 들어갔다 → 첫 키가 키 몇 개 거리의 긴 긋기로 확정. 제보 로그
/// `[ㄴ] raw ←225(178°) ⇒ ㅓ` 가 그 흔적이다: "는" → "너ㅡㄴ", "니" → "네".
final class KeyboardViewModelRolloverTests: XCTestCase {

    private var vm: KeyboardViewModel!
    private var buffer: TextBufferDelegate!
    private var savedLayout: LayoutCustomization!

    override func setUp() {
        super.setUp()
        savedLayout = KeyboardSettings.shared.layoutCustomization
        KeyboardSettings.shared.layoutCustomization = LayoutCustomization()
        vm = KeyboardViewModel()
        buffer = TextBufferDelegate()
        vm.delegate = buffer
    }

    override func tearDown() {
        KeyboardSettings.shared.layoutCustomization = savedLayout
        vm = nil
        buffer = nil
        super.tearDown()
    }

    // MARK: - 키 위치 (레이아웃에서 찾는다)

    private func position(of target: KeyContent) -> (row: Int, column: Int) {
        for row in 0..<4 {
            for column in 0..<7 {
                let c = KeyboardMetrics.keyContent(
                    at: row, column: column, mode: .korean,
                    layout: KeyboardSettings.shared.layoutCustomization, symbolPage: 0)
                if let c, "\(c)" == "\(target)" { return (row, column) }
            }
        }
        XCTFail("레이아웃에 \(target) 이 없다")
        return (0, 0)
    }

    /// 대략의 화면 좌표 — 키폭 54 + 간격 6 기준. 정확할 필요는 없고 키 사이 거리만 실제와 비슷하면 된다.
    private func point(_ key: (row: Int, column: Int)) -> CGPoint {
        CGPoint(x: 30 + CGFloat(key.column) * 60, y: 30 + CGFloat(key.row) * 60)
    }

    private var nieun: (row: Int, column: Int) { position(of: .consonant(.ㄴ)) }
    private var dash: (row: Int, column: Int) { position(of: .vowelPrimitive(.dash)) }
    private var bar: (row: Int, column: Int) { position(of: .vowelPrimitive(.bar)) }

    private func tap(_ key: (row: Int, column: Int)) {
        vm.gestureStarted(row: key.row, column: key.column, at: point(key))
        vm.gestureEnded(row: key.row, column: key.column)
    }

    /// `first` 를 누른 채 `second` 를 누르고, 첫 손가락이 1pt 흔들린 뒤 첫 키 → 둘째 키 순으로 뗀다.
    private func rollover(_ first: (row: Int, column: Int), _ second: (row: Int, column: Int)) {
        vm.gestureStarted(row: first.row, column: first.column, at: point(first))
        vm.gestureStarted(row: second.row, column: second.column, at: point(second))
        let jitter = CGPoint(x: point(first).x + 1, y: point(first).y)
        vm.gestureMoved(row: first.row, column: first.column, to: jitter)
        vm.gestureEnded(row: first.row, column: first.column)
        vm.gestureEnded(row: second.row, column: second.column)
    }

    // MARK: - 제보 재현

    func test_rollover_nieunThenDash_typesNeun() {
        rollover(nieun, dash)   // ㄴ + ㅡ
        tap(nieun)              // 받침 ㄴ
        XCTAssertEqual(buffer.text, "는", "롤오버한 ㄴ 이 긴 ← 긋기(ㅓ)로 읽혔다 — 제보 \"너ㅡㄴ\"")
    }

    func test_rollover_nieunThenBar_typesNi() {
        rollover(nieun, bar)    // ㄴ + ㅣ
        XCTAssertEqual(buffer.text, "니", "제보 \"니 → 네\"")
    }

    /// 둘째 키를 먼저 떼는 순서(뗌 순서 뒤바뀜)도 같아야 한다.
    func test_rollover_releaseOutOfOrder_sameResult() {
        vm.gestureStarted(row: nieun.row, column: nieun.column, at: point(nieun))
        vm.gestureStarted(row: dash.row, column: dash.column, at: point(dash))
        vm.gestureEnded(row: dash.row, column: dash.column)
        vm.gestureMoved(row: nieun.row, column: nieun.column, to: CGPoint(x: point(nieun).x + 1, y: point(nieun).y))
        vm.gestureEnded(row: nieun.row, column: nieun.column)
        tap(nieun)
        XCTAssertEqual(buffer.text, "는")
    }

    /// 먼저 확정된 키가 뒤늦게 보내는 취소(EarlyTouch 미처리 뗌)는 새 키의 긋기를 지우면 안 된다.
    func test_supersededKeyCancel_doesNotResetNewGesture() {
        vm.gestureStarted(row: nieun.row, column: nieun.column, at: point(nieun))
        vm.gestureStarted(row: dash.row, column: dash.column, at: point(dash))
        vm.cancelGesture(row: nieun.row, column: nieun.column)
        XCTAssertNotNil(vm.activeKey, "앞 키의 늦은 취소가 진행 중인 ㅡ 누름을 지웠다")
        vm.gestureEnded(row: dash.row, column: dash.column)
        XCTAssertEqual(buffer.text, "느")
    }

    // MARK: - 회귀: 겹치지 않는 입력은 그대로

    func test_sequentialTaps_unchanged() {
        tap(nieun); tap(dash); tap(nieun)
        XCTAssertEqual(buffer.text, "는")
    }

    /// 롤오버가 아닌 실제 긋기(ㄴ 에서 → 길게)는 그대로 ㅏ.
    func test_realSwipe_unchanged() {
        vm.gestureStarted(row: nieun.row, column: nieun.column, at: point(nieun))
        for i in 1...6 {
            vm.gestureMoved(row: nieun.row, column: nieun.column,
                            to: CGPoint(x: point(nieun).x + CGFloat(i) * 10, y: point(nieun).y))
        }
        vm.gestureEnded(row: nieun.row, column: nieun.column)
        XCTAssertEqual(buffer.text, "나")
    }
}

/// 삽입·삭제·조합 갱신을 실제 문자열에 반영하는 호스트 흉내.
private final class TextBufferDelegate: KeyboardViewModelDelegate {
    var text = ""
    func insertText(_ s: String) { text += s }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func updateComposingText(from previous: String, to current: String) {
        for _ in 0..<previous.count where !text.isEmpty { text.removeLast() }
        text += current
    }
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { text }
    func textAfterCursor() -> String? { "" }
    func hostAllowsAutoCapitalization() -> Bool { true }
    func hostInputTraitsDebugInfo() -> String { "" }
}

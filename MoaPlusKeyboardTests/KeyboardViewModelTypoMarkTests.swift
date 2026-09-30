import XCTest
@testable import MoaPlusKeyboard

/// 오타 후보 자동 표시 — 긋기 직후 첫 입력이 백스페이스면 그 긋기 로그 줄에
/// `GestureDebugLog.deletedMark` 가 붙는다 (메일 제보 "오타가 나면 그대로 저장해 달라").
final class KeyboardViewModelTypoMarkTests: XCTestCase {

    private var vm: KeyboardViewModel!
    private var originalLogEnabled = true

    /// 한글 레이아웃 row 1 col 4 = ㄱ.
    private let giyeok = (row: 1, column: 4)

    override func setUp() {
        super.setUp()
        originalLogEnabled = KeyboardSettings.shared.gestureDebugLogEnabled
        KeyboardSettings.shared.gestureDebugLogEnabled = true
        GestureDebugLog.clear()
        vm = KeyboardViewModel()
    }

    override func tearDown() {
        vm = nil
        GestureDebugLog.clear()
        KeyboardSettings.shared.gestureDebugLogEnabled = originalLogEnabled
        super.tearDown()
    }

    private func swipeRight(on key: (row: Int, column: Int)) {
        let origin = CGPoint(x: 100, y: 100)
        vm.gestureStarted(row: key.row, column: key.column, at: origin)
        for i in 1...6 {
            vm.gestureMoved(to: CGPoint(x: origin.x + CGFloat(i) * 10, y: origin.y))
        }
        vm.gestureEnded(row: key.row, column: key.column)
    }

    private var lines: [String] { GestureDebugLog.recentLines() }

    func test_gestureThenBackspace_marksLine() {
        swipeRight(on: giyeok)
        XCTAssertEqual(lines.count, 1)
        vm.deleteBackward()
        XCTAssertTrue(lines.last?.hasSuffix(GestureDebugLog.deletedMark) == true, lines.last ?? "")
    }

    /// 반복 삭제(꾹 누르기)도 표시는 한 번만.
    func test_repeatedBackspace_marksOnce() {
        swipeRight(on: giyeok)
        vm.deleteBackward()
        vm.deleteBackward()
        vm.deleteBackward()
        let mark = GestureDebugLog.deletedMark
        XCTAssertEqual(lines.last?.components(separatedBy: mark).count, 2, "표시가 한 번만 붙어야 한다")
    }

    /// 긋기 뒤 스페이스를 쳤다면 그 뒤 백스페이스는 스페이스를 지우는 것 — 표시 안 함.
    func test_otherInputBetween_clearsPending() {
        swipeRight(on: giyeok)
        vm.inputSpace()
        vm.deleteBackward()
        XCTAssertFalse(lines.last?.hasSuffix(GestureDebugLog.deletedMark) == true)
    }

    /// 다음 키를 누르기 시작하면(탭 포함) 대기가 풀린다.
    func test_nextKeyPress_clearsPending() {
        swipeRight(on: giyeok)
        vm.gestureStarted(row: giyeok.row, column: giyeok.column, at: CGPoint(x: 100, y: 100))
        vm.gestureEnded(row: giyeok.row, column: giyeok.column)   // 탭 = ㄱ
        vm.deleteBackward()
        XCTAssertFalse(lines.last?.hasSuffix(GestureDebugLog.deletedMark) == true)
    }

    /// 로그가 꺼져 있으면 아무것도 쓰지 않는다.
    func test_logDisabled_noMark() {
        KeyboardSettings.shared.gestureDebugLogEnabled = false
        swipeRight(on: giyeok)
        vm.deleteBackward()
        XCTAssertTrue(lines.isEmpty)
    }
}

import XCTest

final class KeyboardViewModelCursorTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: MockKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = MockKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    func testMoveCursorByZero_isNoOp() {
        viewModel.moveCursor(by: 0)
        XCTAssertTrue(delegate.cursorMoves.isEmpty, "moveCursor(by: 0) must not call delegate")
    }

    func testMoveCursorForward_callsDelegate() {
        viewModel.moveCursor(by: 1)
        XCTAssertEqual(delegate.cursorMoves, [1])
    }

    func testMoveCursorBackward_callsDelegate() {
        viewModel.moveCursor(by: -3)
        XCTAssertEqual(delegate.cursorMoves, [-3])
    }

    func testMoveCursorWhileComposing_commitsAndMoves() {
        // Start composing "ㅂ"
        viewModel.gestureStarted(row: 1, column: 1, at: .zero)
        viewModel.gestureEnded(row: 1, column: 1)
        // Verify we have a composing character
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅂ")

        delegate.cursorMoves = []
        viewModel.moveCursor(by: 1)

        // After moveCursor, composer should be cleared (no pending composing text)
        XCTAssertEqual(viewModel.composingText, "",
                       "Composer must be cleared after moveCursor")
        XCTAssertEqual(delegate.cursorMoves, [1],
                       "Delegate must receive the cursor move")
    }

    func testMoveCursorResetsAbbreviationBuffer() {
        // Feed some characters into the abbreviation engine buffer
        viewModel.inputSpace() // triggers processCharacter(" ")
        // Now move cursor — abbreviation buffer should reset (no crash, clean state)
        viewModel.moveCursor(by: -1)
        XCTAssertEqual(delegate.cursorMoves, [-1])
    }

    // MARK: - External cursor move (user tapped elsewhere in the text field)

    /// When the user moves the caret by tapping directly in the host text
    /// field, iOS has *already* repositioned the caret. The composing glyph
    /// is on screen as plain text at its old position. We must only clear
    /// composer state — never touch the proxy (no delete/insert/cursor move),
    /// otherwise the next keystroke's commit path edits at the wrong place.
    func testExternalCursorMoveWhileComposing_clearsComposerWithoutTouchingProxy() {
        viewModel.inputConsonant(.ㅂ)
        XCTAssertEqual(viewModel.composingText, "ㅂ", "precondition: composing ㅂ")

        delegate.cursorMoves = []
        delegate.insertedTexts = []
        delegate.deleteCount = 0

        viewModel.handleExternalCursorMove()

        XCTAssertEqual(viewModel.composingText, "",
                       "composer must be cleared after external caret move")
        XCTAssertTrue(delegate.cursorMoves.isEmpty,
                      "must NOT move the proxy caret — iOS already moved it")
        XCTAssertEqual(delegate.deleteCount, 0,
                       "must NOT delete anything on an external caret move")
        XCTAssertTrue(delegate.insertedTexts.isEmpty,
                      "must NOT insert anything on an external caret move")
    }

    /// Reproduces the "안욥하세욥" data-corruption bug: composing glyph, then
    /// the user taps elsewhere, then types. The next input must start a fresh
    /// composition at the new caret — the old composing glyph must not be
    /// re-deleted or re-inserted via the commit path.
    func testInputAfterExternalCursorMove_doesNotReinsertOldComposingGlyph() {
        viewModel.inputConsonant(.ㅂ)
        XCTAssertEqual(viewModel.composingText, "ㅂ", "precondition: composing ㅂ")

        viewModel.handleExternalCursorMove() // user taps between other glyphs

        delegate.cursorMoves = []
        delegate.insertedTexts = []
        delegate.deleteCount = 0
        delegate.composingUpdates = []

        viewModel.inputConsonant(.ㅈ)

        XCTAssertEqual(delegate.deleteCount, 0,
                       "must not delete a glyph at the new caret (the old ㅂ bug)")
        XCTAssertEqual(delegate.insertedTexts, [],
                       "must not re-insert the old committed glyph at the new caret")
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅈ",
                       "new composition is just ㅈ")
        XCTAssertEqual(delegate.composingUpdates.last?.previous, "",
                       "composition starts fresh, not from the stale ㅂ")
    }

    // MARK: - 상하 줄 이동 (스페이스 드래그 세로 축 — 순정 모아키 커서 이동 모드)
    // 하드 줄바꿈(\n) 기준 열 보존 환산. 오프셋 산식:
    //   위: -(현재 열 + 1 + (이전 줄 길이 - 목표 열))
    //   아래: 현재 줄 잔여 + 1 + 목표 열

    func testMoveCursorLineUp_movesToSameColumnOfPreviousLine() {
        delegate.contextBefore = "가나다\n라마"   // 커서: 2번째 줄, 열 2
        viewModel.moveCursorLine(by: -1)
        XCTAssertEqual(delegate.cursorMoves, [-4], "2 + 1 + (3-2) = 4 후퇴")
    }

    func testMoveCursorLineUp_clampsColumnToShorterPreviousLine() {
        delegate.contextBefore = "가\n라마바사"   // 열 4, 이전 줄 길이 1 → 목표 열 1
        viewModel.moveCursorLine(by: -1)
        XCTAssertEqual(delegate.cursorMoves, [-5], "4 + 1 + (1-1) = 5 후퇴")
    }

    func testMoveCursorLineUp_withoutPreviousLineInContext_isNoOp() {
        delegate.contextBefore = "가나다"
        viewModel.moveCursorLine(by: -1)
        XCTAssertTrue(delegate.cursorMoves.isEmpty, "컨텍스트에 이전 줄이 없으면 이동하지 않음")
    }

    func testMoveCursorLineDown_movesToSameColumnOfNextLine() {
        delegate.contextBefore = "가나"            // 열 2
        delegate.contextAfter = "다라\n마바사아"    // 잔여 2, 다음 줄 길이 4
        viewModel.moveCursorLine(by: 1)
        XCTAssertEqual(delegate.cursorMoves, [5], "2 + 1 + 2 = 5 전진")
    }

    func testMoveCursorLineDown_clampsToShorterNextLine() {
        delegate.contextBefore = "가나다라"        // 열 4
        delegate.contextAfter = "\n마"             // 잔여 0, 다음 줄 길이 1 → 목표 열 1
        viewModel.moveCursorLine(by: 1)
        XCTAssertEqual(delegate.cursorMoves, [2], "0 + 1 + 1 = 2 전진")
    }

    func testMoveCursorLineDown_withoutNextLineInContext_isNoOp() {
        delegate.contextBefore = "가나"
        delegate.contextAfter = "다라"
        viewModel.moveCursorLine(by: 1)
        XCTAssertTrue(delegate.cursorMoves.isEmpty, "뒤 컨텍스트에 줄바꿈이 없으면 이동하지 않음")
    }
}

private final class MockKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var deleteCount = 0
    var composingUpdates: [ComposingUpdate] = []
    var switchKeyboardCount = 0
    var hapticCount = 0
    var cursorMoves: [Int] = []
    /// 상하 줄 이동 테스트용 커서 앞/뒤 컨텍스트. nil = 호스트 컨텍스트 없음.
    var contextBefore: String?
    var contextAfter: String?

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() { deleteCount += 1 }
    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }
    func switchToNextKeyboard() { switchKeyboardCount += 1 }
    func triggerHapticFeedback() { hapticCount += 1 }
    func moveCursor(by offset: Int) { cursorMoves.append(offset) }
    func textBeforeCursor() -> String? { contextBefore }
    func textAfterCursor() -> String? { contextAfter }
}

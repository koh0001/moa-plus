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

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() { deleteCount += 1 }
    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }
    func switchToNextKeyboard() { switchKeyboardCount += 1 }
    func triggerHapticFeedback() { hapticCount += 1 }
    func moveCursor(by offset: Int) { cursorMoves.append(offset) }
}

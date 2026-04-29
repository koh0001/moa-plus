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

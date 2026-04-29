import XCTest

final class KeyboardViewModelLongPressTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: SpyKeyboardDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    func testLongPressNumberThenGestureEnd_insertsOnlyNumber() {
        // Use the "~" symbol key (row 0, col 0) so the popup's secondaryAction
        // lookup yields no candidates and confirmPopupSelection falls back to
        // the explicit longPressPopupText. Consonant keys (e.g. ㅂ) instead
        // surface popup candidates whose first entry is not "1".
        viewModel.gestureStarted(row: 0, column: 0, at: .zero)
        viewModel.inputLongPressNumber("1")
        viewModel.confirmPopupSelection()
        viewModel.gestureEnded(row: 0, column: 0)

        XCTAssertEqual(delegate.insertedTexts, ["1"])
        XCTAssertTrue(delegate.composingUpdates.isEmpty)
    }

    func testNormalTapStillInputsConsonant() {
        viewModel.gestureStarted(row: 1, column: 1, at: .zero) // ㅂ key
        viewModel.gestureEnded(row: 1, column: 1)

        XCTAssertEqual(delegate.insertedTexts, [])
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅂ")
    }

    func testLongPressSuppressionResetsForNextGesture() {
        // First gesture uses the "~" symbol key (no popup candidates) so the
        // popup falls back to the explicit "1" longPressPopupText.
        viewModel.gestureStarted(row: 0, column: 0, at: .zero)
        viewModel.inputLongPressNumber("1")
        viewModel.confirmPopupSelection()
        viewModel.gestureEnded(row: 0, column: 0)

        viewModel.gestureStarted(row: 1, column: 2, at: .zero) // ㅈ key
        viewModel.gestureEnded(row: 1, column: 2)

        XCTAssertEqual(delegate.insertedTexts, ["1"])
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㅈ")
    }
}

private final class SpyKeyboardDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var insertedTexts: [String] = []
    var deleteCount = 0
    var composingUpdates: [ComposingUpdate] = []
    var switchKeyboardCount = 0
    var hapticCount = 0

    func insertText(_ text: String) {
        insertedTexts.append(text)
    }

    func deleteBackward() {
        deleteCount += 1
    }

    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }

    func switchToNextKeyboard() {
        switchKeyboardCount += 1
    }

    func triggerHapticFeedback() {
        hapticCount += 1
    }

    func moveCursor(by offset: Int) {}
}

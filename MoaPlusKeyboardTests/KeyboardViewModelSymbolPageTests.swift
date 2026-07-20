import XCTest
@testable import MoaPlusKeyboard

/// Covers the symbol keypad page state: toggle, reset-on-mode-change, and that
/// a tap resolves the *active* page's symbol (not the page 0 grid).
final class KeyboardViewModelSymbolPageTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: MockSymbolPageDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = MockSymbolPageDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: - Toggle / reset

    func testTogglePage_flipsBetween0And1() {
        viewModel.keyboardMode = .symbolFromKorean
        XCTAssertEqual(viewModel.symbolPage, 0)
        viewModel.toggleSymbolPage()
        XCTAssertEqual(viewModel.symbolPage, 1)
        viewModel.toggleSymbolPage()
        XCTAssertEqual(viewModel.symbolPage, 0)
    }

    func testTogglePage_noOpOutsideSymbolMode() {
        viewModel.keyboardMode = .korean
        viewModel.toggleSymbolPage()
        XCTAssertEqual(viewModel.symbolPage, 0, "page must not change in a letter mode")
    }

    func testEnteringSymbolMode_resetsToPage0() {
        viewModel.keyboardMode = .symbolFromKorean
        viewModel.toggleSymbolPage()
        XCTAssertEqual(viewModel.symbolPage, 1)
        // Exit back to Korean, then re-enter symbol mode — must start on page 0.
        viewModel.toggleSymbolMode()   // symbol → korean
        viewModel.toggleSymbolMode()   // korean → symbol
        XCTAssertEqual(viewModel.symbolPage, 0)
    }

    func testSwitchingToLetterMode_resetsPage() {
        viewModel.keyboardMode = .symbolFromKorean
        viewModel.toggleSymbolPage()
        XCTAssertEqual(viewModel.symbolPage, 1)
        viewModel.toggleLetterMode()   // symbol → opposite letter, page reset
        XCTAssertEqual(viewModel.symbolPage, 0)
    }

    // MARK: - Page-aware tap

    /// (row 2, col 0) is `'` on page 0 and `$` on page 1. A tap must resolve
    /// against the active page — otherwise page 1 would insert the page 0 glyph.
    func testTap_resolvesActivePageSymbol() {
        viewModel.keyboardMode = .symbolFromKorean

        // Page 0 tap → '
        viewModel.symbolPage = 0
        tap(row: 2, column: 0)
        XCTAssertEqual(delegate.insertedTexts.last, "'")

        // Page 1 tap → $
        viewModel.symbolPage = 1
        tap(row: 2, column: 0)
        XCTAssertEqual(delegate.insertedTexts.last, "$")
    }

    private func tap(row: Int, column: Int) {
        viewModel.gestureStarted(row: row, column: column, at: .zero)
        viewModel.gestureEnded(row: row, column: column)
    }
}

private final class MockSymbolPageDelegate: KeyboardViewModelDelegate {
    var insertedTexts: [String] = []
    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() {}
    func updateComposingText(from previous: String, to current: String) {}
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
}

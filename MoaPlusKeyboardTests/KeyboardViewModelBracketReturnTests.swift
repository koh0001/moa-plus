import XCTest

/// 괄호 입력 후 글자 자판으로 (설정 `returnToLettersAfterBracket`, 앱스토어 리뷰 2026-11).
/// 실제 탭 경로(`gestureStarted` → `gestureEnded`)로 누른다 — `inputSymbol` 을 직접 부르면
/// 탭 처리 중에 모드를 바꾸는 순서 문제를 못 잡는다.
final class KeyboardViewModelBracketReturnTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: InsertRecorder!
    private var saved: (returnAfter: Bool, autoBracket: Bool)!

    override func setUp() {
        super.setUp()
        let settings = KeyboardSettings.shared
        saved = (settings.returnToLettersAfterBracket, settings.autoBracketEnabled)
        settings.returnToLettersAfterBracket = true
        viewModel = KeyboardViewModel()
        delegate = InsertRecorder()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        KeyboardSettings.shared.returnToLettersAfterBracket = saved.returnAfter
        KeyboardSettings.shared.autoBracketEnabled = saved.autoBracket
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    func test_openBracket_returnsToKorean_withAndWithoutAutoBracket() {
        for autoBracket in [true, false] {
            KeyboardSettings.shared.autoBracketEnabled = autoBracket
            delegate.inserted = []
            viewModel.keyboardMode = .symbolFromKorean
            tapSymbol("(")
            XCTAssertEqual(viewModel.keyboardMode, .korean, "autoBracket=\(autoBracket)")
            XCTAssertEqual(viewModel.symbolPage, 0)
            XCTAssertEqual(delegate.inserted, [autoBracket ? "()" : "("], "한 번만 들어가야 한다")
        }
    }

    func test_closeBracket_returnsToEnglish() {
        viewModel.keyboardMode = .symbolFromEnglish
        tapSymbol(")")
        XCTAssertEqual(viewModel.keyboardMode, .english)
        XCTAssertEqual(delegate.inserted, [")"])
    }

    func test_otherSymbol_staysInSymbolMode() {
        viewModel.keyboardMode = .symbolFromKorean
        tapSymbol("!")
        XCTAssertEqual(viewModel.keyboardMode, .symbolFromKorean)
    }

    func test_settingOff_staysInSymbolMode() {
        KeyboardSettings.shared.returnToLettersAfterBracket = false
        viewModel.keyboardMode = .symbolFromKorean
        tapSymbol("(")
        XCTAssertEqual(viewModel.keyboardMode, .symbolFromKorean)
    }

    /// 기호 자판 page 0 에서 그 글자가 있는 칸을 찾아 누른다 — 칸 위치는 레이아웃 설정에 따라 다르다.
    private func tapSymbol(_ symbol: String, file: StaticString = #filePath, line: UInt = #line) {
        let grid = KeyboardMetrics.symbolLayout(KeyboardSettings.shared.layoutCustomization, page: 0)
        for (row, keys) in grid.enumerated() {
            if let column = keys.firstIndex(of: .symbol(symbol)) {
                viewModel.gestureStarted(row: row, column: column, at: .zero)
                viewModel.gestureEnded(row: row, column: column)
                return
            }
        }
        XCTFail("기호 자판 page 0 에 \(symbol) 가 없다", file: file, line: line)
    }
}

private final class InsertRecorder: KeyboardViewModelDelegate {
    var inserted: [String] = []
    func insertText(_ text: String) { inserted.append(text) }
    func deleteBackward() {}
    func updateComposingText(from previous: String, to current: String) {}
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
}

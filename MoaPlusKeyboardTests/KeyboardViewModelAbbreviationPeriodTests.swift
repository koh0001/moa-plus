import XCTest

/// Regression coverage for the "auto-period after an abbreviation expansion"
/// bug: an expansion inserts `replacement + " "`, so the *next* space would be
/// mistaken for the user's first space and the double-space→period shortcut
/// would turn it into ". " (e.g. "하트 " + space → "하트. ").
///
/// The replacement must end in a letter/digit so the period shortcut's
/// `preceding.isLetter || .isNumber` guard is actually satisfied — a symbol
/// replacement like "♥" would mask the bug. Uses `TextTrackingDelegate` because
/// it implements `textBeforeCursor()`, which the period shortcut needs.
final class KeyboardViewModelAbbreviationPeriodTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: TextTrackingDelegate!

    private var savedStore: ShortcutExpansionStore!
    private var savedAbbreviationEnabled: Bool!
    private var savedPeriodEnabled: Bool!

    override func setUp() {
        super.setUp()
        savedStore = KeyboardSettings.shared.shortcutExpansionStore
        savedAbbreviationEnabled = KeyboardSettings.shared.abbreviationEnabled
        savedPeriodEnabled = KeyboardSettings.shared.periodOnDoubleSpaceEnabled

        var store = ShortcutExpansionStore()
        // Replacement ends in a Hangul syllable (a letter), so the period
        // shortcut's letter/digit guard would fire without the fix.
        store.add(ShortcutExpansion(trigger: "ㅎㅌ", replacement: "하트"))
        KeyboardSettings.shared.shortcutExpansionStore = store
        KeyboardSettings.shared.abbreviationEnabled = true
        KeyboardSettings.shared.periodOnDoubleSpaceEnabled = true

        delegate = TextTrackingDelegate()
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        KeyboardSettings.shared.shortcutExpansionStore = savedStore
        KeyboardSettings.shared.abbreviationEnabled = savedAbbreviationEnabled
        KeyboardSettings.shared.periodOnDoubleSpaceEnabled = savedPeriodEnabled
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    private func expandHatu() {
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "하트 ", "precondition: ㅎㅌ + space expands to '하트 '")
    }

    /// The space immediately after an expansion must stay a plain space — the
    /// expansion's own trailing space must not be turned into ". ".
    func testSpaceRightAfterExpansion_doesNotInsertPeriod() {
        expandHatu()
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "하트  ",
                       "space after expansion is plain, not '하트. '")
    }

    /// After the user types a real character following the expansion, the
    /// period shortcut must behave normally again (the suppression is one-shot).
    func testDoubleSpaceAfterTypingPostExpansion_stillInsertsPeriod() {
        expandHatu() // "하트 "
        viewModel.inputConsonant(.ㄱ) // "하트 ㄱ"
        viewModel.inputSpace()        // "하트 ㄱ "
        viewModel.inputSpace()        // → period
        XCTAssertEqual(delegate.text, "하트 ㄱ. ",
                       "normal double-space→period resumes after typing")
    }

    /// The backspace-restore → re-expand cycle must also suppress the period:
    /// deleting the trailing space restores the trigger, a space re-expands,
    /// and the following space must not period-ize.
    func testReexpandAfterRestore_thenSpace_doesNotInsertPeriod() {
        expandHatu()             // "하트 "
        viewModel.deleteBackward() // restore → "ㅎㅌ"
        XCTAssertEqual(delegate.text, "ㅎㅌ", "precondition: backspace restores trigger")
        viewModel.inputSpace()     // re-expand → "하트 "
        XCTAssertEqual(delegate.text, "하트 ", "precondition: space re-expands")
        viewModel.inputSpace()     // must stay plain
        XCTAssertEqual(delegate.text, "하트  ",
                       "space after re-expansion is plain, not '하트. '")
    }
}

/// Mock delegate simulating a host text field. Tracks a plain string and
/// reports it back via `textBeforeCursor()` so the period shortcut's context
/// check can run in tests.
private final class TextTrackingDelegate: KeyboardViewModelDelegate {
    private(set) var text: String = ""

    func insertText(_ string: String) { text.append(string) }

    func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }

    func updateComposingText(from previous: String, to current: String) {
        for _ in previous where !text.isEmpty { text.removeLast() }
        text.append(current)
    }

    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { text }
}

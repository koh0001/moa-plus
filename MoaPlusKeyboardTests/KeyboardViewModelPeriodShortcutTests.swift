import XCTest

/// Coverage for the double-space → period shortcut (iOS-style ". ").
final class KeyboardViewModelPeriodShortcutTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: TextTrackingDelegate!

    private var savedStore: ShortcutExpansionStore!
    private var savedPeriodEnabled: Bool!

    override func setUp() {
        super.setUp()
        savedStore = KeyboardSettings.shared.shortcutExpansionStore
        savedPeriodEnabled = KeyboardSettings.shared.periodOnDoubleSpaceEnabled
        // Empty the abbreviation store so typed triggers never expand and
        // the test exercises only the period shortcut.
        KeyboardSettings.shared.shortcutExpansionStore = ShortcutExpansionStore()
        KeyboardSettings.shared.periodOnDoubleSpaceEnabled = true

        delegate = TextTrackingDelegate()
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        KeyboardSettings.shared.shortcutExpansionStore = savedStore
        KeyboardSettings.shared.periodOnDoubleSpaceEnabled = savedPeriodEnabled
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// Space after a letter then another space → the trailing space becomes ". ".
    func testDoubleSpaceAfterLetter_insertsPeriod() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputSpace()
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "ㄱ. ")
    }

    /// A single space after a letter must stay a plain space.
    func testSingleSpaceAfterLetter_insertsPlainSpace() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "ㄱ ")
    }

    /// A third space after ". " must not chain into another period — the
    /// character before the trailing space is now punctuation / whitespace.
    func testSpaceAfterPeriodShortcut_doesNotChain() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputSpace()
        viewModel.inputSpace() // → "ㄱ. "
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "ㄱ.  ", "third space stays plain, no '..'")
    }

    /// Two spaces at the start of an empty field must not produce a period.
    func testDoubleSpaceAtLineStart_doesNotInsertPeriod() {
        viewModel.inputSpace()
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "  ")
    }

    /// When the setting is off, double space stays two plain spaces.
    func testDisabled_doesNotInsertPeriod() {
        KeyboardSettings.shared.periodOnDoubleSpaceEnabled = false
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputSpace()
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "ㄱ  ")
    }
}

/// Mock delegate simulating a host text field. Tracks a plain string and
/// reports it back via `textBeforeCursor()` so the period shortcut's
/// context check can run in tests.
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

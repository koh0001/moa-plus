import XCTest

/// Regression coverage for abbreviation expansion + backspace restoration.
///
/// Reproduces the "♥ㅎㅌ" bug: after `ㅎㅌ` expands to `♥` on a delimiter,
/// pressing backspace once must remove the whole `♥ ` footprint and restore
/// the bare trigger — not leave `♥` and append `ㅎㅌ` after it.
final class KeyboardViewModelAbbreviationTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: TextFieldMockDelegate!

    private var savedStore: ShortcutExpansionStore!
    private var savedAbbreviationEnabled: Bool!

    override func setUp() {
        super.setUp()
        // Preserve the real settings so the test machine isn't left dirty.
        savedStore = KeyboardSettings.shared.shortcutExpansionStore
        savedAbbreviationEnabled = KeyboardSettings.shared.abbreviationEnabled

        var store = ShortcutExpansionStore()
        store.add(ShortcutExpansion(trigger: "ㅎㅌ", replacement: "♥"))
        KeyboardSettings.shared.shortcutExpansionStore = store
        KeyboardSettings.shared.abbreviationEnabled = true

        delegate = TextFieldMockDelegate()
        // KeyboardViewModel loads the expansion store in init().
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        KeyboardSettings.shared.shortcutExpansionStore = savedStore
        KeyboardSettings.shared.abbreviationEnabled = savedAbbreviationEnabled
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// Type `ㅎㅌ`, expand with space, then a single backspace must undo the
    /// expansion back to `ㅎㅌ` — the core reported bug.
    func testBackspaceAfterExpansion_restoresTriggerWithoutLeftoverReplacement() {
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "♥ ",
                       "precondition: ㅎㅌ + space expands to '♥ '")

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.text, "ㅎㅌ",
                       "single backspace must restore the bare trigger, not yield '♥ㅎㅌ'")
    }

    /// After the restore, further backspaces delete the restored trigger
    /// character-by-character like normal text.
    func testBackspaceAfterRestore_deletesTriggerNormally() {
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()
        viewModel.deleteBackward() // restore → "ㅎㅌ"

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "ㅎ", "backspace after restore deletes one trigger char")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "", "backspace clears the rest of the trigger")
    }
}

/// Mock delegate that simulates a host text field by maintaining a plain
/// string. All edits happen at the end of the buffer, which matches the
/// append / deleteBackward / marked-text flow the keyboard exercises here.
private final class TextFieldMockDelegate: KeyboardViewModelDelegate {
    private(set) var text: String = ""

    func insertText(_ string: String) { text.append(string) }

    func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
    }

    func updateComposingText(from previous: String, to current: String) {
        // Marked-text simulation: drop the old composing glyph, append the new.
        for _ in previous where !text.isEmpty { text.removeLast() }
        text.append(current)
    }

    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
}

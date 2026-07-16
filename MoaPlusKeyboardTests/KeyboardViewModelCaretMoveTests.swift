import XCTest

/// Regression coverage for the "마지막 입력 글자 중복 삽입" bug: while composing a
/// Hangul syllable, the user taps elsewhere in the host field to move the
/// caret, then types — and the previously-composing glyph gets re-inserted at
/// the new caret.
///
/// Root cause (confirmed on-device): the host that reproduces it (SwiftUI
/// `TextField` / `UITextField`) fires NO `selectionDidChange` on a caret tap,
/// so `handleExternalCursorMove` never runs and the composer stays pointed at
/// the old caret. The keyboard must detect the moved caret at input time. It
/// does so by requiring positive proof the caret is still right after the
/// composing glyph (`textBeforeCursor()` ends with it); anything else — a
/// non-matching context, or a `nil` context at the field start — triggers a
/// fresh composition.
final class KeyboardViewModelCaretMoveTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: CaretTrackingDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = CaretTrackingDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// The exact user repro: type "가나다", move the caret to the very front
    /// (before "가" — where `documentContextBeforeInput` is `nil`), then type
    /// "라". Expected "라가나다"; the bug produced "다라가나다" (the stale "다"
    /// re-inserted before the new input).
    func testTapMoveToFront_thenType_doesNotReinsertOldGlyph() {
        compose가나다()
        XCTAssertEqual(delegate.document, "가나다", "precondition")

        delegate.caret = 0 // tap to the very front — before-context is nil here

        viewModel.inputConsonant(.ㄹ)
        viewModel.inputVowel(.ㅏ)

        XCTAssertEqual(delegate.document, "라가나다",
                       "라 composes at the front; stale 다 must not be re-inserted")
    }

    /// Caret moved into the middle (non-nil, non-matching context) must also
    /// start a fresh composition at the new caret.
    func testTapMoveIntoMiddle_thenType_composesAtNewCaret() {
        delegate.insertText("abc")
        viewModel.inputConsonant(.ㄴ)
        viewModel.inputVowel(.ㅏ)
        XCTAssertEqual(delegate.document, "abc나", "precondition: composing 나 after abc")

        delegate.caret = 1 // between "a" and "b"

        viewModel.inputConsonant(.ㄷ)

        XCTAssertEqual(delegate.document, "aㄷbc나",
                       "ㄷ composes at the new caret; 나 stays put, not re-inserted")
    }

    /// The backstop must NOT over-reset normal composition — including at the
    /// field start, where the caret sits after the first jamo once inserted so
    /// the before-context matches. ㄱ+ㅏ must still form "가".
    func testCompositionAtFieldStart_notResetByBackstop() {
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        XCTAssertEqual(delegate.document, "가",
                       "composition at field start must not be reset mid-syllable")
    }

    /// Backspace after a tap-move must act at the current caret, not decompose
    /// the stale composer (which would rewrite the composing glyph at the wrong
    /// position — e.g. leaving "간" as "가" inserted mid-text).
    func testTapMoveWhileComposing_thenBackspace_deletesAtNewCaret() {
        delegate.insertText("abc")
        viewModel.inputConsonant(.ㄱ)
        viewModel.inputVowel(.ㅏ)
        viewModel.inputConsonant(.ㄴ) // ㄴ folds in as 받침 → composing "간"
        XCTAssertEqual(delegate.document, "abc간", "precondition: composing 간 after abc")

        delegate.caret = 2 // between "b" and "c"

        viewModel.deleteBackward()

        XCTAssertEqual(delegate.document, "ac간",
                       "backspace removes 'b' at the caret; 간 is untouched, not decomposed to 가")
    }

    // 가 = ㄱㅏ, 나 = ㄴㅏ, 다 = ㄷㅏ (each vowel pushes the prior jongseong out).
    private func compose가나다() {
        viewModel.inputConsonant(.ㄱ); viewModel.inputVowel(.ㅏ)
        viewModel.inputConsonant(.ㄴ); viewModel.inputVowel(.ㅏ)
        viewModel.inputConsonant(.ㄷ); viewModel.inputVowel(.ㅏ)
    }
}

/// Mock delegate modelling a document string plus a caret index. Crucially,
/// `textBeforeCursor()` returns `nil` when the caret is at the field start —
/// matching real `UITextDocumentProxy.documentContextBeforeInput`, which the
/// bug depended on.
private final class CaretTrackingDelegate: KeyboardViewModelDelegate {
    private(set) var document: String = ""
    var caret: Int = 0

    func insertText(_ string: String) {
        let idx = document.index(document.startIndex, offsetBy: caret)
        document.insert(contentsOf: string, at: idx)
        caret += string.count
    }

    func deleteBackward() {
        guard caret > 0 else { return }
        let idx = document.index(document.startIndex, offsetBy: caret - 1)
        document.remove(at: idx)
        caret -= 1
    }

    func updateComposingText(from previous: String, to current: String) {
        for _ in previous { deleteBackward() }
        insertText(current)
    }

    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {
        caret = max(0, min(document.count, caret + offset))
    }
    func textBeforeCursor() -> String? {
        caret == 0 ? nil : String(document.prefix(caret))
    }
    func textAfterCursor() -> String? {
        caret == document.count ? nil : String(document.suffix(document.count - caret))
    }
}

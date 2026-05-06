import XCTest

final class KeyboardViewModelShiftTests: XCTestCase {
    private var vm: KeyboardViewModel!
    private var mockDelegate: MockShiftDelegate!

    override func setUp() {
        super.setUp()
        vm = KeyboardViewModel()
        mockDelegate = MockShiftDelegate()
        vm.delegate = mockDelegate
        vm.keyboardMode = .english
    }

    override func tearDown() {
        vm = nil
        mockDelegate = nil
        super.tearDown()
    }

    func test_shift_off_inputsLowercase() {
        XCTAssertEqual(vm.shiftState, .off)
        vm.inputSymbol("a")
        XCTAssertEqual(mockDelegate.insertedTexts.last, "a")
    }

    func test_shift_on_inputsUppercase_thenAutoOff() {
        vm.toggleShift()  // off → on
        XCTAssertEqual(vm.shiftState, .on)
        vm.inputSymbol("a")
        XCTAssertEqual(mockDelegate.insertedTexts.last, "A")
        XCTAssertEqual(vm.shiftState, .off)  // auto-released after one letter
    }

    func test_shift_on_then_off_by_tap() {
        vm.toggleShift()  // off → on
        XCTAssertEqual(vm.shiftState, .on)
        // Wait past doubleTapInterval (0.3s) so the next tap is treated as a
        // single tap (.on → .off) rather than a caps-lock double-tap.
        Thread.sleep(forTimeInterval: 0.31)
        vm.toggleShift()
        XCTAssertEqual(vm.shiftState, .off)
    }

    func test_shiftLocked_keepsUppercase() {
        vm.shiftState = .locked
        vm.inputSymbol("a")
        vm.inputSymbol("b")
        XCTAssertEqual(mockDelegate.insertedTexts.suffix(2), ["A", "B"])
        XCTAssertEqual(vm.shiftState, .locked)
    }

    func test_shiftLocked_tap_turnsOff() {
        vm.shiftState = .locked
        vm.toggleShift()  // locked → off
        XCTAssertEqual(vm.shiftState, .off)
    }

    func test_letterModeToggle_resetsShift() {
        vm.shiftState = .on
        vm.toggleLetterMode()  // english → korean
        XCTAssertEqual(vm.shiftState, .off)
    }

    func test_shift_notApplied_inKoreanMode() {
        vm.keyboardMode = .korean
        vm.shiftState = .on
        // inputSymbol in Korean mode should not transform (Korean letters don't uppercase)
        vm.inputSymbol("!")
        XCTAssertEqual(mockDelegate.insertedTexts.last, "!")
        // shiftState unchanged since shiftedSymbolIfNeeded returns early for non-english
        XCTAssertEqual(vm.shiftState, .on)
    }

    // MARK: - Caps lock long-press regression

    /// Holding the shift key fires `lockShift()` while the finger is still
    /// down. When the finger lifts, `gestureEnded` runs and previously
    /// called `toggleShift()` which immediately undid the lock — so the
    /// user could only sustain caps lock by keeping the finger pressed.
    /// Regression test: after `lockShift()` followed by `gestureEnded` on
    /// the shift key, the state must remain `.locked`.
    func test_capsLockLongPress_survivesGestureEnd() {
        // shift key is at row 3, col 0 in english layout (functional .shift)
        // The exact coordinates don't matter for this test as long as the
        // gesture lifecycle is exercised correctly.
        vm.gestureStarted(row: 3, column: 0, at: .zero)
        vm.lockShift()
        XCTAssertEqual(vm.shiftState, .locked, "long-press toggles caps lock on")

        vm.gestureEnded(row: 3, column: 0)
        XCTAssertEqual(
            vm.shiftState,
            .locked,
            "caps lock must remain on after the finger lifts; the trailing tap should be suppressed by didHandleShiftLongPressInCurrentGesture"
        )
    }

    /// A second long-press toggles caps lock back off.
    func test_capsLockLongPress_secondHoldTurnsOff() {
        vm.shiftState = .locked

        vm.gestureStarted(row: 3, column: 0, at: .zero)
        vm.lockShift()
        XCTAssertEqual(vm.shiftState, .off, "second long-press releases caps lock")
        vm.gestureEnded(row: 3, column: 0)
        XCTAssertEqual(vm.shiftState, .off, "released state survives gesture end")
    }

    /// A normal tap on shift (no long-press) still toggles state via
    /// `gestureEnded` — the suppression flag must only fire when
    /// `lockShift()` actually ran.
    func test_normalShiftTap_stillToggles() {
        vm.gestureStarted(row: 3, column: 0, at: .zero)
        // No lockShift() call — simulating a quick tap that doesn't reach
        // the long-press threshold.
        vm.gestureEnded(row: 3, column: 0)
        XCTAssertEqual(vm.shiftState, .on, "quick tap toggles to .on")
    }
}

private final class MockShiftDelegate: KeyboardViewModelDelegate {
    var insertedTexts: [String] = []
    var deleteCount = 0
    var cursorMoves: [Int] = []

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() { deleteCount += 1 }
    func updateComposingText(from previous: String, to current: String) {}
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) { cursorMoves.append(offset) }
}

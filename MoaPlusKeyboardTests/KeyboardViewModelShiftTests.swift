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

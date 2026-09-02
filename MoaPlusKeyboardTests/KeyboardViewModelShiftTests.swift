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

    // MARK: - 영문 문장 첫 글자 대문자 (기본 OFF)

    private func withAutoCap(_ enabled: Bool, _ body: () -> Void) {
        let settings = KeyboardSettings.shared
        let saved = settings.englishAutoCapitalizeEnabled
        settings.englishAutoCapitalizeEnabled = enabled
        body()
        settings.englishAutoCapitalizeEnabled = saved
    }

    func test_autoCapitalize_disabledByDefault() {
        XCTAssertFalse(KeyboardSettings.shared.englishAutoCapitalizeEnabled)
    }

    func test_autoCapitalize_off_doesNotArmShift() {
        withAutoCap(false) {
            mockDelegate.before = ""
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .off)
        }
    }

    func test_autoCapitalize_armsOnEmptyField() {
        withAutoCap(true) {
            mockDelegate.before = ""
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .on)
            vm.inputSymbol("a")
            XCTAssertEqual(mockDelegate.insertedTexts.last, "A")
        }
    }

    func test_autoCapitalize_armsAfterTerminatorAndSpace() {
        withAutoCap(true) {
            mockDelegate.before = "Hi. "
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .on)
        }
    }

    /// 종결부호 **직후**(공백 없음)에는 켜지면 안 된다 — "Hi.Q" 방지.
    func test_autoCapitalize_notArmedRightAfterTerminator() {
        withAutoCap(true) {
            mockDelegate.before = "Hi."
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .off)
        }
    }

    func test_autoCapitalize_notArmedMidSentence() {
        withAutoCap(true) {
            mockDelegate.before = "hello "
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .off)
        }
    }

    func test_autoCapitalize_skippedInKoreanMode() {
        withAutoCap(true) {
            vm.keyboardMode = .korean
            mockDelegate.before = ""
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .off)
        }
    }

    func test_autoCapitalize_neverBreaksCapsLock() {
        withAutoCap(true) {
            vm.shiftState = .locked
            mockDelegate.before = "hello "
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .locked)
        }
    }

    /// 이메일·비밀번호 필드처럼 호스트가 대문자화를 원하지 않으면 무동작.
    func test_autoCapitalize_respectsHostOptOut() {
        withAutoCap(true) {
            mockDelegate.allowsAutoCapitalization = false
            mockDelegate.before = ""
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .off)
        }
    }

    /// 앞뒤 문맥을 **모두** 안 주는 호스트(시큐어 필드)에서만 추측을 포기한다.
    func test_autoCapitalize_noContextAtAll_isNoOp() {
        withAutoCap(true) {
            mockDelegate.before = nil
            mockDelegate.after = nil
            mockDelegate.hasText = true
            vm.shiftState = .on
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .on)
        }
    }

    /// 문서 맨 앞을 탭한 경우: 앞 문맥은 nil 이지만 뒤 문맥이 오므로 문장 시작이다.
    /// 실기기 A6 회귀 가드 — 문장 시작을 눌러도 안 켜지던 증상.
    func test_autoCapitalize_caretAtDocumentStart_arms() {
        withAutoCap(true) {
            mockDelegate.before = nil
            mockDelegate.after = "hello world"
            mockDelegate.hasText = true
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .on)
        }
    }

    /// 빈 입력창은 문맥이 nil 로 오지만(호스트가 줄 게 없다) 문장 시작이 맞다.
    /// 원 제보의 핵심 시나리오 — 이 갈래가 없으면 A1 이 영영 동작하지 않는다.
    func test_autoCapitalize_nilContextEmptyDocument_arms() {
        withAutoCap(true) {
            mockDelegate.before = nil
            mockDelegate.hasText = false
            vm.refreshAutoCapitalization()
            XCTAssertEqual(vm.shiftState, .on)
        }
    }

    /// 한글로 진입해 영문으로 전환했을 때도 문장 시작이면 켜져야 한다.
    func test_autoCapitalize_armsAfterSwitchingToEnglish() {
        withAutoCap(true) {
            vm.keyboardMode = .korean
            mockDelegate.before = nil
            mockDelegate.hasText = false
            vm.toggleLetterMode()
            XCTAssertEqual(vm.keyboardMode, .english)
            XCTAssertEqual(vm.shiftState, .on)
        }
    }

    /// 호스트가 우리 삽입에 대해 `textDidChange` 를 안 쏘는 경우의 백스톱.
    /// 실기기 A3 실패(". " 뒤 재무장 안 됨)의 회귀 가드다.
    func test_autoCapitalize_rearmsAfterOurOwnSpace() {
        withAutoCap(true) {
            mockDelegate.before = "Hi. "
            vm.inputSpace()
            // 판정은 다음 런루프 틱으로 미뤄진다(프록시 문맥이 아직 갱신 전일 수 있어서).
            let settled = expectation(description: "auto-cap refresh settled")
            DispatchQueue.main.async { settled.fulfill() }
            wait(for: [settled], timeout: 1.0)
            XCTAssertEqual(vm.shiftState, .on)
        }
    }

    func test_autoCapitalize_disarmsAfterBackspaceIntoSentence() {
        withAutoCap(true) {
            vm.shiftState = .on
            mockDelegate.before = "Hi"
            vm.deleteBackward()
            let settled = expectation(description: "auto-cap refresh settled")
            DispatchQueue.main.async { settled.fulfill() }
            wait(for: [settled], timeout: 1.0)
            XCTAssertEqual(vm.shiftState, .off)
        }
    }

    // MARK: - 영문 롱프레스 대문자 (기본 ON)

    func test_longPressUppercase_enabledByDefault() {
        XCTAssertTrue(KeyboardSettings.shared.englishLongPressUppercaseEnabled)
    }

    /// 롱프레스 대문자는 `inputSymbol` 경로를 타야 한다: 시프트 `.on` 을 소비하고
    /// 약어 버퍼에 문자를 흘려야 다음 탭이 연달아 대문자가 되지 않는다.
    func test_longPressUppercase_consumesPendingShift() {
        vm.shiftState = .on
        vm.inputLongPressNumber("Q")
        vm.confirmPopupSelection()
        XCTAssertEqual(mockDelegate.insertedTexts.last, "Q")
        XCTAssertEqual(vm.shiftState, .off, "shift must not stay armed after a long-press capital")
    }

    func test_longPressUppercase_capsLockSurvives() {
        vm.shiftState = .locked
        vm.inputLongPressNumber("Q")
        vm.confirmPopupSelection()
        XCTAssertEqual(mockDelegate.insertedTexts.last, "Q")
        XCTAssertEqual(vm.shiftState, .locked)
    }
}

private final class MockShiftDelegate: KeyboardViewModelDelegate {
    var insertedTexts: [String] = []
    var deleteCount = 0
    var cursorMoves: [Int] = []
    var before: String?
    var allowsAutoCapitalization = true
    var hasText = false
    var after: String?

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() { deleteCount += 1 }
    func updateComposingText(from previous: String, to current: String) {}
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) { cursorMoves.append(offset) }
    func textBeforeCursor() -> String? { before }
    func textAfterCursor() -> String? { after }
    func hostAllowsAutoCapitalization() -> Bool { allowsAutoCapitalization }
    func hostHasText() -> Bool { hasText }
}

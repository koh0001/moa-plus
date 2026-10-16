import XCTest

/// 테스트가 건드리는 `KeyboardSettings.shared` 값을 고정했다가 되돌린다. 공유 싱글톤은 App
/// Group 저장소에 쓰므로 고정하지 않으면 시뮬레이터에 남은 값(롱프레스 매핑·괄호 자동 닫기·
/// 모드 기억)에 결과가 좌우되고, 테스트가 바꾼 값이 다음 테스트로 샌다.
struct LongPressSettingsPin {
    private let actions: [SecondaryKeyAction]
    private let autoBracket: Bool
    private let rememberMode: Bool
    private let lastLetterMode: String
    private let migrated: Bool
    private let layout: LayoutCustomization

    /// 현재 값을 기억하고 테스트 기준값(기본 매핑·괄호 자동 닫기 ON·모드 기억 OFF·한글·
    /// 이전 완료·기본 레이아웃)으로 고정한다. 뷰모델 생성 **전에** 불러야 한다 — `init` 이
    /// 모드 기억 설정을 읽는다.
    init() {
        let s = KeyboardSettings.shared
        actions = s.secondaryKeyActions
        autoBracket = s.autoBracketEnabled
        rememberMode = s.rememberLastKeyboardMode
        lastLetterMode = s.lastKeyboardLetterMode
        migrated = s.longPressPrimaryMigrated
        layout = s.layoutCustomization

        s.secondaryKeyActions = SecondaryKeyAction.defaults
        s.autoBracketEnabled = true
        s.rememberLastKeyboardMode = false
        s.lastKeyboardLetterMode = "korean"
        s.longPressPrimaryMigrated = true
        s.layoutCustomization = LayoutCustomization()
    }

    func restore() {
        let s = KeyboardSettings.shared
        s.secondaryKeyActions = actions
        s.autoBracketEnabled = autoBracket
        s.rememberLastKeyboardMode = rememberMode
        s.lastKeyboardLetterMode = lastLetterMode
        s.longPressPrimaryMigrated = migrated
        s.layoutCustomization = layout
    }

    /// 기본 매핑에서 한 키만 고친 매핑을 저장한다 (설정 화면에서 그 키만 편집한 상태).
    static func edit(_ keyId: String, _ change: (inout SecondaryKeyAction) -> Void) {
        KeyboardSettings.shared.secondaryKeyActions = SecondaryKeyAction.defaults.map {
            guard $0.keyId == keyId else { return $0 }
            var edited = $0
            change(&edited)
            return edited
        }
    }
}

final class KeyboardViewModelLongPressTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: SpyKeyboardDelegate!
    private var pin: LongPressSettingsPin!

    override func setUp() {
        super.setUp()
        pin = LongPressSettingsPin()
        viewModel = KeyboardViewModel()
        delegate = SpyKeyboardDelegate()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        pin.restore()
        pin = nil
        super.tearDown()
    }

    // MARK: - 롱프레스 출력 설정 반영 (이슈 #37, 앱스토어 리뷰 "ㅈ은 다르게 설정해도 7로만")

    /// 그리드가 이 키에 거는 롱키 트리거 — 키보드와 **같은 함수**(`KeyGridView.longPressBinding`)로 구한다.
    private func gridTrigger(row: Int, column: Int) -> String? {
        let s = KeyboardSettings.shared
        let content = KeyboardMetrics.keyContent(at: row, column: column, mode: viewModel.keyboardMode,
                                                 layout: s.layoutCustomization, symbolPage: viewModel.symbolPage)
        return KeyGridView.longPressBinding(
            content: content, row: row, column: column, mode: viewModel.keyboardMode,
            layout: s.layoutCustomization,
            englishLongPressUppercase: s.englishLongPressUppercaseEnabled,
            storedAction: { s.secondaryAction(forKey: $0) }
        ).trigger
    }

    /// 길게 눌러 팝업을 띄운다 (손은 아직 안 뗐다).
    private func longPress(row: Int, column: Int, file: StaticString = #filePath, line: UInt = #line) {
        viewModel.gestureStarted(row: row, column: column, at: .zero)
        guard let trigger = gridTrigger(row: row, column: column) else {
            return XCTFail("(\(row),\(column)) 에 롱키 트리거가 없다", file: file, line: line)
        }
        viewModel.inputLongPressNumber(trigger)
    }

    /// 팝업이 뜬 상태에서 손을 뗀다. 실제 키는 팝업이 떠 있으면 `onPopupRelease` 만 부르고
    /// 끝나므로(`gestureEnded` 없음) 여기서도 그렇게 한다. 롱키는 조합 중인 글자를 만들지 않는다.
    private func release(file: StaticString = #filePath, line: UInt = #line) {
        viewModel.confirmPopupSelection()
        XCTAssertTrue(delegate.composingUpdates.isEmpty, "롱키 확정이 조합 글자를 건드렸다", file: file, line: line)
    }

    /// 길게 눌렀다 드래그 없이 뗀다.
    private func longPressAndRelease(row: Int, column: Int, file: StaticString = #filePath, line: UInt = #line) {
        longPress(row: row, column: column, file: file, line: line)
        release(file: file, line: line)
    }

    /// 팝업 오버레이가 그릴 후보 — 오버레이와 같은 함수.
    private var overlayCandidates: [String] {
        KeyboardView.popupDisplayCandidates(candidates: viewModel.longPressPopupCandidates,
                                            text: viewModel.longPressPopupText)
    }

    func test_editedPrimaryOutput_isInsertedOnRelease() {
        LongPressSettingsPin.edit("ㅈ") { $0.visibleHint = "@"; $0.primaryLongPressOutput = "@" }
        longPressAndRelease(row: 1, column: 2)   // ㅈ
        XCTAssertEqual(delegate.insertedTexts, ["@"], "고치기 전에는 후보 첫 번째인 7 이 들어갔다")
    }

    func test_editedPrimaryOutput_leadsPopupCandidates_keepingTheRest() {
        LongPressSettingsPin.edit("ㅈ") { $0.primaryLongPressOutput = "@" }
        longPress(row: 1, column: 2)
        XCTAssertEqual(viewModel.longPressPopupText, "@", "그리드 트리거도 고친 출력")
        XCTAssertEqual(viewModel.longPressPopupCandidates, ["@", "7", "&"])
        XCTAssertEqual(overlayCandidates, ["@", "7", "&"])
    }

    func test_defaultMapping_isUnchanged() {
        longPressAndRelease(row: 1, column: 2)
        XCTAssertEqual(delegate.insertedTexts, ["7"])
    }

    // MARK: 닫는 괄호 — 괄호 자동 닫기 ON 에서도 롱프레스 출력은 빠지지 않는다

    func test_closingBracketPrimary_withAutoBracket_isInsertedAndLeadsCandidates() {
        XCTAssertTrue(KeyboardSettings.shared.autoBracketEnabled)
        // ㄱ 기본 후보 9 ( ) — 출력을 ")" 로 고침. 예전에는 필터가 ")" 를 빼 9 가 들어갔다.
        LongPressSettingsPin.edit("ㄱ") { $0.primaryLongPressOutput = ")" }
        longPress(row: 1, column: 4)
        XCTAssertEqual(viewModel.longPressPopupCandidates.first, ")")
        XCTAssertEqual(viewModel.longPressPopupCandidates, [")", "9", "("])
        XCTAssertEqual(overlayCandidates, [")", "9", "("], "오버레이가 다시 걸러 뷰모델과 어긋나면 안 된다")
        release()
        XCTAssertEqual(delegate.insertedTexts, [")"])
    }

    func test_everyCandidateIsCloser_popupStillShowsPrimary() {
        LongPressSettingsPin.edit("ㅈ") {
            $0.primaryLongPressOutput = ")"
            $0.popupOutputs = ["]", "}", ")"]
        }
        longPress(row: 1, column: 2)
        XCTAssertEqual(viewModel.longPressPopupCandidates, [")"], "후보가 비면 오버레이가 빈 점 팝업을 그렸다")
        XCTAssertEqual(overlayCandidates, [")"])
        release()
        XCTAssertEqual(delegate.insertedTexts, [")"])
    }

    func test_englishZeroKey_defaultCloserPrimary_isNotFilteredAway() {
        // 영문 0 = ")" 하나뿐 — 예전에는 필터로 후보가 비고 오버레이가 그 텍스트까지 걸러 빈 팝업이 떴다.
        viewModel.keyboardMode = .english
        longPress(row: 0, column: 9)   // "0"
        XCTAssertEqual(viewModel.longPressPopupCandidates, [")"])
        XCTAssertEqual(overlayCandidates, [")"])
        release()
        XCTAssertEqual(delegate.insertedTexts, [")"])
    }

    func test_symbolMode_closerAlternatesAreKept() {
        // 심볼 모드는 필터를 쓰지 않는다 — ")" 의 대체 문자 ] } > 가 그대로.
        viewModel.keyboardMode = .symbolFromKorean
        let layout = KeyboardMetrics.activeLayout(for: .symbolFromKorean, layout: KeyboardSettings.shared.layoutCustomization)
        guard let row = layout.firstIndex(where: { $0.contains(.symbol(")")) }),
              let column = layout[row].firstIndex(of: .symbol(")")) else {
            return XCTFail("심볼 page 0 에 ) 키가 없다")
        }
        longPress(row: row, column: column)
        XCTAssertEqual(viewModel.longPressPopupCandidates, ["]", "}", ">"])
        XCTAssertEqual(overlayCandidates, ["]", "}", ">"])
    }

    // MARK: 영문 숫자 키

    func test_englishDigitKey_editedPrimary_isTriggerAndInsertedOnRelease() {
        LongPressSettingsPin.edit("1") { $0.primaryLongPressOutput = "?" }
        viewModel.keyboardMode = .english
        longPress(row: 0, column: 0)   // "1"
        XCTAssertEqual(viewModel.longPressPopupText, "?")
        XCTAssertEqual(viewModel.longPressPopupCandidates, ["?", "!"])
        release()
        XCTAssertEqual(delegate.insertedTexts, ["?"])
    }

    // MARK: 오른쪽 끝 키 — 드래그 방향이 반대

    func test_rightEdgeConsonant_primaryFirst_leftDragPicksNext() {
        // ㅅ (1,5) 기본 후보 0 - _ + = — 출력을 "-" 로.
        LongPressSettingsPin.edit("ㅅ") { $0.primaryLongPressOutput = "-" }
        longPress(row: 1, column: 5)
        XCTAssertEqual(viewModel.longPressPopupCandidates, ["-", "0", "_", "+", "="])
        XCTAssertEqual(viewModel.longPressPopupSelectedIndex, 0)
        viewModel.updatePopupSelection(translationX: -45)   // 오른쪽 끝은 왼쪽 드래그 = 다음 후보
        XCTAssertEqual(viewModel.longPressPopupSelectedIndex, 1)
        release()
        XCTAssertEqual(delegate.insertedTexts, ["0"])
    }

    func test_rightEdgeConsonant_releaseWithoutDrag_insertsPrimary() {
        LongPressSettingsPin.edit("ㅅ") { $0.primaryLongPressOutput = "+" }
        longPressAndRelease(row: 1, column: 5)
        XCTAssertEqual(delegate.insertedTexts, ["+"])
    }

    // MARK: 공백·빈 값

    func test_whitespacePrimary_isTrimmed() {
        LongPressSettingsPin.edit("ㅈ") {
            $0.primaryLongPressOutput = " @ "
            $0.popupOutputs = [" 7", "", "&", "7", "@"]
        }
        longPress(row: 1, column: 2)
        XCTAssertEqual(viewModel.longPressPopupText, "@")
        XCTAssertEqual(viewModel.longPressPopupCandidates, ["@", "7", "&"], "공백 제거 + 빈 칸·중복 제거")
        release()
        XCTAssertEqual(delegate.insertedTexts, ["@"], "공백까지 들어가면 안 된다")
    }

    func test_whitespaceOnlyPrimary_fallsBackToFirstPopupOutput() {
        LongPressSettingsPin.edit("ㅈ") { $0.primaryLongPressOutput = "   " }
        longPressAndRelease(row: 1, column: 2)
        XCTAssertEqual(delegate.insertedTexts, ["7"])
    }

    func test_emptyAction_fallsBackToLayoutTable() {
        LongPressSettingsPin.edit("ㅈ") {
            $0.primaryLongPressOutput = ""
            $0.popupOutputs = [" "]
        }
        longPress(row: 1, column: 2)
        XCTAssertEqual(viewModel.longPressPopupCandidates, [])
        XCTAssertEqual(overlayCandidates, ["7"], "후보가 없으면 트리거 글자 하나를 그린다")
        release()
        XCTAssertEqual(delegate.insertedTexts, ["7"])
    }

    // MARK: - 기존 동작
    // 아래 두 롱키 테스트는 팝업 확정 뒤 늦게 온 `gestureEnded` 가 자음을 또 넣지 않는지
    // (억제 플래그)를 지키는 테스트라 `gestureEnded` 를 일부러 부른다.

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

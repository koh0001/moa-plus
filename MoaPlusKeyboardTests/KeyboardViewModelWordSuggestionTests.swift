import XCTest

/// 단어 추천 (메일 제보 2026-11, `KeyboardViewModel.refreshWordSuggestions`/`acceptWordSuggestion`).
/// 후보 소스는 시스템 `UITextChecker` 라 구체 단어는 OS 사전에 따라 바뀐다 — 단어를 못박지 않고
/// 접두·개수·표시 조건만 본다. 실제 키보드에서는 컨트롤러가 글자 변경마다 refresh 를 부르므로
/// 테스트도 고르기 전에 refresh 를 부른다.
final class KeyboardViewModelWordSuggestionTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: ContextDelegate!
    private var savedEnabled: Bool!

    override func setUp() {
        super.setUp()
        savedEnabled = KeyboardSettings.shared.wordSuggestionEnabled
        KeyboardSettings.shared.wordSuggestionEnabled = true
        delegate = ContextDelegate()
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        KeyboardSettings.shared.wordSuggestionEnabled = savedEnabled
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    func test_token_isTrailingRunOfLetters() {
        XCTAssertEqual(KeyboardViewModel.wordSuggestionToken(before: "안녕 감ㅅ"), "감ㅅ")
        XCTAssertEqual(KeyboardViewModel.wordSuggestionToken(before: "hello, Wor"), "Wor")
        XCTAssertEqual(KeyboardViewModel.wordSuggestionToken(before: "hello "), "")
        XCTAssertEqual(KeyboardViewModel.wordSuggestionToken(before: nil), "")
    }

    /// "don't" 에서 t 만 단어로 보면 고를 때 "don'the" 가 된다. 앞쪽 따옴표는 단어가 아니다.
    func test_token_keepsInnerApostrophe_dropsLeadingQuote() {
        XCTAssertEqual(KeyboardViewModel.wordSuggestionToken(before: "I don't"), "don't")
        XCTAssertEqual(KeyboardViewModel.wordSuggestionToken(before: "그는 '감ㅅ"), "감ㅅ")
    }

    func test_korean_partialSyllable_suggestsCompletionsStartingWithTypedSyllable() {
        delegate.text = "고마워요 감ㅅ"
        viewModel.refreshWordSuggestions()
        XCTAssertTrue(viewModel.isWordSuggestionBarVisible)
        XCTAssertFalse(viewModel.wordSuggestions.isEmpty, "ko_KR 완성어가 비었다 — UITextChecker 한국어 동작이 바뀌었나?")
        XCTAssertLessThanOrEqual(viewModel.wordSuggestions.count, 3)
        XCTAssertTrue(viewModel.wordSuggestions.allSatisfy { $0.hasPrefix("감") }, "\(viewModel.wordSuggestions)")
    }

    /// 대문자로 시작한 단어는 후보도 대문자로 — 그렇게 바꾼 뒤 입력한 단어 자체("The")는 다시 내지 않는다.
    func test_english_capitalizedToken_keepsCapital_andNeverEchoesToken() {
        viewModel.keyboardMode = .english
        delegate.text = "Hel"
        viewModel.refreshWordSuggestions()
        XCTAssertFalse(viewModel.wordSuggestions.isEmpty)
        XCTAssertTrue(viewModel.wordSuggestions.allSatisfy { $0.hasPrefix("Hel") }, "\(viewModel.wordSuggestions)")
        delegate.text = "The"
        viewModel.refreshWordSuggestions()
        XCTAssertFalse(viewModel.wordSuggestions.contains("The"), "\(viewModel.wordSuggestions)")
    }

    /// 후보가 없어도 바 자리는 유지 — 여닫으면 매 키마다 키보드 높이가 출렁인다.
    func test_noToken_keepsBarButClearsSuggestions() {
        delegate.text = "감ㅅ"
        viewModel.refreshWordSuggestions()
        delegate.text = "감사 "
        viewModel.refreshWordSuggestions()
        XCTAssertTrue(viewModel.isWordSuggestionBarVisible)
        XCTAssertTrue(viewModel.isCandidateBarVisible)
        XCTAssertEqual(viewModel.wordSuggestions, [])
    }

    func test_settingOff_hidesBar() {
        KeyboardSettings.shared.wordSuggestionEnabled = false
        delegate.text = "감ㅅ"
        viewModel.refreshWordSuggestions()
        XCTAssertFalse(viewModel.isWordSuggestionBarVisible)
        XCTAssertFalse(viewModel.isCandidateBarVisible)
        XCTAssertEqual(viewModel.wordSuggestions, [])
    }

    /// 컨트롤러가 높이 계산 전에 동기로 부르는 판정 — 사전 조회 없이 자리만 정한다.
    func test_visibilityOnly_setsBarWithoutSuggestions() {
        delegate.text = "감ㅅ"
        XCTAssertTrue(viewModel.updateWordSuggestionBarVisibility())
        XCTAssertTrue(viewModel.isCandidateBarVisible)
        XCTAssertEqual(viewModel.wordSuggestions, [])
    }

    func test_excludedField_hidesBar() {
        delegate.allowsAutomation = false   // 이메일·URL·숫자·비밀번호 칸
        delegate.text = "감ㅅ"
        viewModel.refreshWordSuggestions()
        XCTAssertFalse(viewModel.isWordSuggestionBarVisible)
        XCTAssertEqual(viewModel.wordSuggestions, [])
    }

    func test_symbolMode_keepsBarButNoSuggestions() {
        viewModel.keyboardMode = .symbolFromKorean
        delegate.text = "감ㅅ"
        viewModel.refreshWordSuggestions()
        XCTAssertTrue(viewModel.isWordSuggestionBarVisible)
        XCTAssertEqual(viewModel.wordSuggestions, [])
    }

    /// 캐럿 앞 단어만 지우고 추천 + 공백을 넣는다 — 앞 단어(안녕)는 건드리지 않는다.
    func test_accept_replacesOnlyCurrentWord() {
        delegate.text = "안녕 감ㅅ"
        viewModel.refreshWordSuggestions()
        viewModel.acceptWordSuggestion("감사합니다")
        XCTAssertEqual(delegate.text, "안녕 감사합니다 ")
        XCTAssertEqual(viewModel.wordSuggestions, [])
    }

    /// 조합 중에 고르면 조합을 확정해야 한다 — 안 하면 다음 자음이 지운 글자 자리에 다시 조합된다.
    func test_accept_whileComposing_nextConsonantStartsFresh() {
        viewModel.inputConsonant(.ㄱ)
        XCTAssertEqual(delegate.text, "ㄱ")
        viewModel.refreshWordSuggestions()
        viewModel.acceptWordSuggestion("감사")
        XCTAssertEqual(delegate.text, "감사 ")
        viewModel.inputConsonant(.ㄴ)
        XCTAssertEqual(delegate.text, "감사 ㄴ")
    }

    /// 캐럿 탭을 알리지 않는 호스트: "hel" 후보가 남은 채 캐럿이 "world" 뒤로 가 있으면 바꾸지 않는다.
    func test_accept_staleSuggestions_doNotReplaceOtherWord() {
        viewModel.keyboardMode = .english
        delegate.text = "hel"
        viewModel.refreshWordSuggestions()
        delegate.text = "hel world"   // 알림 없이 캐럿이 world 뒤로 옮겨 간 상태
        viewModel.acceptWordSuggestion("hello")
        XCTAssertEqual(delegate.text, "hel world")
    }

    /// 단어 중간("hel|lo")이면 후보를 내지 않는다 — 고르면 "hello lo" 가 된다.
    func test_caretMidWord_noSuggestions() {
        viewModel.keyboardMode = .english
        delegate.text = "hel"
        delegate.after = "lo"
        viewModel.refreshWordSuggestions()
        XCTAssertEqual(viewModel.wordSuggestions, [])
        viewModel.acceptWordSuggestion("hello")
        XCTAssertEqual(delegate.text, "hel")
    }

    /// 선택 영역이 있으면 첫 삭제가 선택을 지워 글자 수가 어긋난다 — 후보도, 고르기도 없다.
    func test_selection_noSuggestions() {
        viewModel.keyboardMode = .english
        delegate.text = "hel"
        delegate.hasSelection = true
        viewModel.refreshWordSuggestions()
        XCTAssertEqual(viewModel.wordSuggestions, [])
        viewModel.acceptWordSuggestion("hello")
        XCTAssertEqual(delegate.text, "hel")
    }

    /// 추천 뒤 자동 공백에 문장부호가 오면 공백을 거둔다(iOS 순정과 같음). 다른 걸 친 뒤면 그대로.
    func test_punctuationAfterAcceptedSuggestion_removesAutoSpace() {
        delegate.text = "감ㅅ"
        viewModel.refreshWordSuggestions()
        viewModel.acceptWordSuggestion("감사합니다")
        viewModel.refreshWordSuggestions()   // 컨트롤러가 삽입 뒤 부른다
        viewModel.inputSymbol(".")
        XCTAssertEqual(delegate.text, "감사합니다.")

        viewModel.inputSymbol(" ")
        XCTAssertEqual(delegate.text, "감사합니다. ")
        viewModel.inputSymbol(",")
        XCTAssertEqual(delegate.text, "감사합니다. ,", "사용자가 직접 친 공백은 건드리지 않는다")
    }
}

/// 문맥을 진짜 문자열로 들고 있는 스텁 — 삭제·삽입·조합 갱신이 캐럿 앞 문맥에 그대로 반영된다.
private final class ContextDelegate: KeyboardViewModelDelegate {
    var text = ""
    var after: String?
    var hasSelection = false
    var allowsAutomation = true

    func insertText(_ s: String) { text += s }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func updateComposingText(from previous: String, to current: String) {
        for _ in previous { deleteBackward() }
        text += current
    }
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { text.isEmpty ? nil : text }
    func textAfterCursor() -> String? { after }
    func hostAllowsAutoCapitalization() -> Bool { allowsAutomation }
    func hostHasText() -> Bool { !text.isEmpty || after != nil }
    func hostHasSelection() -> Bool { hasSelection }
}

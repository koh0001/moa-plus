import XCTest

/// iOS 텍스트 대치 연동 (설정 `systemTextReplacementEnabled`, 앱스토어 리뷰 2026-10).
/// 렉시콘 자체는 키보드 익스텐션에서만 받을 수 있어, 받은 항목을 넣은 뒤의 걸러내기·합치기·확장을 본다.
final class KeyboardViewModelTextReplacementTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: TextRecorder!
    private var saved: (store: ShortcutExpansionStore, enabled: Bool, abbr: Bool, keepSpace: Bool)!

    override func setUp() {
        super.setUp()
        let s = KeyboardSettings.shared
        saved = (s.shortcutExpansionStore, s.systemTextReplacementEnabled, s.abbreviationEnabled,
                 s.abbreviationKeepConfirmSpaceEnabled)
        s.abbreviationEnabled = true
        s.abbreviationKeepConfirmSpaceEnabled = true
        s.systemTextReplacementEnabled = true
        s.shortcutExpansionStore = ShortcutExpansionStore()
    }

    override func tearDown() {
        let s = KeyboardSettings.shared
        s.shortcutExpansionStore = saved.store
        s.systemTextReplacementEnabled = saved.enabled
        s.abbreviationEnabled = saved.abbr
        s.abbreviationKeepConfirmSpaceEnabled = saved.keepSpace
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    private func makeViewModel() {
        delegate = TextRecorder()
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
        viewModel.keyboardMode = .english
    }

    private func type(_ word: String) {
        for c in word { viewModel.inputSymbol(String(c)) }
        viewModel.inputSpace()
    }

    /// 연락처 이름(입력 = 결과)·빈 값·공백 든 단축키·대소문자만 다른 중복은 뺀다.
    func test_lexiconEntries_filtered() {
        let result = KeyboardViewModel.textReplacementExpansions(from: [
            (userInput: "omw", documentText: "On my way!"),
            (userInput: "홍길동", documentText: "홍길동"),
            (userInput: "", documentText: "x"),
            (userInput: "a b", documentText: "ab"),
            (userInput: "OMW", documentText: "duplicate"),
        ])
        XCTAssertEqual(result.map(\.trigger), ["omw"])
        XCTAssertEqual(result.first?.replacement, "On my way!")
    }

    /// 사용자 단축어(꺼 둔 것 포함)와 같은 트리거면 텍스트 대치를 넣지 않는다 — 한 노드에 둘이면 자동 확장이 후보 고르기가 된다.
    func test_merge_userTriggerWins_caseInsensitive() {
        var store = ShortcutExpansionStore()
        store.add(ShortcutExpansion(trigger: "Omw", replacement: "mine"))
        var disabled = ShortcutExpansion(trigger: "brb", replacement: "off")
        disabled.isEnabled = false
        store.add(disabled)
        let system = KeyboardViewModel.textReplacementExpansions(from: [
            (userInput: "omw", documentText: "On my way!"),
            (userInput: "brb", documentText: "be right back"),
            (userInput: "ty", documentText: "thank you"),
        ])
        let merged = KeyboardViewModel.mergedExpansionStore(store, systemReplacements: system)
        XCTAssertEqual(merged.expansions.map(\.replacement), ["mine", "off", "thank you"])
    }

    func test_typingReplacementShortcut_expands() {
        makeViewModel()
        viewModel.setSystemTextReplacements([(userInput: "omw", documentText: "On my way!")])
        type("omw")
        XCTAssertEqual(delegate.text, "On my way! ")
    }

    func test_settingOff_doesNotExpand() {
        KeyboardSettings.shared.systemTextReplacementEnabled = false
        makeViewModel()
        viewModel.setSystemTextReplacements([(userInput: "omw", documentText: "On my way!")])
        type("omw")
        XCTAssertEqual(delegate.text, "omw ")
    }
}

private final class TextRecorder: KeyboardViewModelDelegate {
    private(set) var text = ""
    func insertText(_ s: String) { text.append(s) }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func updateComposingText(from previous: String, to current: String) {
        for _ in previous where !text.isEmpty { text.removeLast() }
        text.append(current)
    }
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { text }
}

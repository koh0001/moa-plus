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
    private var savedUndoEnabled: Bool!
    private var savedKeepConfirmSpace: Bool!

    override func setUp() {
        super.setUp()
        // Preserve the real settings so the test machine isn't left dirty.
        savedStore = KeyboardSettings.shared.shortcutExpansionStore
        savedAbbreviationEnabled = KeyboardSettings.shared.abbreviationEnabled
        savedUndoEnabled = KeyboardSettings.shared.abbreviationUndoOnBackspaceEnabled
        savedKeepConfirmSpace = KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled

        KeyboardSettings.shared.abbreviationEnabled = true
        KeyboardSettings.shared.abbreviationUndoOnBackspaceEnabled = true
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = true

        makeViewModel(triggers: [("ㅎㅌ", "♥")])
    }

    override func tearDown() {
        KeyboardSettings.shared.shortcutExpansionStore = savedStore
        KeyboardSettings.shared.abbreviationEnabled = savedAbbreviationEnabled
        KeyboardSettings.shared.abbreviationUndoOnBackspaceEnabled = savedUndoEnabled
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = savedKeepConfirmSpace
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// 지정한 트리거 목록으로 스토어를 갈아끼우고 뷰모델을 새로 만든다.
    /// `KeyboardViewModel` 은 init 에서 스토어를 읽으므로 **설정을 먼저** 넣어야 한다.
    private func makeViewModel(triggers: [(String, String)]) {
        makeViewModel(expansions: triggers.map {
            ShortcutExpansion(trigger: $0.0, replacement: $0.1)
        })
    }

    private func makeViewModel(expansions: [ShortcutExpansion]) {
        var store = ShortcutExpansionStore()
        for expansion in expansions {
            store.add(expansion)
        }
        KeyboardSettings.shared.shortcutExpansionStore = store

        delegate = TextFieldMockDelegate()
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
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

    // MARK: - 제보 재현 (2026-08-16) — 트리거/본문에 기호가 섞인 경우
    //
    // 두 가지 해석을 분리 검증한다.
    //  (a) 본문에 기호를 먼저 치고 그 뒤에 순수 트리거를 입력 → 지금도 동작해야 정상
    //  (b) 트리거 문자열 자체가 구분자(. , ! 공백 …)를 포함 → 현재 구조상 절대 매칭 불가
    // (a)까지 깨진다면 원인이 하나 더 있다는 뜻이다.

    /// (a) 본문 선행 기호 — "." 를 먼저 입력한 뒤 트리거 `ㅎㅌ` + space.
    func testExpansion_afterLeadingSymbolInText_stillExpands() {
        viewModel.inputSymbol(".")
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, ".♥ ",
                       "본문 앞의 기호는 트리거 매칭에 영향을 주면 안 된다")
    }

    /// (b) 기호를 포함한 트리거 — `.ㅎㅌ` 를 등록하고 `. ㅎ ㅌ` + space.
    /// 제보 1·2의 핵심 요구사항.
    func testExpansion_triggerWithLeadingSymbol_expands() {
        makeViewModel(triggers: [(".ㅎㅌ", "♥")])

        viewModel.inputSymbol(".")
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "♥ ", "기호를 포함한 트리거도 확장되어야 한다")
    }

    /// 앞말에 붙여 쓴 기호 트리거 — `ㄱㄴ.ㅎㅌ` + space → `ㄱㄴ♥ `.
    ///
    /// 접미 매칭이 걸리는 경로이자, 삭제 산술의 최대 위험 지점이다. 지울 길이를 버퍼
    /// 길이로 잡으면 앞 글자 `ㄱㄴ` 까지 먹는다. 더 긴 트리거를 함께 등록해 버퍼가
    /// 트리거보다 길게 유지되도록(= 정확 매칭이 실패하도록) 만든 뒤 검증한다.
    func testExpansion_symbolTriggerAfterPrecedingText_deletesOnlyTrigger() {
        makeViewModel(triggers: [(".ㅎㅌ", "♥"), ("ㄱㄴㄷㄹㅁ", "X")])

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputConsonant(.ㄴ)
        viewModel.inputSymbol(".")
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "ㄱㄴ♥ ",
                       "트리거 길이만 지워야 한다 — 앞 글자를 먹으면 안 됨")
    }

    /// 기호로 끝나는 트리거 — `ㅏ..` 는 다 쳐도 확장되지 않고, 이어지는 스페이스에서 확장된다.
    func testExpansion_triggerEndingWithSymbol_waitsForSpace() {
        makeViewModel(triggers: [("ㅏ..", "Aㅏ....")])

        viewModel.inputVowel(.ㅏ)
        viewModel.inputSymbol(".")
        viewModel.inputSymbol(".")
        XCTAssertEqual(delegate.text, "ㅏ..",
                       "트리거를 다 쳐도 그 순간에는 확장하지 않는다")

        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "Aㅏ.... ", "스페이스에서 확장된다")
    }

    /// 기호도 여전히 **확정 구분자**다 — `ㅏ..` 를 친 뒤 마침표를 하나 더 찍으면 그 마침표가
    /// 확정 신호가 되어 확장된다. `ㅏ...` 를 리터럴로 남기려면 백스페이스로 되돌려야 한다.
    /// (기호 확정을 없애면 `ㄱㅅ.` 로 확정하던 기존 사용자가 깨지므로 유지하는 쪽을 택했다.)
    func testExpansion_triggerEndingWithSymbol_alsoConfirmsOnFurtherSymbol() {
        makeViewModel(triggers: [("ㅏ..", "Aㅏ....")])

        viewModel.inputVowel(.ㅏ)
        viewModel.inputSymbol(".")
        viewModel.inputSymbol(".")
        viewModel.inputSymbol(".")

        XCTAssertEqual(delegate.text, "Aㅏ.....",
                       "세 번째 마침표가 확정 신호로 동작한다")
    }

    // MARK: - 확정 스페이스 유지 / 제거

    /// 끄면 확정용 스페이스가 결과 뒤에 남지 않는다.
    func testExpansion_whenConfirmSpaceDropped_leavesNoTrailingSpace() {
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = false
        makeViewModel(triggers: [("ㅎㅌ", "♥")])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "♥", "확정 스페이스를 남기지 않는다")
    }

    /// 스페이스를 제거해도 되돌리기 삭제 개수가 맞아야 한다.
    /// 구분자를 안 넣었는데 넣은 것으로 계산하면 앞 글자를 한 자 더 먹는다.
    func testBackspace_afterExpansionWithoutConfirmSpace_restoresTrigger() {
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = false
        makeViewModel(triggers: [("ㅎㅌ", "♥")])

        viewModel.inputConsonant(.ㄱ)   // 앞에 남아 있어야 할 글자
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "ㄱ♥", "precondition: 앞 글자 + 치환 결과")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "ㄱㅎㅌ",
                       "되돌리기는 치환 결과만 지우고 앞 글자를 건드리면 안 된다")
    }

    /// 기호로 확정할 때는 이 설정과 무관하게 기호가 유지된다.
    /// 마침표는 확정 신호이기 이전에 사용자가 의도한 문장부호다.
    func testExpansion_whenConfirmSpaceDropped_stillKeepsPunctuation() {
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = false
        makeViewModel(triggers: [("ㄱㅅ", "감사합니다")])

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputConsonant(.ㅅ)
        viewModel.inputSymbol(".")

        XCTAssertEqual(delegate.text, "감사합니다.", "마침표는 그대로 남는다")
    }

    /// 엔터로 확정하는 경로. 스페이스와 달리 개행은 이 설정과 무관하게 항상 유지된다.
    func testExpansion_confirmedByReturn_keepsNewline() {
        makeViewModel(triggers: [("ㅎㅌ", "♥")])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputReturn()

        XCTAssertEqual(delegate.text, "♥\n", "엔터 확정은 개행을 남긴다")
    }

    func testExpansion_confirmedByReturn_keepsNewlineEvenWhenSpaceDropped() {
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = false
        makeViewModel(triggers: [("ㅎㅌ", "♥")])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputReturn()

        XCTAssertEqual(delegate.text, "♥\n",
                       "개행은 줄바꿈/전송이라 스페이스 설정과 무관하게 유지한다")
    }

    // MARK: - 후보 선택(.suggestion) 커밋 모드
    //
    // `pendingTrigger` / `pendingDelimiter` 는 오직 이 경로에서만 쓰인다.

    func testSuggestionMode_showsCandidateThenConfirms() {
        makeViewModel(expansions: [
            ShortcutExpansion(trigger: "ㅎㅌ", replacement: "♥", commitMode: .suggestion)
        ])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertTrue(viewModel.isAbbreviationCandidateVisible, "후보 바가 떠야 한다")
        XCTAssertEqual(delegate.text, "ㅎㅌ ",
                       "확정 전에는 치환하지 않고 사용자가 누른 스페이스만 들어간다")

        viewModel.confirmAbbreviation()

        XCTAssertEqual(delegate.text, "♥ ", "후보를 확정하면 치환된다")
        XCTAssertFalse(viewModel.isAbbreviationCandidateVisible)
    }

    /// 후보를 `.` 로 띄웠으면 확정 후에도 공백이 아니라 **마침표**가 붙어야 한다.
    /// (구 구현은 확정 구분자를 공백으로 하드코딩했다.)
    func testSuggestionMode_confirmedAfterSymbol_restoresThatSymbol() {
        makeViewModel(expansions: [
            ShortcutExpansion(trigger: "ㅎㅌ", replacement: "♥", commitMode: .suggestion)
        ])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSymbol(".")
        XCTAssertTrue(viewModel.isAbbreviationCandidateVisible)

        viewModel.confirmAbbreviation()

        XCTAssertEqual(delegate.text, "♥.", "띄운 구분자를 그대로 되붙인다")
    }

    func testSuggestionMode_withConfirmSpaceDropped_leavesNoTrailingSpace() {
        KeyboardSettings.shared.abbreviationKeepConfirmSpaceEnabled = false
        makeViewModel(expansions: [
            ShortcutExpansion(trigger: "ㅎㅌ", replacement: "♥", commitMode: .suggestion)
        ])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()
        viewModel.confirmAbbreviation()

        XCTAssertEqual(delegate.text, "♥", "후보 확정에서도 확정 스페이스를 남기지 않는다")
    }

    // MARK: - 기호(`.`)로 확정할 때의 삭제 산술
    //
    // 스페이스 확정과 경로가 다르다. `inputSymbol()` 은 기호를 화면에 **먼저** 넣고
    // 엔진을 호출하므로, 확정 구분자가 화면에 남은 채로 `shouldReplace` 가 시작된다.
    // 그래서 pre-strip 분기(`KeyboardViewModel:1423`)를 타는 유일한 경로다 —
    // 스페이스 확정만 테스트하면 이 분기는 커버리지 0으로 남는다.

    /// 평범한 트리거를 `.` 로 확정 — 이미 화면에 들어간 `.` 를 한 번 걷어내고 치환해야 한다.
    func testExpansion_plainTrigger_confirmedBySymbol() {
        makeViewModel(triggers: [("ㄱㅅ", "감사합니다")])

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputConsonant(.ㅅ)
        viewModel.inputSymbol(".")

        XCTAssertEqual(delegate.text, "감사합니다.",
                       "이미 삽입된 마침표를 걷어내고 치환 + 마침표를 다시 붙인다")
    }

    /// 기호 트리거를 `.` 로 확정 — 화면이 `.ㅎㅌ.` 인 상태로 진입한다.
    /// `hasSuffix(trigger)` 는 false 이고 `hasSuffix(trigger + delimiter)` 만 true 인
    /// 유일한 경로라, 확장 포기 가드의 두 번째 조건이 여기서 검증된다.
    func testExpansion_symbolTrigger_confirmedBySymbol() {
        makeViewModel(triggers: [(".ㅎㅌ", "♥")])

        viewModel.inputSymbol(".")
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSymbol(".")

        XCTAssertEqual(delegate.text, "♥.",
                       "기호 트리거를 기호로 확정해도 포기하지 않고 정확히 치환한다")
    }

    /// 경계 가드 — 기호가 없는 평범한 트리거는 어절 중간에서 발동하면 안 된다.
    /// 접미 매칭을 기호 트리거로 한정하지 않으면 여기서 전체 회귀가 난다.
    func testExpansion_plainTrigger_doesNotFireMidWord() {
        makeViewModel(triggers: [("ㅎㅌ", "♥"), ("ㄱㄴㄷㄹㅁ", "X")])

        viewModel.inputConsonant(.ㄱ)
        viewModel.inputConsonant(.ㄴ)
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "ㄱㄴㅎㅌ ",
                       "평범한 트리거는 어절 중간에서 발동하지 않는다")
    }

    /// 트리거가 최장 길이를 넘겨도 동작해야 한다 — 버퍼 상한을 상수로 고정하면
    /// 긴 트리거가 조용히 멈춘다.
    func testExpansion_longTrigger_isNotTruncatedByBufferCap() {
        makeViewModel(triggers: [("ㄱㄴㄷㄹㅁㅂ", "긴단축어")])

        for consonant in [Choseong.ㄱ, .ㄴ, .ㄷ, .ㄹ, .ㅁ, .ㅂ] {
            viewModel.inputConsonant(consonant)
        }
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "긴단축어 ", "6자 트리거도 확장되어야 한다")
    }

    /// 되돌리기를 끄면 백스페이스는 일반 삭제로 동작한다.
    func testBackspace_whenUndoDisabled_doesNotRestoreTrigger() {
        KeyboardSettings.shared.abbreviationUndoOnBackspaceEnabled = false
        makeViewModel(triggers: [("ㅎㅌ", "♥")])

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()
        XCTAssertEqual(delegate.text, "♥ ", "precondition: 확장은 그대로 일어난다")

        viewModel.deleteBackward()
        XCTAssertEqual(delegate.text, "♥",
                       "되돌리기 OFF 면 뒤 공백만 지워지고 트리거로 되돌아가지 않는다")
    }

    /// 1글자 트리거가 현재 확장되는지 — 최소 길이 제한 도입 전 현행 동작 확인.
    func testExpansion_singleCharacterTrigger_currentBehavior() {
        makeViewModel(triggers: [("ㅋ", "크크크")])

        viewModel.inputConsonant(.ㅋ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "크크크 ",
                       "현행: 1글자 트리거도 스페이스로 확장된다")
    }

    /// (b') 공백을 포함한 트리거 — **의도적 미지원**.
    ///
    /// 스페이스는 확정 신호이므로 트리거 내용으로 겸용하면 짧은/긴 트리거 충돌,
    /// 더블스페이스→마침표 충돌, 삭제 개수 불일치가 한꺼번에 들어온다. 오입력 위험 대비
    /// 이득이 없어(같은 효과를 `ㅋㅋ` 처럼 공백 없는 트리거로 낼 수 있다) 공백 포함 트리거는
    /// 등록 단계에서 막기로 했다. 이 테스트는 "확장되지 않음" 을 고정한다.
    func testExpansion_triggerContainingSpace_isNotSupported() {
        makeViewModel(triggers: [("ㅋ ㅋ", "ㅋㅋㅋㅋㅋ")])

        viewModel.inputConsonant(.ㅋ)
        viewModel.inputSpace()
        viewModel.inputConsonant(.ㅋ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "ㅋ ㅋ ",
                       "공백 포함 트리거는 확장하지 않는다 (설계 결정)")
    }
}

// MARK: - 트리거 등록 검증 정책

/// `AbbreviationTriggerPolicy` 는 등록 UI 전용이라 키보드 동작 테스트로는 안 잡힌다.
/// 실기기에서 `ㅏ..` (제보자가 요청한 바로 그 예시) 가 기본 정책에 막히는 문제가
/// 나왔으므로 규칙을 여기에 고정한다.
final class AbbreviationTriggerPolicyTests: XCTestCase {
    func testSafePolicy_allowsOrdinaryTriggers() {
        let safe = AbbreviationTriggerPolicy.safe
        XCTAssertNil(safe.validationMessage(for: "ㅎㅌ"))
        XCTAssertNil(safe.validationMessage(for: "ㄱㅅ"))
    }

    /// 기호로 **끝나는** 트리거는 앞부분이 먼저 일치해야 하므로 위험하지 않다.
    func testSafePolicy_allowsTriggerEndingWithSymbols() {
        XCTAssertNil(AbbreviationTriggerPolicy.safe.validationMessage(for: "ㅏ.."),
                     "제보자 예시 `ㅏ..` 는 기본 정책에서 등록 가능해야 한다")
    }

    /// 기호로 **시작하는** 트리거는 문장 중간 어디서든 발동하므로 실질 2자를 요구한다.
    func testSafePolicy_symbolLeadingTrigger_requiresTwoSubstantiveChars() {
        let safe = AbbreviationTriggerPolicy.safe
        XCTAssertNil(safe.validationMessage(for: ".ㄱㅅ"))
        XCTAssertNotNil(safe.validationMessage(for: ".ㄱ"),
                        "`.ㄱ` 는 마침표로 끝나는 아무 문장 뒤에서 터진다")
    }

    func testSafePolicy_rejectsSingleCharacter() {
        XCTAssertNotNil(AbbreviationTriggerPolicy.safe.validationMessage(for: "ㅋ"))
    }

    func testFreePolicy_allowsShortTriggers() {
        let free = AbbreviationTriggerPolicy.free
        XCTAssertNil(free.validationMessage(for: "ㅋ"))
        XCTAssertNil(free.validationMessage(for: ".ㄱ"))
    }

    /// 공백은 구조적 사유라 정책과 무관하게 항상 막는다.
    func testBothPolicies_rejectWhitespace() {
        for policy in AbbreviationTriggerPolicy.allCases {
            XCTAssertNotNil(policy.validationMessage(for: "ㅋ ㅋ"),
                            "\(policy) 에서도 공백 트리거는 막아야 한다")
            XCTAssertNotNil(policy.validationMessage(for: ""))
        }
    }
}

// MARK: - 화면/버퍼 불일치 방어

/// 엔진 버퍼와 호스트 화면이 어긋난 상황에서 확장을 **포기**하는지 검증한다.
///
/// `processBackspace()` 가 버퍼를 한 글자 줄이는 사이 조합기는 조합 글자를 지우는 식으로
/// 둘이 어긋날 수 있다. 그 상태에서 `trigger.count` 만큼 맹목적으로 지우면 사용자가 친
/// 글자를 먹는다. 여기서는 호스트 컨텍스트가 트리거로 끝나지 않는 상황을 직접 만들어,
/// (1) 아무것도 지우지 않고 (2) 사용자가 누른 스페이스도 삼키지 않는지 본다.
final class KeyboardViewModelAbbreviationDesyncTests: XCTestCase {
    private var savedStore: ShortcutExpansionStore!
    private var savedEnabled: Bool!

    override func setUp() {
        super.setUp()
        savedStore = KeyboardSettings.shared.shortcutExpansionStore
        savedEnabled = KeyboardSettings.shared.abbreviationEnabled

        var store = ShortcutExpansionStore()
        store.add(ShortcutExpansion(trigger: "ㅎㅌ", replacement: "♥"))
        KeyboardSettings.shared.shortcutExpansionStore = store
        KeyboardSettings.shared.abbreviationEnabled = true
    }

    override func tearDown() {
        KeyboardSettings.shared.shortcutExpansionStore = savedStore
        KeyboardSettings.shared.abbreviationEnabled = savedEnabled
        super.tearDown()
    }

    /// 대조군 — 컨텍스트가 정직하면 같은 입력이 확장된다. 아래 테스트가 "가드 때문에"
    /// 통과하는지, 애초에 매칭이 안 돼서 통과하는지 구분해 준다.
    func testExpansion_withHonestContext_expandsNormally() {
        let delegate = StaleContextDelegate()
        let viewModel = KeyboardViewModel()
        viewModel.delegate = delegate

        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)
        viewModel.inputSpace()

        XCTAssertEqual(delegate.text, "♥ ", "precondition: 정직한 컨텍스트에서는 확장된다")
    }

    func testExpansion_abortsWhenHostContextDoesNotEndWithTrigger() {
        let delegate = StaleContextDelegate()
        let viewModel = KeyboardViewModel()
        viewModel.delegate = delegate

        // 조합 중에는 정직하게 보고해야 `freezeComposerIfCaretMoved` 가 조합기를
        // 리셋하지 않는다. 리셋되면 매칭 자체가 일어나지 않아 가드를 검증하지 못한다.
        viewModel.inputConsonant(.ㅎ)
        viewModel.inputConsonant(.ㅌ)

        // 조합 텍스트 시뮬레이션(delete+insert)도 deleteBackward 를 쓰므로,
        // 확정 시점 기준으로 **추가** 삭제가 있었는지만 본다.
        let deletesBeforeConfirm = delegate.deleteCount

        // 확정 직전에만 어긋난 화면을 보고한다.
        delegate.reportsStaleContext = true
        viewModel.inputSpace()

        XCTAssertEqual(delegate.deleteCount, deletesBeforeConfirm,
                       "화면이 트리거로 끝나지 않으면 한 글자도 지우면 안 된다")
        XCTAssertEqual(delegate.text, "ㅎㅌ ",
                       "확장을 포기했으면 사용자가 누른 스페이스는 그대로 들어가야 한다")
    }
}

/// 요청 시점에 화면과 어긋난 컨텍스트를 보고하는 델리게이트.
private final class StaleContextDelegate: KeyboardViewModelDelegate {
    private(set) var text: String = ""
    private(set) var deleteCount: Int = 0
    var reportsStaleContext = false

    func insertText(_ string: String) { text.append(string) }

    func deleteBackward() {
        deleteCount += 1
        if !text.isEmpty { text.removeLast() }
    }

    func updateComposingText(from previous: String, to current: String) {
        for _ in previous where !text.isEmpty { text.removeLast() }
        text.append(current)
    }

    func switchToNextKeyboard() {}
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}

    func textBeforeCursor() -> String? { reportsStaleContext ? "전혀다른내용" : text }
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

    /// Reporting the host context is what makes `shouldReplace` 의 두 안전장치
    /// (pre-strip + 2차 삭제 가드) 를 테스트에서 살아있게 한다. 이 메서드가 없으면
    /// 두 분기가 통째로 죽어 삭제 산술이 검증되지 않는다.
    func textBeforeCursor() -> String? { text }
}

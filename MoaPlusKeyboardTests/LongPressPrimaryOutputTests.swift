import XCTest

/// 이슈 #37 — 롱키를 그대로 떼면 들어가는 글자 = 설정의 **롱프레스 출력**.
///
/// - `SecondaryKeyAction.effectivePrimary` / `effectiveCandidates` 가 후보의 유일한 출처다
///   (뷰모델·팝업 오버레이·키 힌트·설정 화면이 모두 이것을 쓴다).
/// - 그리드 트리거는 `KeyGridView.longPressBinding` — `ConsonantGridView` 가 부르는 바로 그 함수.
/// - 기존 사용자 일회성 이전: 팝업 후보 순서를 바꿔 결과를 고른 사용자는 결과가 유지되고,
///   출력만 고치고 힌트는 기본값 그대로인 사용자(제보자 상태)는 힌트가 새 출력을 따라간다.
final class LongPressPrimaryOutputTests: XCTestCase {
    private var pin: LongPressSettingsPin!

    override func setUp() {
        super.setUp()
        pin = LongPressSettingsPin()
    }

    override func tearDown() {
        pin.restore()
        pin = nil
        super.tearDown()
    }

    private func defaultAction(_ keyId: String) -> SecondaryKeyAction {
        SecondaryKeyAction.action(forKey: keyId)!
    }

    // MARK: - effectivePrimary / effectiveCandidates

    func test_defaults_primaryIsFirstPopupOutput_andCandidatesUnchanged() {
        // 기본 매핑 29개는 출력 == 첫 후보이고 중복이 없다 → 고친 뒤에도 기본 사용자에게 보이는 게 같다.
        // 힌트 == 출력도 지킨다 — 일회성 이전이 "힌트가 기본값 = 손대지 않음" 으로 판정하고, 다시
        // 적용해도 무변화인 근거가 이것이다.
        for action in SecondaryKeyAction.defaults {
            XCTAssertEqual(action.effectivePrimary, action.popupOutputs.first, action.keyId)
            XCTAssertEqual(action.visibleHint, action.primaryLongPressOutput, action.keyId)
            XCTAssertEqual(action.effectiveCandidates(filteringClosingBrackets: false), action.popupOutputs, action.keyId)
        }
    }

    func test_effectivePrimary_trimsAndFallsBackToFirstNonEmptyPopupOutput() {
        var a = defaultAction("ㅈ")
        a.primaryLongPressOutput = "  @\n"
        XCTAssertEqual(a.effectivePrimary, "@")
        a.primaryLongPressOutput = "   "
        a.popupOutputs = ["", "  ", " & ", "7"]
        XCTAssertEqual(a.effectivePrimary, "&")
        a.popupOutputs = [" "]
        XCTAssertEqual(a.effectivePrimary, "")
        XCTAssertEqual(a.effectiveCandidates(filteringClosingBrackets: false), [], "맨 앞 글자가 없으면 빈 후보 — [\"\"] 가 아니다")
    }

    func test_effectiveCandidates_primaryFirst_trimmed_allDuplicatesRemoved_orderKept() {
        var a = defaultAction("ㅈ")
        a.primaryLongPressOutput = "&"
        a.popupOutputs = ["7", " & ", "#", "7", "", "#", "%"]
        XCTAssertEqual(a.effectiveCandidates(filteringClosingBrackets: false), ["&", "7", "#", "%"])
    }

    func test_effectiveCandidates_closerFilter_neverRemovesPrimary() {
        var a = defaultAction("ㄱ")   // 9 ( )
        XCTAssertEqual(a.effectiveCandidates(filteringClosingBrackets: true), ["9", "("])
        a.primaryLongPressOutput = ")"
        XCTAssertEqual(a.effectiveCandidates(filteringClosingBrackets: true), [")", "9", "("])
        a.popupOutputs = ["]", "}", ">", "」"]
        XCTAssertEqual(a.effectiveCandidates(filteringClosingBrackets: true), [")"])
        XCTAssertEqual(a.effectiveCandidates(filteringClosingBrackets: false), [")", "]", "}", ">", "」"])
    }

    func test_filtersClosingBrackets_onlyInLetterModesWithAutoBracket() {
        XCTAssertTrue(SecondaryKeyAction.filtersClosingBrackets(autoBracketEnabled: true, mode: .korean))
        XCTAssertTrue(SecondaryKeyAction.filtersClosingBrackets(autoBracketEnabled: true, mode: .english))
        XCTAssertFalse(SecondaryKeyAction.filtersClosingBrackets(autoBracketEnabled: true, mode: .symbolFromKorean))
        XCTAssertFalse(SecondaryKeyAction.filtersClosingBrackets(autoBracketEnabled: true, mode: .symbolFromEnglish))
        XCTAssertFalse(SecondaryKeyAction.filtersClosingBrackets(autoBracketEnabled: false, mode: .korean))
    }

    func test_overlayCandidates_renderedAsGiven_fallBackToTextOnlyWhenEmpty() {
        XCTAssertEqual(KeyboardView.popupDisplayCandidates(candidates: [")", "]"], text: ")"), [")", "]"],
                       "오버레이는 다시 거르지 않는다")
        XCTAssertEqual(KeyboardView.popupDisplayCandidates(candidates: [], text: "Q"), ["Q"])
        XCTAssertEqual(KeyboardView.popupDisplayCandidates(candidates: [], text: nil), [])
    }

    // MARK: - 설정 화면 편집 (EditSecondaryKeyView 저장)

    func test_applyingEdit_trimsValues_andHintFollowsUncustomisedPrimary() {
        let edited = defaultAction("ㅈ").applyingEdit(visibleHint: "7", primaryOutput: " @ ", popupText: " 7  &\t# ")
        XCTAssertEqual(edited.primaryLongPressOutput, "@")
        XCTAssertEqual(edited.popupOutputs, ["7", "&", "#"])
        XCTAssertEqual(edited.visibleHint, "@", "힌트를 손대지 않았으면(= 예전 출력) 새 출력을 따라간다")
        XCTAssertEqual(edited.keyId, "ㅈ")
    }

    func test_applyingEdit_keepsCustomisedHint() {
        let edited = defaultAction("ㅈ").applyingEdit(visibleHint: "★", primaryOutput: "@", popupText: "7 &")
        XCTAssertEqual(edited.visibleHint, "★")
        XCTAssertEqual(edited.primaryLongPressOutput, "@")
    }

    // MARK: - 그리드 트리거 (KeyGridView.longPressBinding — ConsonantGridView 가 부르는 함수)

    private func binding(_ content: KeyContent?, row: Int, column: Int, mode: KeyboardMode = .korean,
                         layout: LayoutCustomization = LayoutCustomization(),
                         uppercase: Bool = true,
                         actions: [SecondaryKeyAction] = SecondaryKeyAction.defaults) -> KeyGridView.LongPressBinding {
        KeyGridView.longPressBinding(
            content: content, row: row, column: column, mode: mode, layout: layout,
            englishLongPressUppercase: uppercase,
            storedAction: { SecondaryKeyAction.action(forKey: $0, from: actions) })
    }

    private func editedActions(_ keyId: String, primary: String, popup: [String]? = nil) -> [SecondaryKeyAction] {
        SecondaryKeyAction.defaults.map {
            guard $0.keyId == keyId else { return $0 }
            var e = $0
            e.primaryLongPressOutput = primary
            if let popup { e.popupOutputs = popup }
            return e
        }
    }

    func test_gridTrigger_korean_prefersStoredPrimaryOverLayoutTable() {
        // 수정 전(고정표만 읽음)에는 "7" 이었다 — ConsonantGridView 의 변경을 되돌리면 이 테스트가 깨진다.
        let b = binding(.consonant(.ㅈ), row: 1, column: 2, actions: editedActions("ㅈ", primary: "@"))
        XCTAssertEqual(b.trigger, "@")
        XCTAssertEqual(b.action?.effectivePrimary, "@")
    }

    func test_gridTrigger_korean_defaultMatchesLayoutTable() {
        let layout = LayoutCustomization()
        let grid = KeyboardMetrics.activeLayout(for: .korean, layout: layout)
        for (row, cells) in grid.enumerated() {
            for (column, content) in cells.enumerated() {
                guard case .consonant = content else { continue }
                XCTAssertEqual(binding(content, row: row, column: column).trigger,
                               KeyboardMetrics.longPressNumber(at: row, column: column, layout: layout),
                               "기본 매핑에서는 트리거가 예전 고정표와 같다 (\(row),\(column))")
            }
        }
    }

    func test_gridTrigger_korean_fallsBackToTableWhenNoUsableStoredPrimary() {
        XCTAssertEqual(binding(.consonant(.ㅈ), row: 1, column: 2, actions: []).trigger, "7", "저장된 매핑이 없으면 고정표")
        let empty = editedActions("ㅈ", primary: " ", popup: [])
        let b = binding(.consonant(.ㅈ), row: 1, column: 2, actions: empty)
        XCTAssertEqual(b.trigger, "7", "출력·후보가 모두 비면 고정표")
        XCTAssertEqual(binding(.consonant(.ㅈ), row: 1, column: 2,
                               actions: editedActions("ㅈ", primary: " ")).trigger, "7",
                       "공백뿐인 출력은 첫 후보(7)")
    }

    func test_gridTrigger_korean_gatedByLayoutTable() {
        // 고정표가 nil 인 자리는 저장된 액션이 있어도 롱키가 없다 (고정표 = 문).
        let b = binding(.consonant(.ㅈ), row: 3, column: 5, actions: editedActions("ㅈ", primary: "@"))
        XCTAssertNil(b.trigger)
        XCTAssertNil(b.action, "롱키가 없는 자리는 힌트도 없다")
        var classic = LayoutCustomization()
        classic.slotA = .classic11
        XCTAssertNil(binding(.consonant(.ㅈ), row: 1, column: 6, layout: classic).trigger,
                     "classic11 의 col 6 은 고정표가 nil")
    }

    func test_gridTrigger_korean_onlyConsonantKeys_symbolCellShowsNoHint() {
        // slotC 칸을 "7"·"ㄱ" 로 바꾼 경우 — 글자가 저장된 keyId 와 같아도 한글 모드 심볼 칸은 롱키 없음.
        for text in ["7", "ㄱ"] {
            let b = binding(.symbol(text), row: 1, column: 1)
            XCTAssertNil(b.trigger, text)
            XCTAssertNil(b.action, "\(text): 롱키가 없는 칸에 다른 키의 힌트를 그리면 안 된다")
        }
        XCTAssertNil(binding(.symbol("~"), row: 0, column: 0).trigger)
        XCTAssertNil(binding(.backspace, row: 1, column: 6).trigger)
    }

    func test_gridTrigger_englishDigit_usesStoredPrimary() {
        let b = binding(.symbol("1"), row: 0, column: 0, mode: .english, actions: editedActions("1", primary: " ? "))
        XCTAssertEqual(b.trigger, "?")
        XCTAssertEqual(b.action?.keyId, "1")
        XCTAssertEqual(binding(.symbol("0"), row: 0, column: 9, mode: .english).trigger, ")")
        XCTAssertNil(binding(.symbol("1"), row: 0, column: 0, mode: .english, actions: []).trigger,
                     "매핑 없는 숫자 키는 롱키 없음")
        XCTAssertNil(binding(.symbol("1"), row: 0, column: 0, mode: .english,
                             actions: editedActions("1", primary: "", popup: [])).trigger,
                     "빈 출력으로 롱프레스가 걸리면 안 된다")
    }

    func test_gridTrigger_englishLetter_uppercaseSetting() {
        let on = binding(.symbol("q"), row: 1, column: 0, mode: .english, uppercase: true)
        XCTAssertEqual(on.trigger, "Q")
        XCTAssertNil(on.action)
        XCTAssertNil(binding(.symbol("q"), row: 1, column: 0, mode: .english, uppercase: false).trigger)
    }

    func test_gridTrigger_symbolMode_usesAlternateTable() {
        let b = binding(.symbol("("), row: 3, column: 0, mode: .symbolFromKorean)
        XCTAssertEqual(b.trigger, "[")
        XCTAssertEqual(b.action?.effectiveCandidates(filteringClosingBrackets: false), ["[", "{", "<"])
        XCTAssertNil(binding(.symbol("1"), row: 0, column: 0, mode: .symbolFromKorean).trigger,
                     "심볼 모드는 저장된 영문 숫자 매핑을 쓰지 않는다")
    }

    // MARK: - 일회성 이전 (popupOutputs[0] 이 들어가던 시절의 결과 유지)

    /// ㅈ 의 출력은 기본값 7 그대로 두고 후보 순서만 바꿔 & 를 받던 사용자.
    private var reorderedJieut: [SecondaryKeyAction] {
        SecondaryKeyAction.defaults.map {
            guard $0.keyId == "ㅈ" else { return $0 }
            var e = $0
            e.popupOutputs = ["&", "7"]
            return e
        }
    }

    func test_migration_static_reorderedUserKeepsResult_hintFollows() {
        let migrated = SecondaryKeyAction.migratingForPrimaryOutput(reorderedJieut)
        let jieut = SecondaryKeyAction.action(forKey: "ㅈ", from: migrated)!
        XCTAssertEqual(jieut.primaryLongPressOutput, "&")
        XCTAssertEqual(jieut.visibleHint, "&", "힌트가 예전 출력과 같았으면 따라간다")
        XCTAssertEqual(jieut.effectiveCandidates(filteringClosingBrackets: true), ["&", "7"])
        XCTAssertEqual(migrated.filter { $0.keyId != "ㅈ" }, SecondaryKeyAction.defaults.filter { $0.keyId != "ㅈ" })
    }

    func test_migration_static_customHintKept() {
        var actions = reorderedJieut
        actions[actions.firstIndex(where: { $0.keyId == "ㅈ" })!].visibleHint = "★"
        let jieut = SecondaryKeyAction.action(
            forKey: "ㅈ", from: SecondaryKeyAction.migratingForPrimaryOutput(actions))!
        XCTAssertEqual(jieut.primaryLongPressOutput, "&")
        XCTAssertEqual(jieut.visibleHint, "★")
    }

    func test_migration_static_defaultsAndUnknownKeysUntouched() {
        XCTAssertEqual(SecondaryKeyAction.migratingForPrimaryOutput(SecondaryKeyAction.defaults),
                       SecondaryKeyAction.defaults)
        // 저장소에 없는 keyId 는 대상이 아니다.
        let unknown = [SecondaryKeyAction(keyId: "★", visibleHint: "x", primaryLongPressOutput: "x", popupOutputs: ["y"])]
        XCTAssertEqual(SecondaryKeyAction.migratingForPrimaryOutput(unknown), unknown)
    }

    /// 이슈 #37 제보자 상태: ㅈ 의 출력만 @ 로 고치고 힌트·후보는 기본값(7 / 7 &).
    /// 수정 전 편집 화면은 힌트를 따라 바꾸지 않았고, 이제 떼면 @ 가 들어가므로 키에 7 이 남는다.
    /// 편집 화면을 다시 저장해도(`applyingEdit` 은 지금 저장된 출력 @ 와 비교) 고쳐지지 않으므로
    /// 이전에서 힌트를 맞춘다.
    private var reporterJieut: [SecondaryKeyAction] {
        SecondaryKeyAction.defaults.map {
            guard $0.keyId == "ㅈ" else { return $0 }
            var e = $0
            e.primaryLongPressOutput = "@"
            return e
        }
    }

    func test_migration_static_editedPrimaryWithDefaultHint_hintFollowsPrimary() {
        let migrated = SecondaryKeyAction.migratingForPrimaryOutput(reporterJieut)
        let jieut = SecondaryKeyAction.action(forKey: "ㅈ", from: migrated)!
        XCTAssertEqual(jieut.visibleHint, "@", "손대지 않은(기본값) 힌트는 새 출력을 따라간다")
        XCTAssertEqual(jieut.primaryLongPressOutput, "@", "고친 출력은 그대로")
        XCTAssertEqual(jieut.popupOutputs, ["7", "&"], "후보도 그대로")
        XCTAssertEqual(migrated.filter { $0.keyId != "ㅈ" }, SecondaryKeyAction.defaults.filter { $0.keyId != "ㅈ" })

        // 이전 뒤 편집 화면을 그대로 저장해도 힌트가 유지된다 (예전에는 7 이 그대로 남았다).
        let resaved = jieut.applyingEdit(visibleHint: jieut.visibleHint, primaryOutput: jieut.primaryLongPressOutput,
                                         popupText: jieut.popupOutputs.joined(separator: " "))
        XCTAssertEqual(resaved.visibleHint, "@")
    }

    func test_migration_static_editedPrimaryAndPopupReordered_hintFollowsPrimary() {
        // 출력 @ · 후보 & 7 · 힌트 기본값 7 → 출력·후보는 그대로, 힌트만 @.
        var actions = reorderedJieut
        actions[actions.firstIndex(where: { $0.keyId == "ㅈ" })!].primaryLongPressOutput = "@"
        let jieut = SecondaryKeyAction.action(forKey: "ㅈ", from: SecondaryKeyAction.migratingForPrimaryOutput(actions))!
        XCTAssertEqual(jieut.primaryLongPressOutput, "@")
        XCTAssertEqual(jieut.popupOutputs, ["&", "7"])
        XCTAssertEqual(jieut.visibleHint, "@")
    }

    func test_migration_static_editedPrimaryWithCustomHint_untouched() {
        var actions = reporterJieut
        actions[actions.firstIndex(where: { $0.keyId == "ㅈ" })!].visibleHint = "★"
        XCTAssertEqual(SecondaryKeyAction.migratingForPrimaryOutput(actions), actions,
                       "힌트를 직접 고친 항목은 출력을 고쳤어도 그대로")
    }

    func test_migration_static_editedPrimary_hintTrimmed() {
        // 앞뒤 공백이 붙은 출력은 공백을 걷은 값을 힌트로 쓴다(떼면 들어가는 글자 = effectivePrimary).
        var actions = reporterJieut
        actions[actions.firstIndex(where: { $0.keyId == "ㅈ" })!].primaryLongPressOutput = " @ "
        let jieut = SecondaryKeyAction.action(forKey: "ㅈ", from: SecondaryKeyAction.migratingForPrimaryOutput(actions))!
        XCTAssertEqual(jieut.visibleHint, "@")
        XCTAssertEqual(jieut.primaryLongPressOutput, " @ ", "출력 자체는 이전이 건드리지 않는다")
    }

    func test_migration_static_blankPrimary_hintFollowsFirstPopupOrStays() {
        // 공백뿐인 출력은 예전 편집 화면이 저장을 막지 않았다. 떼면 들어가는 글자는 첫 후보다.
        func jieut(primary: String, popup: [String]) -> SecondaryKeyAction {
            let actions = SecondaryKeyAction.defaults.map { a -> SecondaryKeyAction in
                guard a.keyId == "ㅈ" else { return a }
                var e = a
                e.primaryLongPressOutput = primary
                e.popupOutputs = popup
                return e
            }
            return SecondaryKeyAction.action(forKey: "ㅈ", from: SecondaryKeyAction.migratingForPrimaryOutput(actions))!
        }
        let reordered = jieut(primary: "  ", popup: ["&", "7"])
        XCTAssertEqual(reordered.visibleHint, "&", "힌트가 빈 글자가 되지 않고 들어가는 글자(첫 후보)를 따라간다")
        XCTAssertEqual(reordered.primaryLongPressOutput, "  ")
        XCTAssertEqual(reordered.effectivePrimary, "&")

        let kept = jieut(primary: "", popup: ["7", "&"])
        XCTAssertEqual(kept.visibleHint, "7", "들어가는 글자가 힌트와 같으면 그대로")

        let empty = jieut(primary: " ", popup: [" ", ""])
        XCTAssertEqual(empty.visibleHint, "7", "들어갈 글자가 없으면 힌트를 비우지 않는다")
    }

    func test_migration_static_englishDigitKey_editedPrimary_hintFollows() {
        // 영문 숫자 0 (기본 힌트·출력 ")") 의 출력을 ] 로 고친 사용자도 같은 규칙.
        let actions = SecondaryKeyAction.defaults.map { a -> SecondaryKeyAction in
            guard a.keyId == "0" else { return a }
            var e = a
            e.primaryLongPressOutput = "]"
            return e
        }
        let zero = SecondaryKeyAction.action(forKey: "0", from: SecondaryKeyAction.migratingForPrimaryOutput(actions))!
        XCTAssertEqual(zero.visibleHint, "]")
        XCTAssertEqual(zero.primaryLongPressOutput, "]")
        XCTAssertEqual(zero.popupOutputs, [")"])
    }

    func test_migration_static_idempotent() {
        var custom = reporterJieut
        custom[custom.firstIndex(where: { $0.keyId == "ㅈ" })!].visibleHint = "★"
        var both = reorderedJieut
        both[both.firstIndex(where: { $0.keyId == "ㄱ" })!].primaryLongPressOutput = "["
        for input in [reorderedJieut, reporterJieut, custom, both] {
            let once = SecondaryKeyAction.migratingForPrimaryOutput(input)
            XCTAssertEqual(SecondaryKeyAction.migratingForPrimaryOutput(once), once)
        }
    }

    func test_migration_loadAll_reorderedUserKeepsResult_persistsAndSetsFlag() {
        let s = KeyboardSettings.shared
        s.secondaryKeyActions = reorderedJieut
        s.longPressPrimaryMigrated = false
        s.loadAll()
        XCTAssertTrue(s.longPressPrimaryMigrated)
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.primaryLongPressOutput, "&", "인덱스도 이전된 값을 가리킨다")
        // 한 번 더 읽어도(= 디스크에서 다시) 이전된 값 — 저장이 빠지면 여기서 예전 배열로 돌아온다.
        s.loadAll()
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.primaryLongPressOutput, "&")
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.popupOutputs, ["&", "7"])
    }

    func test_migration_loadAll_defaultUserUnchanged_flagSet() {
        let s = KeyboardSettings.shared
        s.longPressPrimaryMigrated = false
        s.loadAll()
        XCTAssertTrue(s.longPressPrimaryMigrated)
        XCTAssertEqual(s.secondaryKeyActions, SecondaryKeyAction.defaults)
    }

    func test_migration_loadAll_editedPrimaryUnchanged() {
        let s = KeyboardSettings.shared
        LongPressSettingsPin.edit("ㅈ") {
            $0.primaryLongPressOutput = "@"
            $0.popupOutputs = ["&", "7"]
        }
        s.longPressPrimaryMigrated = false
        s.loadAll()
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.primaryLongPressOutput, "@")
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.popupOutputs, ["&", "7"])
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.visibleHint, "@", "기본값 힌트는 고친 출력을 따라간다")
    }

    func test_migration_loadAll_reporterState_hintFollows_persistsAndSetsFlag() {
        let s = KeyboardSettings.shared
        s.secondaryKeyActions = reporterJieut
        s.longPressPrimaryMigrated = false
        s.loadAll()
        XCTAssertTrue(s.longPressPrimaryMigrated)
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.visibleHint, "@")
        // 한 번 더 읽어도(= 디스크에서 다시) 이전된 값 — 저장이 빠지면 여기서 힌트 7 로 돌아온다.
        s.loadAll()
        let jieut = s.secondaryAction(forKey: "ㅈ")
        XCTAssertEqual(jieut?.visibleHint, "@")
        XCTAssertEqual(jieut?.primaryLongPressOutput, "@")
        XCTAssertEqual(jieut?.popupOutputs, ["7", "&"])
    }

    func test_migration_runsOnlyOnce_laterReorderDoesNotMovePrimary() {
        let s = KeyboardSettings.shared
        s.longPressPrimaryMigrated = false
        s.loadAll()
        XCTAssertTrue(s.longPressPrimaryMigrated)
        // 이전 뒤(새 의미)에 후보 순서만 바꾼 사용자 — 출력은 7 그대로여야 한다.
        s.secondaryKeyActions = reorderedJieut
        s.loadAll()
        XCTAssertEqual(s.secondaryAction(forKey: "ㅈ")?.primaryLongPressOutput, "7")
    }
}

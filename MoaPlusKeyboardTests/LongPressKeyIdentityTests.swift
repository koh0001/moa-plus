import XCTest

/// 롱키 콜백이 **어느 키의 것인지** 아는가 (이슈 #40).
///
/// 롱키 타이머·팝업 드래그·팝업 뗌은 키 뷰마다 따로 오는데, 예전에는 뷰모델이 그 신호를 받는
/// 시점의 `activeKey`·`keyboardMode` 로 해석했다. 두 엄지 롤오버(이슈 #31/#32 — 앞 키는 다음 키가
/// 눌리는 순간 확정된다)나 한/영·123 전환 뒤에도 앞 키의 타이머는 그대로 울리므로:
/// - (a) ㅈ 을 누른 채 ㄱ → ㅈ 의 타이머가 ㄱ 의 후보로 팝업을 열고 억제 플래그를 세워, ㅈ 을 떼면
///   "9" 가 들어가고 ㄱ 은 사라졌다("ㅈ9").
/// - (b) ㅈ 을 누른 채 123 → (1,2) 를 심볼 "4" 로 다시 해석해 "$".
/// - (c) 팝업이 떠 있던 앞 키의 뗌이 새 키의 `activeKey` 를 지워, 새 키의 롱키가 팝업 없이 글자만 넣었다.
/// - (d) 팝업이 뜬 채 모드를 바꾸면 오버레이가 새 모드로 후보를 다시 걸러 빈 칸으로 남았다.
///
/// 키 뷰의 계약: 타이머가 울리면 `inputLongPressNumber(_:row:column:)` 를 부르고, `true` 일 때만
/// 팝업 모드(뗌 = `confirmPopupSelection(row:column:)`)로 간다. `false` 면 일반 제스처로 남아 뗌이
/// `gestureEnded(row:column:)` 로 간다 — 아래 테스트도 그 순서를 그대로 흉내 낸다.
final class LongPressKeyIdentityTests: XCTestCase {
    private var vm: KeyboardViewModel!
    private var host: LongPressHostDelegate!
    private var pin: LongPressSettingsPin!

    override func setUp() {
        super.setUp()
        pin = LongPressSettingsPin()
        vm = KeyboardViewModel()
        host = LongPressHostDelegate()
        vm.delegate = host
    }

    override func tearDown() {
        vm = nil
        host = nil
        pin.restore()
        pin = nil
        super.tearDown()
    }

    // MARK: - 키 찾기 · 키 뷰 흉내

    private typealias Key = (row: Int, column: Int)

    private func position(of target: KeyContent, mode: KeyboardMode = .korean, page: Int = 0,
                          file: StaticString = #filePath, line: UInt = #line) -> Key {
        let grid = KeyboardMetrics.activeLayout(
            for: mode, layout: KeyboardSettings.shared.layoutCustomization, symbolPage: page)
        for (row, cells) in grid.enumerated() {
            if let column = cells.firstIndex(of: target) { return (row, column) }
        }
        XCTFail("\(mode) 레이아웃에 \(target) 이 없다", file: file, line: line)
        return (0, 0)
    }

    private var jieut: Key { position(of: .consonant(.ㅈ)) }
    private var giyeok: Key { position(of: .consonant(.ㄱ)) }
    private var nieun: Key { position(of: .consonant(.ㄴ)) }
    private var ieung: Key { position(of: .consonant(.ㅇ)) }
    private var ssangjieut: Key { position(of: .consonant(.ㅉ)) }

    /// 그 키를 누른 순간 그리드가 그 키 뷰에 넘겨 둔 롱키 트리거 — 키보드와 같은 함수로 구한다.
    /// 타이머 클로저는 누를 때의 값을 쥐고 있으므로 **누르기 전에** 구해 둬야 한다.
    private func trigger(_ key: Key, file: StaticString = #filePath, line: UInt = #line) -> String {
        let s = KeyboardSettings.shared
        let content = KeyboardMetrics.keyContent(at: key.row, column: key.column, mode: vm.keyboardMode,
                                                 layout: s.layoutCustomization, symbolPage: vm.symbolPage)
        guard let t = KeyGridView.longPressBinding(
            content: content, row: key.row, column: key.column, mode: vm.keyboardMode,
            layout: s.layoutCustomization,
            englishLongPressUppercase: s.englishLongPressUppercaseEnabled,
            storedAction: { s.secondaryAction(forKey: $0) }
        ).trigger else {
            XCTFail("(\(key.row),\(key.column)) 에 롱키 트리거가 없다", file: file, line: line)
            return ""
        }
        return t
    }

    /// 누름 — 키 뷰의 `beginPress` (제스처 시작 + 롱키 타이머 무장). 타이머가 쥘 트리거를 돌려준다.
    @discardableResult
    private func press(_ key: Key) -> String {
        let t = trigger(key)
        vm.gestureStarted(row: key.row, column: key.column, at: .zero)
        return t
    }

    /// 롱키 타이머가 울림. 뷰모델이 받았는지(= 키 뷰가 팝업 모드로 가는지)를 돌려준다.
    private func timerFires(_ key: Key, trigger: String) -> Bool {
        vm.inputLongPressNumber(trigger, row: key.row, column: key.column)
    }

    /// 손 뗌 — 팝업 모드면 `onPopupRelease`, 아니면 `onGestureEnd`.
    private func lift(_ key: Key, popupMode: Bool) {
        if popupMode {
            vm.confirmPopupSelection(row: key.row, column: key.column)
        } else {
            vm.gestureEnded(row: key.row, column: key.column)
        }
    }

    /// 팝업 오버레이가 지금 그려지는가 + 어느 키 위에 — `KeyboardView` 의 표시 조건 그대로.
    private var popupAnchor: Key? {
        guard vm.popupState.text != nil, let key = vm.gestureState.activeKey else { return nil }
        return key
    }

    // MARK: - (a) 두 엄지 롤오버: 먼저 확정된 키의 늦은 롱키

    func test_a_rollover_supersededKeysLateTimer_isIgnored_andNewKeyTypesNormally() {
        let j = jieut, g = giyeok
        let jTrigger = press(j)
        press(g)                                         // 0.12 초 — 롤오버: ㅈ 은 여기서 확정된다
        let accepted = timerFires(j, trigger: jTrigger)  // 0.2 초 — ㅈ 의 타이머
        XCTAssertFalse(accepted, "먼저 확정된 ㅈ 의 타이머가 ㄱ 의 팝업을 열었다")
        XCTAssertNil(popupAnchor)
        XCTAssertTrue(vm.longPressPopupCandidates.isEmpty)
        XCTAssertEqual(host.longPressFeedbackCount, 0, "열리지 않은 팝업의 햅틱")

        lift(j, popupMode: accepted)
        lift(g, popupMode: false)
        XCTAssertEqual(host.text, "ㅈㄱ", "제보 \"ㅈ9\" — ㅈ 의 타이머가 ㄱ 을 삼켰다")
    }

    func test_a_rollover_newKeyStillHeld_ownLongPressWorks() {
        let j = jieut, g = giyeok
        let jTrigger = press(j)
        let gTrigger = press(g)
        XCTAssertFalse(timerFires(j, trigger: jTrigger))
        lift(j, popupMode: false)                        // ㅈ 을 먼저 뗀다 — ㄱ 은 아직 누르고 있다
        XCTAssertTrue(timerFires(g, trigger: gTrigger), "ㄱ 자신의 롱키는 열려야 한다")
        XCTAssertEqual(popupAnchor?.row, g.row)
        XCTAssertEqual(popupAnchor?.column, g.column)
        XCTAssertEqual(vm.longPressPopupCandidates, ["9", "("], "ㄱ 의 후보(괄호 자동 닫기로 ) 제외)")
        lift(g, popupMode: true)
        XCTAssertEqual(host.text, "ㅈ9")
    }

    /// 시프트 롱키(캡스 락)도 같은 문으로 걸러야 한다 — 받으면 억제 플래그가 새 키의 뗌을 삼킨다.
    func test_a_rollover_supersededShiftLongPress_doesNotLockOrSwallowNextKey() {
        vm.keyboardMode = .english
        let shift = position(of: .functional(.shift), mode: .english)
        let a = position(of: .symbol("a"), mode: .english)
        vm.gestureStarted(row: shift.row, column: shift.column, at: .zero)
        vm.gestureStarted(row: a.row, column: a.column, at: .zero)   // 롤오버 — 시프트 탭이 먼저 확정
        XCTAssertEqual(vm.shiftState, .on)
        vm.lockShift(row: shift.row, column: shift.column)           // 시프트 키의 늦은 롱프레스 타이머
        XCTAssertEqual(vm.shiftState, .on, "먼저 확정된 시프트의 타이머가 캡스 락을 걸었다")
        vm.gestureEnded(row: shift.row, column: shift.column)
        vm.gestureEnded(row: a.row, column: a.column)
        XCTAssertEqual(host.text, "A", "억제 플래그가 a 의 뗌을 삼켰다")
        XCTAssertEqual(vm.shiftState, .off)
    }

    // MARK: - (b) 레이어 전환: 누른 키의 늦은 롱키·뗌이 새 레이어로 해석되지 않는다

    func test_b_holdJieut_tap123_beforeDelay_noSymbolFromOtherLayer() {
        let j = jieut
        let jTrigger = press(j)
        vm.toggleSymbolMode()                            // 123 탭 — 롱키 딜레이 전
        XCTAssertEqual(vm.keyboardMode, .symbolFromKorean)
        let accepted = timerFires(j, trigger: jTrigger)
        XCTAssertFalse(accepted, "레이어가 바뀐 뒤의 타이머가 (1,2) 를 심볼 4 로 다시 해석했다")
        XCTAssertNil(popupAnchor)
        lift(j, popupMode: accepted)
        XCTAssertEqual(host.text, "ㅈ", "제보 \"$\" — 누른 ㅈ 은 전환 전 레이어로 확정된다")
        XCTAssertFalse(host.text.contains("$") || host.text.contains("4"))
    }

    /// 롱키 없이 떼도 마찬가지 — 예전에는 뗌이 새 레이어로 해석돼 "4" 가 들어갔다.
    func test_b_holdJieut_tap123_releaseWithoutLongPress_typesJieut() {
        let j = jieut
        press(j)
        vm.toggleSymbolMode()
        lift(j, popupMode: false)
        XCTAssertEqual(host.text, "ㅈ")
    }

    func test_b_holdSsangjieut_tapHanYoung_noEnglishRow0Symbol() {
        let jj = ssangjieut                              // (0,2) — 영문 같은 칸 = 3, 롱키 = #
        let jjTrigger = press(jj)
        vm.toggleLetterMode()
        XCTAssertEqual(vm.keyboardMode, .english)
        let accepted = timerFires(jj, trigger: jjTrigger)
        XCTAssertFalse(accepted)
        lift(jj, popupMode: accepted)
        XCTAssertEqual(host.text, "ㅉ")
    }

    func test_b_symbolPageToggle_heldKeyCommitsOnItsOwnPage() {
        vm.keyboardMode = .symbolFromKorean
        let dash = position(of: .symbol("-"), mode: .symbolFromKorean, page: 0)
        let dashTrigger = press(dash)
        XCTAssertEqual(dashTrigger, "–")
        vm.toggleSymbolPage()                            // #+= 탭
        XCTAssertEqual(vm.symbolPage, 1)
        let accepted = timerFires(dash, trigger: dashTrigger)
        XCTAssertFalse(accepted, "페이지가 바뀐 뒤의 타이머가 page 1 의 같은 칸으로 팝업을 열었다")
        lift(dash, popupMode: accepted)
        XCTAssertEqual(host.insertedTexts, ["-"], "누른 page 0 의 - 가 한 번만")
    }

    // MARK: - (c) 팝업이 떠 있던 앞 키의 뗌은 새 키의 상태를 건드리지 않는다

    func test_c_supersededPopupKeyRelease_keepsNewKeysActiveStateAndPopup() {
        let o = ieung, n = nieun
        let oTrigger = press(o)
        XCTAssertTrue(timerFires(o, trigger: oTrigger))  // ㅇ 팝업이 열린 채
        let nTrigger = press(n)                          // ㄴ 을 누른다 — 팝업 후보를 고른 게 아니므로 확정 없음
        XCTAssertNil(popupAnchor, "앞 키의 팝업은 닫혀야 한다")
        lift(o, popupMode: true)                         // ㅇ 은 팝업 모드였으므로 onPopupRelease
        XCTAssertEqual(vm.gestureState.activeKey?.row, n.row, "앞 키의 뗌이 ㄴ 의 activeKey 를 지웠다")
        XCTAssertEqual(vm.gestureState.activeKey?.column, n.column)
        XCTAssertTrue(host.insertedTexts.isEmpty, "앞 키의 뗌이 무언가를 넣었다")

        XCTAssertTrue(timerFires(n, trigger: nTrigger))
        XCTAssertEqual(popupAnchor?.row, n.row, "ㄴ 의 롱키가 팝업 없이 글자만 넣는 상태")
        XCTAssertEqual(popupAnchor?.column, n.column)
        XCTAssertEqual(vm.longPressPopupCandidates.first, ".")
        lift(n, popupMode: true)
        XCTAssertEqual(host.insertedTexts, ["."])
    }

    func test_c_supersededPopupKeyDrag_doesNotMoveNewKeysSelection() {
        let j = jieut, o = ieung                         // ㅇ 후보 ? / \ — 고를 칸이 여럿
        XCTAssertTrue(timerFires(j, trigger: press(j)))
        let oTrigger = press(o)
        XCTAssertTrue(timerFires(o, trigger: oTrigger))
        XCTAssertEqual(vm.longPressPopupCandidates, ["?", "/", "\\"])
        vm.updatePopupSelection(row: j.row, column: j.column, translationX: 45)   // 앞 키 손가락이 끈다
        XCTAssertEqual(vm.longPressPopupSelectedIndex, 0, "앞 키의 드래그가 ㅇ 의 후보를 움직였다")
        vm.updatePopupSelection(row: o.row, column: o.column, translationX: 45)
        XCTAssertEqual(vm.longPressPopupSelectedIndex, 1, "ㅇ 자신의 드래그는 움직여야 한다")
        lift(j, popupMode: true)
        lift(o, popupMode: true)
        XCTAssertEqual(host.insertedTexts, ["/"])
    }

    /// 상태가 이미 정리된 뒤(`resetGestureState` — 백그라운드 전환 등) 다른 키가 눌렸다면, 앞 키는
    /// 롤오버 기록에도 없다. 그 키의 늦은 콜백도 새 키를 건드리면 안 된다.
    ///
    /// 타이머를 거절당한 키 뷰는 일반 제스처로 남으므로 실제로 오는 건 이동(`gestureMoved`)과
    /// 뗌(`gestureEnded`)이다 (리뷰 — 예전 테스트는 이 둘을 보내지 않아 `gestureEnded` 가 ㄴ 의
    /// 분석기로 ㅇ 을 넣고 ㄴ 의 상태를 지우는 걸 못 잡았다: "ㅇㄴ").
    func test_c_staleKeyAfterReset_callbacksDoNotTouchNewKey() {
        let o = ieung, n = nieun
        let oTrigger = press(o)
        vm.resetGestureState()
        press(n)
        let accepted = timerFires(o, trigger: oTrigger)
        XCTAssertFalse(accepted)
        // ㅇ 손가락의 흔들림 — ㄴ 의 분석기에 들어가면 ㄴ 이 긴 ← 긋기(ㅓ)로 읽힌다 (이슈 #31/#32 와 같은 꼴).
        vm.gestureMoved(row: o.row, column: o.column, to: CGPoint(x: -120, y: 0))
        lift(o, popupMode: accepted)                     // 거절됐으므로 onGestureEnd
        vm.confirmPopupSelection(row: o.row, column: o.column)
        vm.cancelGesture(row: o.row, column: o.column)
        XCTAssertEqual(vm.gestureState.activeKey?.row, n.row, "ㅇ 의 늦은 뗌이 ㄴ 의 activeKey 를 지웠다")
        XCTAssertEqual(vm.gestureState.activeKey?.column, n.column)
        XCTAssertTrue(host.insertedTexts.isEmpty, "ㅇ 의 늦은 뗌이 무언가를 넣었다")
        lift(n, popupMode: false)
        XCTAssertEqual(host.text, "ㄴ", "ㅇ 의 늦은 뗌·이동이 ㄴ 의 긋기로 해석됐다")
    }

    /// 위와 같은데 ㄴ 의 팝업이 이미 떠 있다 — ㅇ 의 뗌이 ㄴ 의 억제 플래그를 가져가 ㄴ 의 팝업과
    /// 결과를 지우면 안 된다 (리뷰).
    func test_c_staleKeyAfterReset_releaseDoesNotTakeNewKeysPopup() {
        let o = ieung, n = nieun
        let oTrigger = press(o)
        vm.resetGestureState()
        let nTrigger = press(n)
        XCTAssertFalse(timerFires(o, trigger: oTrigger))
        XCTAssertTrue(timerFires(n, trigger: nTrigger))
        lift(o, popupMode: false)
        XCTAssertEqual(popupAnchor?.row, n.row, "ㅇ 의 늦은 뗌이 ㄴ 의 팝업을 닫았다")
        XCTAssertEqual(popupAnchor?.column, n.column)
        XCTAssertTrue(host.insertedTexts.isEmpty)
        lift(n, popupMode: true)
        XCTAssertEqual(host.insertedTexts, ["."], "ㄴ 의 롱키 결과가 사라졌다")
        XCTAssertEqual(host.text, ".")
    }

    // MARK: - 슬롯 B 모음 키와 겹칠 때 (리뷰)
    //
    // 슬롯 B(`slotB == .vowelKey` / 확장형 임베드)는 `activeKey` 를 (-1,-1) 로 바꾸는 별도 파이프라인이다.
    // 그리드 키 팝업의 문(`isActiveGridKey`)이 생긴 뒤로, 슬롯 B 가 그리드 키를 정리하지 않고 `activeKey`
    // 를 바꾸면 그 키의 팝업 뗌이 거절돼 팝업이 다음 키 위에 남았다.

    private static let slotBOrigin = CGPoint(x: 200, y: 230)

    private func slotBDown() { vm.slotBVowelGestureStarted(at: Self.slotBOrigin) }

    /// 슬롯 B 에서 → 로 80pt — 분석기 문턱을 넉넉히 넘는다(`KeyboardViewModelVowelDragTests` 와 같은 길이).
    private func slotBDragRight() {
        for i in 1...4 {
            vm.slotBVowelGestureMoved(to: CGPoint(x: Self.slotBOrigin.x + CGFloat(i) * 20,
                                                  y: Self.slotBOrigin.y))
        }
    }

    private func slotBUp() { vm.slotBVowelGestureEnded() }

    /// ㅈ 팝업이 뜬 채 모음 키를 누른다 — 그리드 롤오버와 같이 팝업은 확정 없이 닫힌다. 예전에는 ㅈ 의
    /// 뗌이 거절돼 팝업이 남았고, 다음 키(ㄱ) 위에 그려졌으며, ㄱ→ㄴ 롤오버가 그 팝업 때문에 ㄱ 을
    /// 확정 없이 버렸다.
    func test_slotB_pressedWhileGridPopupOpen_closesPopup_nextKeysUnaffected() {
        let j = jieut, g = giyeok, n = nieun
        XCTAssertTrue(timerFires(j, trigger: press(j)))
        slotBDown()
        XCTAssertNil(vm.longPressPopupText, "모음 키를 눌렀는데 ㅈ 의 팝업이 남았다")
        XCTAssertTrue(vm.longPressPopupCandidates.isEmpty)
        lift(j, popupMode: true)                         // ㅈ 은 팝업 모드였으므로 onPopupRelease
        XCTAssertTrue(host.insertedTexts.isEmpty, "닫힌 팝업의 후보가 들어갔다")
        slotBDragRight()
        slotBUp()
        XCTAssertEqual(host.text, "ㅏ")

        press(g)
        XCTAssertNil(popupAnchor, "ㅈ 의 팝업이 ㄱ 위에 남았다")
        press(n)                                         // 롤오버 — ㄱ 은 여기서 확정돼야 한다
        lift(g, popupMode: false)
        lift(n, popupMode: false)
        XCTAssertEqual(host.text, "ㅏㄱㄴ", "남은 팝업 때문에 롤오버가 ㄱ 을 버렸다")
    }

    /// 두 엄지 롤오버 ㅈ → 모음 키 (B1 의 가장 흔한 입력). 모음 키를 누르는 순간 ㅈ 을 자기 획으로 확정하고
    /// ㅈ 손가락의 이후 신호는 버린다 — 안 하면 ㅈ 의 흔들림이 모음 키 분석기에 들어가 ㅈ 이 긴 긋기로
    /// 읽히고, ㅈ 의 뗌이 모음 키의 분석기를 지운다.
    func test_slotB_rolloverFromGridKey_commitsGridKeyOnce_vowelFromSlotBStroke() {
        let j = jieut
        press(j)
        slotBDown()
        vm.gestureMoved(row: j.row, column: j.column, to: CGPoint(x: 1, y: 0))   // ㅈ 손가락 흔들림
        lift(j, popupMode: false)
        slotBDragRight()
        slotBUp()
        XCTAssertEqual(host.text, "자", "ㅈ 이 빠졌거나 모음 키 획이 ㅈ 의 흔들림과 섞였다")
    }

    /// 천지인 동작(`.cheonjiin`)도 같은 문을 지나야 한다 — 누름은 공통이라 롤오버 확정도 같다.
    func test_slotB_rolloverFromGridKey_cheonjiin_commitsGridKeyOnce() {
        setVowelKeyBehavior(.cheonjiin)
        let j = jieut
        press(j)
        slotBDown()
        vm.gestureMoved(row: j.row, column: j.column, to: CGPoint(x: 1, y: 0))
        lift(j, popupMode: false)
        slotBDragRight()                                 // 천지인: → = ㅡ
        slotBUp()
        XCTAssertEqual(host.text, "즈")
    }

    /// 모음 키를 누른 채 ㅈ 롱키 팝업을 연 뒤 모음 키를 먼저 뗀다 — 모음 키의 뗌이 ㅈ 의 `activeKey` 를
    /// 지우면 ㅈ 의 팝업 드래그·뗌이 거절돼 팝업이 다음 키 위에 남는다.
    func test_slotBHeld_gridKeyPopup_survivesSlotBRelease_andOwnReleaseInserts() {
        assertGridPopupSurvivesSlotBRelease()
    }

    /// 천지인 동작은 슬롯 B 뗌이 따로 끝나는 분기라 따로 본다.
    func test_slotBHeld_gridKeyPopup_survivesSlotBRelease_cheonjiin() {
        setVowelKeyBehavior(.cheonjiin)
        assertGridPopupSurvivesSlotBRelease()
    }

    private func setVowelKeyBehavior(_ behavior: VowelKeyBehavior) {
        var layout = KeyboardSettings.shared.layoutCustomization   // tearDown 의 pin.restore() 가 되돌린다
        layout.vowelKeyBehavior = behavior
        KeyboardSettings.shared.layoutCustomization = layout
    }

    /// 슬롯 B 의 뗌이 이끄는 결과(앞의 ㆍ 등)는 모음 키·그리드 키가 분석기를 함께 쓰는 기존 동작이라
    /// 보지 않는다 — ㅈ 의 팝업이 살아 있는지, ㅈ 의 뗌이 고른 후보를 한 번 넣고 닫는지, 다음 키가
    /// 멀쩡한지만 본다.
    private func assertGridPopupSurvivesSlotBRelease(file: StaticString = #filePath, line: UInt = #line) {
        let j = jieut, g = giyeok, n = nieun
        slotBDown()
        XCTAssertTrue(timerFires(j, trigger: press(j)), "모음 키를 누른 채라도 ㅈ 자신의 롱키는 열려야 한다",
                      file: file, line: line)
        slotBUp()
        XCTAssertEqual(popupAnchor?.row, j.row, "모음 키의 뗌이 ㅈ 의 팝업을 떼어 냈다", file: file, line: line)
        XCTAssertEqual(popupAnchor?.column, j.column, file: file, line: line)
        vm.updatePopupSelection(row: j.row, column: j.column, translationX: 45)
        XCTAssertEqual(vm.longPressPopupSelectedIndex, 1, "ㅈ 의 드래그가 거절됐다", file: file, line: line)
        lift(j, popupMode: true)
        XCTAssertEqual(host.insertedTexts.filter { $0 == "&" }.count, 1, "ㅈ 이 고른 후보가 한 번 들어가야 한다",
                       file: file, line: line)
        XCTAssertFalse(host.insertedTexts.contains("7"), file: file, line: line)
        XCTAssertNil(vm.longPressPopupText, "ㅈ 의 뗌이 팝업을 닫지 못했다", file: file, line: line)

        press(g)
        XCTAssertNil(popupAnchor, "ㅈ 의 팝업이 ㄱ 위에 남았다", file: file, line: line)
        press(n)
        lift(g, popupMode: false)
        lift(n, popupMode: false)
        XCTAssertTrue(host.text.hasSuffix("&ㄱㄴ"), "남은 팝업 때문에 롤오버가 ㄱ 을 버렸다 — \(host.text)",
                      file: file, line: line)
    }

    // MARK: - (d) 팝업이 떠 있을 때 레이어를 바꾸면 팝업을 닫는다

    func test_d_popupOpen_toggleLetterMode_dismissesPopup_andReleaseInsertsNothing() {
        let j = jieut
        XCTAssertTrue(timerFires(j, trigger: press(j)))
        vm.toggleLetterMode()
        XCTAssertEqual(vm.keyboardMode, .english)
        XCTAssertNil(popupAnchor, "팝업이 새 모드로 다시 걸러진 채 남았다")
        XCTAssertNil(vm.longPressPopupText)
        XCTAssertTrue(vm.longPressPopupCandidates.isEmpty)
        lift(j, popupMode: true)
        XCTAssertTrue(host.insertedTexts.isEmpty, "닫힌 팝업의 후보가 들어갔다")
        XCTAssertEqual(host.text, "")
    }

    func test_d_popupOpen_toggleSymbolMode_fullPackage_dismissesPopup() {
        var layout = LayoutCustomization()
        layout.slotA = .fullPackage
        KeyboardSettings.shared.layoutCustomization = layout
        let j = jieut
        XCTAssertTrue(timerFires(j, trigger: press(j)))
        vm.toggleSymbolMode()
        XCTAssertNil(popupAnchor, "확장형에서 팝업이 심볼 레이어 위에 남았다")
        lift(j, popupMode: true)
        XCTAssertTrue(host.insertedTexts.isEmpty)
    }

    func test_d_popupOpen_toggleSymbolPage_dismissesPopup() {
        vm.keyboardMode = .symbolFromKorean
        let dash = position(of: .symbol("-"), mode: .symbolFromKorean, page: 0)
        XCTAssertTrue(timerFires(dash, trigger: press(dash)))
        XCTAssertEqual(vm.longPressPopupCandidates, ["–", "—", "•"])
        vm.toggleSymbolPage()
        XCTAssertNil(popupAnchor)
        lift(dash, popupMode: true)
        XCTAssertTrue(host.insertedTexts.isEmpty)
    }

    // MARK: - 후보는 누를 때의 키 내용·모드로

    /// 모드가 토글을 거치지 않고 바뀌어도(직접 대입) 후보는 누를 때 잡아 둔 키로 만든다.
    func test_candidates_comeFromPressTimeKey_notCurrentMode() {
        let j = jieut
        let jTrigger = press(j)
        vm.keyboardMode = .symbolFromKorean
        XCTAssertTrue(timerFires(j, trigger: jTrigger))
        XCTAssertEqual(vm.longPressPopupCandidates, ["7", "&"], "타이머 시점의 모드로 (1,2) 를 다시 찾았다")
        lift(j, popupMode: true)
        XCTAssertEqual(host.insertedTexts, ["7"])
    }

    // MARK: - 회귀: 겹치지 않는 롱키는 그대로

    func test_plainLongPress_unchanged() {
        let j = jieut
        XCTAssertTrue(timerFires(j, trigger: press(j)))
        XCTAssertEqual(host.longPressFeedbackCount, 1, "팝업이 열린 순간 한 번")
        lift(j, popupMode: true)
        XCTAssertEqual(host.insertedTexts, ["7"])
        XCTAssertEqual(host.longPressFeedbackCount, 1, "뗄 때 다시 울리면 안 된다")
    }
}

/// 실제 문자열에 반영하는 호스트 흉내 + 피드백 종류별 횟수.
private final class LongPressHostDelegate: KeyboardViewModelDelegate {
    private(set) var text = ""
    private(set) var insertedTexts: [String] = []
    private(set) var tapFeedbackCount = 0
    private(set) var layerSwitchFeedbackCount = 0
    private(set) var longPressFeedbackCount = 0

    func insertText(_ s: String) {
        insertedTexts.append(s)
        text += s
    }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func updateComposingText(from previous: String, to current: String) {
        for _ in 0..<previous.count where !text.isEmpty { text.removeLast() }
        text += current
    }
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() { tapFeedbackCount += 1 }
    func triggerLayerSwitchFeedback() { layerSwitchFeedbackCount += 1 }
    func triggerLongPressFeedback() { longPressFeedbackCount += 1 }
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { text }
    func textAfterCursor() -> String? { "" }
}

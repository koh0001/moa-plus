import XCTest
@testable import MoaPlusKeyboard

/// 호스트 복귀(`NSExtensionHostDidBecomeActive`) 때의 설정 재로드.
///
/// 키보드를 띄운 채 앱만 다녀오면 `viewWillAppear` 가 불리지 않아, 그사이 메인 앱에서 고친
/// 설정(단축어 편집 등)이 다윈 알림 하나에만 기대게 된다. 그래서 복귀 시점에 `loadAll()` 을
/// 다시 돌리는데, **전체 접근이 꺼져 있으면** 돌리면 안 된다 — 공유 컨테이너가 없어 키보드 쪽
/// 저장(한손 모드 띠 버튼의 `keyboardPlacement`)이 남지 않으므로, 제어 센터만 내렸다 올려도
/// 떠 있는 키보드가 원래 값으로 풀린다. 그 사용자는 앱의 편집도 어차피 못 받는다.
///
/// `hasFullAccess` 는 iOS 가 정하는 읽기 전용 값이라 하위 클래스로 덮어써서 고정한다.
/// "키보드 쪽 저장이 App Group 에 닿지 않은" 상태는 메모리 값을 바꾼 뒤 App Group 에 옛 값을
/// 직접 써서 만든다. 실제 컨트롤러에 실제 알림을 보내므로 관찰자 배선까지 함께 본다.
final class KeyboardHostActiveReloadTests: XCTestCase {
    /// 끝날 때 nil 로 풀어 `deinit` 이 관찰자를 걷게 한다 — 남으면 뒤 테스트의 알림을 받는다.
    private var controller: KeyboardViewController?

    private var savedPlacement: KeyboardPlacement!
    private var savedStore: ShortcutExpansionStore!

    /// `KeyboardSettings.Keys` 가 private 이라 문자열로 적는다. 둘 다 바꾸면 기존 사용자
    /// 설정이 사라지는 키라 어차피 고정값이다.
    private static let placementKey = "keyboardPlacement"
    private static let shortcutsKey = "shortcutExpansions"

    override func setUp() {
        super.setUp()
        savedPlacement = KeyboardSettings.shared.keyboardPlacement
        savedStore = KeyboardSettings.shared.shortcutExpansionStore
    }

    override func tearDown() {
        controller = nil
        // 속성 대입은 didSet 이 App Group 에도 다시 쓰므로, 테스트가 직접 쓴 값까지 함께 원복된다.
        KeyboardSettings.shared.keyboardPlacement = savedPlacement
        KeyboardSettings.shared.shortcutExpansionStore = savedStore
        super.tearDown()
    }

    private func sharedDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: KeyboardSettings.appGroupId))
    }

    /// 화면에 뜬 키보드. `viewDidLoad` 가 첫 `loadAll()` 과 호스트 알림 관찰자를 건다 —
    /// 메모리 값과 저장값의 어긋남은 이 **뒤에** 만들어야 첫 `loadAll()` 에 지워지지 않는다.
    private func presentKeyboard(fullAccess: Bool) -> KeyboardViewController {
        let keyboard: KeyboardViewController = fullAccess
            ? FullAccessOnKeyboardController()
            : FullAccessOffKeyboardController()
        keyboard.loadViewIfNeeded()
        controller = keyboard
        return keyboard
    }

    /// 제어 센터·알림 센터·Face ID 창을 내렸다 올린 것과 같다. 메인 스레드에서 보내므로
    /// `.main` 큐 관찰자가 이 자리에서 바로 돈다 — 사이에 런루프를 돌리지 않는다
    /// (돌리면 다윈 알림 반사로 들어온 `loadAll()` 이 끼어들어 판정이 흐려진다).
    private func hostBecomesActive() {
        NotificationCenter.default.post(name: .NSExtensionHostDidBecomeActive, object: nil)
    }

    /// 전체 접근 OFF: 띠 버튼으로 왼쪽에 붙인 키보드가 호스트 복귀 후에도 그대로여야 한다.
    /// 게이트 없이 `loadAll()` 을 부르던 커밋에서는 저장돼 있던 `.full` 로 되돌아가 실패한다.
    func testFullAccessOff_hostBecomesActive_keepsKeyboardSidePlacement() throws {
        _ = presentKeyboard(fullAccess: false)

        // 키보드의 띠 버튼. 전체 접근이 꺼져 있으면 이 저장은 App Group 에 닿지 않는다.
        KeyboardSettings.shared.keyboardPlacement = .left
        try sharedDefaults().set(KeyboardPlacement.full.rawValue, forKey: Self.placementKey)

        hostBecomesActive()

        XCTAssertEqual(KeyboardSettings.shared.keyboardPlacement, .left,
                       "전체 접근 OFF 에서 호스트 복귀 때 다시 읽으면 떠 있는 키보드의 한손 모드가 풀린다")
    }

    /// 전체 접근 ON: 키보드를 띄운 채 앱에서 고친 단축어가 호스트 복귀 시점에 들어와야 한다
    /// (다윈 알림을 놓친 경우의 백스톱 — 이 재로드를 지우면 실패한다).
    func testFullAccessOn_hostBecomesActive_reloadsAppEditedShortcuts() throws {
        _ = presentKeyboard(fullAccess: true)

        var store = ShortcutExpansionStore()
        store.add(ShortcutExpansion(trigger: "ㄷㄹ", replacement: "다람쥐"))
        XCTAssertNotEqual(KeyboardSettings.shared.shortcutExpansionStore, store,
                          "precondition: 메모리에는 아직 앱의 편집이 없다")
        // 메인 앱 프로세스의 저장. 다윈 알림은 놓쳤다고 본다(보내지 않는다).
        try sharedDefaults().set(try JSONEncoder().encode(store), forKey: Self.shortcutsKey)

        hostBecomesActive()

        XCTAssertEqual(KeyboardSettings.shared.shortcutExpansionStore, store,
                       "전체 접근 ON 이면 호스트 복귀 때 앱에서 고친 단축어를 다시 읽어야 한다")
    }

    /// 전체 접근 ON 이면 키보드 쪽 저장도 App Group 에 남으므로 다시 읽어도 잃는 것이 없다.
    /// 저장값이 다르다면 그건 앱이 바꾼 것이라 따라가야 한다.
    func testFullAccessOn_hostBecomesActive_followsPersistedPlacement() throws {
        _ = presentKeyboard(fullAccess: true)

        KeyboardSettings.shared.keyboardPlacement = .left
        // 그사이 앱 설정에서 한손 모드를 끈 것.
        try sharedDefaults().set(KeyboardPlacement.full.rawValue, forKey: Self.placementKey)

        hostBecomesActive()

        XCTAssertEqual(KeyboardSettings.shared.keyboardPlacement, .full)
    }
}

/// `hasFullAccess` 를 고정한 키보드. 실제 값은 iOS 설정 › 키보드 › 전체 접근 허용이 정한다.
private final class FullAccessOffKeyboardController: KeyboardViewController {
    override var hasFullAccess: Bool { false }
}

private final class FullAccessOnKeyboardController: KeyboardViewController {
    override var hasFullAccess: Bool { true }
}

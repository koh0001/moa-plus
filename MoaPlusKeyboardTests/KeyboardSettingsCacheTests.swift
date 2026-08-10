import XCTest
import SwiftUI
@testable import MoaPlusKeyboard

/// `KeyboardSettings` 가 렌더 비용을 줄이려고 들고 있는 **파생 캐시**들이 원본
/// 변경에 항상 따라오는지 고정한다.
///
/// 이 캐시들(키 색상 3종, 롱프레스 매핑 인덱스)은 `didSet` 에서만 재빌드되고,
/// `loadAll()` 은 값이 실제로 달라졌을 때만 대입한다. 그래서 무효화 배선이
/// 끊기면 "설정에서 바꿨는데 키보드는 예전 걸 낸다"가 되는데, 이건
/// **스냅샷 테스트로는 절대 잡히지 않는다** — 스냅샷은 정적 렌더 1회만 보고
/// 런타임 설정 변경 경로를 타지 않기 때문이다.
///
/// 캐시 자체가 정확하려면 원본 타입의 `Equatable` 이 **모든 필드를 비교**해야
/// 한다. 예를 들어 `CodableColor` 가 채널 하나를 빼고 비교하면, 커스텀 색을
/// 바꿔도 `loadAll()` 이 "같다"고 판정해 대입을 건너뛰고 → `didSet` 이 안 돌고
/// → 캐시가 옛 색을 계속 낸다. 그래서 여기서 합성 `Equatable` 의 완전성도 함께 못박는다.
final class KeyboardSettingsCacheTests: XCTestCase {

    private var savedTheme: ThemeSettings!
    private var savedActions: [SecondaryKeyAction]!

    override func setUp() {
        super.setUp()
        savedTheme = KeyboardSettings.shared.themeSettings
        savedActions = KeyboardSettings.shared.secondaryKeyActions
    }

    override func tearDown() {
        KeyboardSettings.shared.themeSettings = savedTheme
        KeyboardSettings.shared.secondaryKeyActions = savedActions
        super.tearDown()
    }

    // MARK: - 색상 캐시

    func testCustomKeyBackgroundChange_updatesResolvedColorCache() {
        let s = KeyboardSettings.shared
        var theme = s.themeSettings
        theme.buttonTheme = .custom
        theme.customKeyBackground = CodableColor(red: 0.1, green: 0.2, blue: 0.3)
        theme.keyBackgroundOpacity = 1.0
        s.themeSettings = theme

        XCTAssertEqual(s.resolvedKeyBackground, theme.resolvedKeyBackground,
                       "테마를 바꿨는데 색 캐시가 따라오지 않았다 — didSet 재빌드 배선이 끊겼다")

        // 다른 색으로 한 번 더 — 첫 대입만 우연히 맞은 경우를 배제한다.
        theme.customKeyBackground = CodableColor(red: 0.9, green: 0.8, blue: 0.7)
        s.themeSettings = theme
        XCTAssertEqual(s.resolvedKeyBackground, theme.resolvedKeyBackground)
    }

    func testCustomKeyTextAndFunctionBackground_updateCaches() {
        let s = KeyboardSettings.shared
        var theme = s.themeSettings
        theme.buttonTheme = .custom
        theme.customKeyText = CodableColor(red: 0.4, green: 0.5, blue: 0.6)
        theme.customFunctionKeyBackground = CodableColor(red: 0.7, green: 0.6, blue: 0.5)
        theme.functionKeyBackgroundOpacity = 1.0
        s.themeSettings = theme

        XCTAssertEqual(s.resolvedKeyText, theme.resolvedKeyText)
        XCTAssertEqual(s.resolvedFunctionKeyBackground, theme.resolvedFunctionKeyBackground)
    }

    /// 캐시 무효화가 기대는 전제: 색 필드가 하나라도 다르면 `ThemeSettings` 가
    /// "다르다"고 판정해야 한다. 합성 `Equatable` 이 `CodableColor` 를 통해
    /// 채널까지 내려가는지 채널별로 확인한다 — 한 채널이라도 비교에서 빠지면
    /// `loadAll()` 이 변경을 놓쳐 스테일 캐시가 된다.
    func testThemeEquality_distinguishesEveryColorChannel() {
        var base = ThemeSettings.default
        base.buttonTheme = .custom
        base.customKeyBackground = CodableColor(red: 0.5, green: 0.5, blue: 0.5, opacity: 1.0)

        let channels: [(String, CodableColor)] = [
            ("red",     CodableColor(red: 0.6, green: 0.5, blue: 0.5, opacity: 1.0)),
            ("green",   CodableColor(red: 0.5, green: 0.6, blue: 0.5, opacity: 1.0)),
            ("blue",    CodableColor(red: 0.5, green: 0.5, blue: 0.6, opacity: 1.0)),
            ("opacity", CodableColor(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.9)),
        ]
        for (name, changed) in channels {
            var other = base
            other.customKeyBackground = changed
            XCTAssertNotEqual(base, other,
                              "\(name) 채널만 다른 테마를 같다고 판정한다 — 이러면 색 변경이 loadAll 에서 유실된다")
        }
    }

    // MARK: - 롱프레스 매핑 인덱스

    func testSecondaryActionEdit_isVisibleThroughIndex() {
        let s = KeyboardSettings.shared
        guard let target = s.secondaryKeyActions.first else {
            return XCTFail("기본 보조 매핑이 비어 있다")
        }

        var edited = s.secondaryKeyActions
        edited[0] = SecondaryKeyAction(keyId: target.keyId,
                                       visibleHint: "★",
                                       primaryLongPressOutput: "★",
                                       popupOutputs: ["★"])
        s.secondaryKeyActions = edited

        XCTAssertEqual(s.secondaryAction(forKey: target.keyId)?.primaryLongPressOutput, "★",
                       "매핑을 고쳤는데 조회가 옛 값을 낸다 — 인덱스 재빌드가 안 걸렸다")
    }

    func testSecondaryActionIndex_survivesLoadAll() {
        let s = KeyboardSettings.shared
        guard let keyId = s.secondaryKeyActions.first?.keyId else {
            return XCTFail("기본 보조 매핑이 비어 있다")
        }
        // loadAll 은 값이 같으면 대입을 건너뛴다(따라서 didSet 도 안 돈다).
        // 그 경로를 지나도 조회가 여전히 유효해야 한다.
        s.loadAll()
        XCTAssertNotNil(s.secondaryAction(forKey: keyId),
                        "loadAll 이후 인덱스가 비었다 — 대입 생략 경로에서 캐시가 날아갔다")
    }

    func testUnknownKeyId_returnsNil() {
        XCTAssertNil(KeyboardSettings.shared.secondaryAction(forKey: "존재하지_않는_키"))
        // 빈 문자열은 KeyGridView 가 매핑 없는 키에 쓰는 값이라 반드시 miss 여야 한다.
        XCTAssertNil(KeyboardSettings.shared.secondaryAction(forKey: ""))
    }
}

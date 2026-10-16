import XCTest

/// 설정 › 소리 · 진동 › 이벤트별 햅틱 토글이 실제로 판정에 쓰이는가 (이슈 #41).
///
/// 예전에는 "롱프레스 팝업" 은 `playLongPress()` 호출부가 없었고, "레이어 전환" 은 레이어 키가
/// 탭 햅틱으로 울려 두 토글 모두 아무 효과가 없었다. 판정은 `HapticManager.isEnabled(_:in:)` 하나가
/// 하고, 레이어 전환 키는 탭 대신 `.layerSwitch` 로 묻는다.
final class HapticEventToggleTests: XCTestCase {

    func test_defaults_everyEventEnabled() {
        let settings = ThemeSettings()
        for event in HapticManager.Event.allCases {
            XCTAssertTrue(HapticManager.isEnabled(event, in: settings), "\(event) 기본값이 꺼져 있다 — 오늘 동작이 바뀐다")
        }
    }

    func test_masterSwitchOff_silencesEveryEvent() {
        var settings = ThemeSettings()
        settings.hapticEnabled = false
        for event in HapticManager.Event.allCases {
            XCTAssertFalse(HapticManager.isEnabled(event, in: settings), "\(event)")
        }
    }

    func test_layerSwitchToggleOff_silencesLayerKeys_only() {
        var settings = ThemeSettings()
        settings.hapticOnLayerSwitch = false
        XCTAssertFalse(HapticManager.isEnabled(.layerSwitch, in: settings), "레이어 전환을 껐는데 울린다")
        XCTAssertTrue(HapticManager.isEnabled(.tap, in: settings))
        XCTAssertTrue(HapticManager.isEnabled(.longPress, in: settings))
    }

    /// 레이어 키는 탭 햅틱 **대신** 레이어 전환 햅틱을 내므로 "탭" 토글과 묶이지 않는다.
    func test_tapToggleOff_layerKeysStillBuzz() {
        var settings = ThemeSettings()
        settings.hapticOnTap = false
        XCTAssertFalse(HapticManager.isEnabled(.tap, in: settings))
        XCTAssertTrue(HapticManager.isEnabled(.layerSwitch, in: settings))
        XCTAssertTrue(HapticManager.isEnabled(.longPress, in: settings))
    }

    func test_longPressToggleOff_silencesPopupOnly() {
        var settings = ThemeSettings()
        settings.hapticOnLongPress = false
        XCTAssertFalse(HapticManager.isEnabled(.longPress, in: settings), "롱프레스 팝업을 껐는데 울린다")
        XCTAssertTrue(HapticManager.isEnabled(.tap, in: settings))
        XCTAssertTrue(HapticManager.isEnabled(.layerSwitch, in: settings))
    }

    func test_abbreviationToggle_isIndependent() {
        var settings = ThemeSettings()
        settings.hapticOnAbbreviationConfirm = false
        XCTAssertFalse(HapticManager.isEnabled(.abbreviationConfirm, in: settings))
        XCTAssertTrue(HapticManager.isEnabled(.tap, in: settings))
    }
}

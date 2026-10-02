import XCTest
import SwiftUI
import UIKit
@testable import MoaPlusKeyboard

/// 이슈 #30 — 다크 모드에서 배경만 어두워지고 키는 밝은 프리셋 색으로 남던 문제.
///
/// 밝은 프리셋은 trait 에 따라 스스로 바뀌는 동적 색이어야 하고, 원래 어두운
/// 프리셋과 커스텀은 모드와 무관하게 같은 색이어야 한다.
final class ThemeDarkModeTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    /// 밝기(평균 RGB). 키 배경이 밝은지/어두운지만 본다.
    private func brightness(_ color: Color, _ traits: UITraitCollection) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r + g + b) / 3
    }

    // MARK: - 밝은 프리셋은 다크 모드에서 어두워진다

    func testLightPresets_turnDarkInDarkMode() {
        for theme in [ButtonTheme.defaultGray, .blueAccent, .beige] {
            XCTAssertGreaterThan(brightness(theme.keyBackgroundColor, light), 0.8,
                                 "\(theme) 라이트 모드 키 배경이 바뀌었다 — 기존 사용자 화면 회귀")
            XCTAssertLessThan(brightness(theme.keyBackgroundColor, dark), 0.4,
                              "\(theme) 다크 모드에서 키 배경이 여전히 밝다 (이슈 #30)")
            XCTAssertLessThan(brightness(theme.functionKeyBackgroundColor, dark), 0.4,
                              "\(theme) 다크 모드에서 기능키 배경이 여전히 밝다")
            XCTAssertGreaterThan(brightness(theme.keyTextColor, dark), 0.7,
                                 "\(theme) 다크 모드 글자가 어두운 배경 위에서 안 보인다")
        }
    }

    /// 라이트 모드 색은 업데이트 전 프리셋 값 그대로여야 한다.
    func testAllPresets_lightModeMatchesOriginalPreset() {
        for theme in ButtonTheme.allCases {
            XCTAssertEqual(brightness(theme.keyBackgroundColor, light),
                           brightness(theme.presetKeyBackground.color, light), accuracy: 0.001,
                           "\(theme) 라이트 모드 색이 원래 프리셋과 다르다")
        }
    }

    // MARK: - 어두운 프리셋·커스텀은 모드 무관

    func testDarkPresets_sameInBothModes() {
        for theme in [ButtonTheme.darkCharcoal, .navy] {
            XCTAssertEqual(brightness(theme.keyBackgroundColor, light),
                           brightness(theme.keyBackgroundColor, dark), accuracy: 0.001,
                           "\(theme) 는 원래 어두운 프리셋이라 모드에 따라 바뀌면 안 된다")
        }
    }

    func testCustomColors_ignoreDarkMode() {
        var settings = ThemeSettings()
        settings.buttonTheme = .custom
        settings.customKeyBackground = CodableColor(red: 0.9, green: 0.9, blue: 0.9)
        XCTAssertEqual(brightness(settings.resolvedKeyBackground, dark), 0.9, accuracy: 0.01,
                       "커스텀 색은 사용자가 고른 그대로여야 한다")
    }

    // MARK: - 테마 모드 설정 적용

    func testAppearanceMode_mapsToInterfaceStyle() {
        XCTAssertEqual(AppearanceMode.system.userInterfaceStyle, .unspecified)
        XCTAssertEqual(AppearanceMode.light.userInterfaceStyle, .light)
        XCTAssertEqual(AppearanceMode.dark.userInterfaceStyle, .dark)
        XCTAssertNil(AppearanceMode.system.colorScheme)
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark)
    }

    /// 색 캐시(`KeyboardSettings.resolved*`)의 일치 검사가 기대는 전제 —
    /// 같은 프리셋의 색은 몇 번을 꺼내도 같은 값으로 비교돼야 한다.
    func testPresetColors_areStableAcrossReads() {
        for theme in ButtonTheme.allCases {
            var a = ThemeSettings(); a.buttonTheme = theme
            var b = ThemeSettings(); b.buttonTheme = theme
            XCTAssertEqual(a.resolvedKeyBackground, b.resolvedKeyBackground, "\(theme)")
            XCTAssertEqual(a.resolvedKeyText, b.resolvedKeyText, "\(theme)")
        }
    }
}

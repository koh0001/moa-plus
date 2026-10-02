import Foundation
import SwiftUI

/// Appearance mode
enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "시스템"
        case .light:  return "라이트"
        case .dark:   return "다크"
        }
    }

    /// 키보드 익스텐션 뷰에 강제할 인터페이스 스타일. `.system` 은 호스트를 따른다.
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// 메인 앱 미리보기에 강제할 SwiftUI 색 체계. `nil` = 앱 화면을 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Haptic feedback strength
enum HapticStrength: String, Codable, CaseIterable {
    case light
    case normal

    var displayName: String {
        switch self {
        case .light:  return "약하게"
        case .normal: return "보통"
        }
    }
}

/// Codable Color wrapper (stores RGBA)
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1.0

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: opacity)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(from color: Color) {
        // Default fallback
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
}

/// Button color theme presets
enum ButtonTheme: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case defaultGray
    case darkCharcoal
    case blueAccent
    case navy
    case beige
    case custom

    var displayName: String {
        switch self {
        case .defaultGray:   return "기본 그레이"
        case .darkCharcoal:  return "다크 차콜"
        case .blueAccent:    return "블루 포인트"
        case .navy:          return "네이비"
        case .beige:         return "베이지"
        case .custom:        return "커스텀"
        }
    }

    /// Preset key background color
    var presetKeyBackground: CodableColor {
        switch self {
        case .defaultGray:  return CodableColor(red: 0.95, green: 0.95, blue: 0.97)
        case .darkCharcoal: return CodableColor(red: 0.15, green: 0.15, blue: 0.17)
        case .blueAccent:   return CodableColor(red: 0.93, green: 0.95, blue: 0.98)
        case .navy:         return CodableColor(red: 0.12, green: 0.15, blue: 0.25)
        case .beige:        return CodableColor(red: 0.96, green: 0.94, blue: 0.90)
        case .custom:       return CodableColor(red: 0.95, green: 0.95, blue: 0.97)
        }
    }

    /// Preset key text color
    var presetKeyText: CodableColor {
        switch self {
        case .defaultGray:  return CodableColor(red: 0.0, green: 0.0, blue: 0.0)
        case .darkCharcoal: return CodableColor(red: 1.0, green: 1.0, blue: 1.0)
        case .blueAccent:   return CodableColor(red: 0.1, green: 0.2, blue: 0.4)
        case .navy:         return CodableColor(red: 0.85, green: 0.88, blue: 0.95)
        case .beige:        return CodableColor(red: 0.25, green: 0.22, blue: 0.18)
        case .custom:       return CodableColor(red: 0.0, green: 0.0, blue: 0.0)
        }
    }

    /// Preset function key background color
    var presetFunctionKeyBackground: CodableColor {
        switch self {
        case .defaultGray:  return CodableColor(red: 0.78, green: 0.78, blue: 0.80)
        case .darkCharcoal: return CodableColor(red: 0.22, green: 0.22, blue: 0.24)
        case .blueAccent:   return CodableColor(red: 0.82, green: 0.87, blue: 0.95)
        case .navy:         return CodableColor(red: 0.18, green: 0.22, blue: 0.35)
        case .beige:        return CodableColor(red: 0.90, green: 0.87, blue: 0.82)
        case .custom:       return CodableColor(red: 0.78, green: 0.78, blue: 0.80)
        }
    }

    // MARK: 다크 모드 짝 (이슈 #30)
    //
    // 밝은 프리셋은 다크 모드에서 배경(`systemGray6`)만 어두워지고 키는 밝은 채
    // 남았다. 아래 짝이 있는 프리셋은 다크 모드에서 이 색으로 바뀐다.
    // `nil` = 원래 어두운 프리셋이라 모드와 무관하게 같은 색. 커스텀은 사용자가
    // 고른 색 그대로 둔다 — 다크 짝을 고를 UI 가 없다.

    var presetDarkKeyBackground: CodableColor? {
        switch self {
        case .defaultGray:  return CodableColor(red: 0.33, green: 0.33, blue: 0.35)
        case .blueAccent:   return CodableColor(red: 0.18, green: 0.23, blue: 0.34)
        case .beige:        return CodableColor(red: 0.30, green: 0.28, blue: 0.25)
        case .darkCharcoal, .navy, .custom: return nil
        }
    }

    var presetDarkKeyText: CodableColor? {
        switch self {
        case .defaultGray:  return CodableColor(red: 1.0, green: 1.0, blue: 1.0)
        case .blueAccent:   return CodableColor(red: 0.82, green: 0.88, blue: 1.0)
        case .beige:        return CodableColor(red: 0.96, green: 0.93, blue: 0.87)
        case .darkCharcoal, .navy, .custom: return nil
        }
    }

    var presetDarkFunctionKeyBackground: CodableColor? {
        switch self {
        case .defaultGray:  return CodableColor(red: 0.22, green: 0.22, blue: 0.24)
        case .blueAccent:   return CodableColor(red: 0.12, green: 0.16, blue: 0.25)
        case .beige:        return CodableColor(red: 0.21, green: 0.19, blue: 0.17)
        case .darkCharcoal, .navy, .custom: return nil
        }
    }

    // 뷰가 쓰는 색. 다크 짝이 있으면 trait 에 따라 스스로 바뀌는 동적 색이라
    // `KeyboardSettings` 의 색 캐시를 모드 전환 때 다시 계산할 필요가 없다.
    // 프리셋별로 한 번만 만들어 둔다 — 매번 새 `UIColor` 클로저를 만들면 같은
    // 프리셋끼리도 `Color` 비교가 다르게 나와 캐시 일치 검사가 깨진다.
    var keyBackgroundColor: Color { Self.keyBackgroundPalette[self]! }
    var keyTextColor: Color { Self.keyTextPalette[self]! }
    var functionKeyBackgroundColor: Color { Self.functionKeyBackgroundPalette[self]! }

    private static let keyBackgroundPalette = palette { ($0.presetKeyBackground, $0.presetDarkKeyBackground) }
    private static let keyTextPalette = palette { ($0.presetKeyText, $0.presetDarkKeyText) }
    private static let functionKeyBackgroundPalette = palette { ($0.presetFunctionKeyBackground, $0.presetDarkFunctionKeyBackground) }

    private static func palette(_ pair: (ButtonTheme) -> (CodableColor, CodableColor?)) -> [ButtonTheme: Color] {
        Dictionary(uniqueKeysWithValues: allCases.map { theme in
            let (light, dark) = pair(theme)
            guard let dark else { return (theme, light.color) }
            let lightUI = light.uiColor
            let darkUI = dark.uiColor
            return (theme, Color(UIColor { $0.userInterfaceStyle == .dark ? darkUI : lightUI }))
        })
    }
}

/// Complete theme settings
struct ThemeSettings: Codable, Equatable {
    var appearanceMode: AppearanceMode = .system
    var buttonTheme: ButtonTheme = .defaultGray
    var backgroundImageId: String?
    var backgroundOpacity: Double = 0.3
    var hapticEnabled: Bool = true
    var hapticStrength: HapticStrength = .normal
    var clickSoundEnabled: Bool = false

    /// Custom colors (used when buttonTheme == .custom)
    var customKeyBackground: CodableColor = CodableColor(red: 0.95, green: 0.95, blue: 0.97)
    var customKeyText: CodableColor = CodableColor(red: 0.0, green: 0.0, blue: 0.0)
    var customFunctionKeyBackground: CodableColor = CodableColor(red: 0.78, green: 0.78, blue: 0.80)

    /// Key opacity (0.0 ~ 1.0)
    var keyBackgroundOpacity: Double = 1.0
    var functionKeyBackgroundOpacity: Double = 1.0

    /// Haptic events configuration
    var hapticOnTap: Bool = true
    var hapticOnLongPress: Bool = true
    var hapticOnLayerSwitch: Bool = true
    var hapticOnAbbreviationConfirm: Bool = true

    /// Resolved colors (respects custom vs preset + opacity)
    var resolvedKeyBackground: Color {
        let base = buttonTheme == .custom ? customKeyBackground.color : buttonTheme.keyBackgroundColor
        return base.opacity(keyBackgroundOpacity)
    }
    var resolvedKeyText: Color {
        buttonTheme == .custom ? customKeyText.color : buttonTheme.keyTextColor
    }
    var resolvedFunctionKeyBackground: Color {
        let base = buttonTheme == .custom ? customFunctionKeyBackground.color : buttonTheme.functionKeyBackgroundColor
        return base.opacity(functionKeyBackgroundOpacity)
    }

    static let `default` = ThemeSettings()
}

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

    // Keep Color accessors for backward compatibility with views
    var keyBackgroundColor: Color { presetKeyBackground.color }
    var keyTextColor: Color { presetKeyText.color }
    var functionKeyBackgroundColor: Color { presetFunctionKeyBackground.color }
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

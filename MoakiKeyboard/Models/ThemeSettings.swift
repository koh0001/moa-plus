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

/// Button color theme presets
enum ButtonTheme: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case defaultGray
    case samsungDark
    case blueAccent
    case navy
    case beige

    var displayName: String {
        switch self {
        case .defaultGray:  return "기본 그레이"
        case .samsungDark:  return "삼성 다크"
        case .blueAccent:   return "블루 포인트"
        case .navy:         return "네이비"
        case .beige:        return "베이지"
        }
    }

    /// Key background color
    var keyBackgroundColor: Color {
        switch self {
        case .defaultGray:  return Color(.systemBackground)
        case .samsungDark:  return Color(red: 0.15, green: 0.15, blue: 0.17)
        case .blueAccent:   return Color(red: 0.93, green: 0.95, blue: 0.98)
        case .navy:         return Color(red: 0.12, green: 0.15, blue: 0.25)
        case .beige:        return Color(red: 0.96, green: 0.94, blue: 0.90)
        }
    }

    /// Key text color
    var keyTextColor: Color {
        switch self {
        case .defaultGray:  return Color(.label)
        case .samsungDark:  return .white
        case .blueAccent:   return Color(red: 0.1, green: 0.2, blue: 0.4)
        case .navy:         return Color(red: 0.85, green: 0.88, blue: 0.95)
        case .beige:        return Color(red: 0.25, green: 0.22, blue: 0.18)
        }
    }

    /// Function key background color
    var functionKeyBackgroundColor: Color {
        switch self {
        case .defaultGray:  return Color(.systemGray5)
        case .samsungDark:  return Color(red: 0.22, green: 0.22, blue: 0.24)
        case .blueAccent:   return Color(red: 0.82, green: 0.87, blue: 0.95)
        case .navy:         return Color(red: 0.18, green: 0.22, blue: 0.35)
        case .beige:        return Color(red: 0.90, green: 0.87, blue: 0.82)
        }
    }
}

/// Complete theme settings
struct ThemeSettings: Codable, Equatable {
    var appearanceMode: AppearanceMode = .system
    var buttonTheme: ButtonTheme = .defaultGray
    var backgroundImageId: String? = nil
    var backgroundOpacity: Double = 0.3
    var hapticEnabled: Bool = true
    var hapticStrength: HapticStrength = .normal
    var clickSoundEnabled: Bool = false

    /// Haptic events configuration
    var hapticOnTap: Bool = true
    var hapticOnLongPress: Bool = true
    var hapticOnLayerSwitch: Bool = true
    var hapticOnAbbreviationConfirm: Bool = true

    static let `default` = ThemeSettings()
}

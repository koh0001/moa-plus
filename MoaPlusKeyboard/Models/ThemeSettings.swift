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

/// 배경 사진을 키보드에 맞추는 방식 (이슈 #39 — 앱스토어 리뷰 "키보드 배경 사진 크기 작게 안 됩니다").
enum BackgroundImageContentMode: String, Codable, CaseIterable {
    /// 키보드를 꽉 채운다 — 넘치는 부분은 잘린다. 이 설정이 생기기 전의 유일한 동작이자 기본값.
    case fill
    /// 사진 전체가 보이게 줄인다 — 남는 곳은 평소 키보드 배경이 보인다.
    case fit

    var displayName: String {
        switch self {
        case .fill: return "꽉 채우기"
        case .fit:  return "전체 보이기"
        }
    }
}

/// 배경 사진을 그릴 크기 계산. 뷰와 분리해 둔 순수 함수라 단위 테스트로 고정한다.
enum BackgroundImageLayout {
    /// 사진을 `container` 안에 그릴 크기. 사진은 항상 가운데에 놓는다.
    ///
    /// 기준 크기는 맞춤 방식이 정하고(꽉 채우기 = 두 변 모두 덮는 최소 배율, 전체 보이기 =
    /// 두 변 모두 들어가는 최대 배율) 거기에 `scale` 을 곱한다. 종횡비는 언제나 원본 그대로다.
    /// `scale` 은 `ThemeSettings.backgroundImageScaleRange` 로 잘라 쓴다 — 저장값이 범위를
    /// 벗어나도(손상·다른 버전) 그리는 크기는 범위 안이다.
    static func displaySize(
        imageSize: CGSize,
        containerSize: CGSize,
        contentMode: BackgroundImageContentMode,
        scale: Double
    ) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else { return .zero }
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let base: CGFloat
        switch contentMode {
        case .fill: base = max(widthRatio, heightRatio)
        case .fit:  base = min(widthRatio, heightRatio)
        }
        let ratio = base * CGFloat(ThemeSettings.clampedBackgroundImageScale(scale))
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }
}

/// Complete theme settings
struct ThemeSettings: Codable, Equatable {
    var appearanceMode: AppearanceMode = .system
    var buttonTheme: ButtonTheme = .defaultGray
    var backgroundImageId: String?
    var backgroundOpacity: Double = 0.3
    /// 배경 사진 맞춤 방식 (이슈 #39). 기본 `.fill` = 기존 렌더링 그대로.
    var backgroundImageContentMode: BackgroundImageContentMode = .fill
    /// 배경 사진 크기 배율 — 맞춤 방식의 기준 크기에 곱한다 (이슈 #39).
    /// 기본 1.0 = 기존 렌더링 그대로. 범위는 `backgroundImageScaleRange`.
    var backgroundImageScale: Double = 1.0
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

    /// 배경 사진 크기 배율 범위 (이슈 #39). 줄이기만 한다 — 1.0 이 맞춤 방식의 기준 크기라
    /// 키우면 꽉 채우기는 더 잘리고 전체 보이기는 이름과 어긋난다. 0.5 아래는 키 사이로
    /// 사진이 거의 안 보여 의미가 없다. 설정 슬라이더는 5% 단위.
    static let backgroundImageScaleRange: ClosedRange<Double> = 0.5...1.0
    static let backgroundImageScaleStep: Double = 0.05

    /// 범위 밖·비정상(NaN) 저장값을 그릴 수 있는 배율로. 비정상이면 기본 1.0.
    static func clampedBackgroundImageScale(_ scale: Double) -> Double {
        guard scale.isFinite else { return 1.0 }
        return min(max(scale, backgroundImageScaleRange.lowerBound), backgroundImageScaleRange.upperBound)
    }

    // 저장된 모든 필드를 나열한다 — 빠진 키는 인코딩에서도 조용히 빠진다.
    private enum CodingKeys: String, CodingKey {
        case appearanceMode, buttonTheme, backgroundImageId, backgroundOpacity
        case backgroundImageContentMode, backgroundImageScale
        case hapticEnabled, hapticStrength, clickSoundEnabled
        case customKeyBackground, customKeyText, customFunctionKeyBackground
        case keyBackgroundOpacity, functionKeyBackgroundOpacity
        case hapticOnTap, hapticOnLongPress, hapticOnLayerSwitch, hapticOnAbbreviationConfirm
    }
}

extension ThemeSettings {
    /// 키가 없으면 기본값으로 채운다. 합성 `Decodable` 은 키 하나만 없어도 `keyNotFound` 로
    /// 통째로 실패하고, `KeyboardSettings.loadAll()` 은 그때 `.default` 로 떨어져 사용자의
    /// 테마·배경 사진이 전부 초기화된다 — 새 필드(이슈 #39)가 없는 기존 저장값이 바로 그 경우다.
    /// 확장(extension)에 둬야 `ThemeSettings()` 기본 생성자가 살아남는다.
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearanceMode = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? appearanceMode
        buttonTheme = try c.decodeIfPresent(ButtonTheme.self, forKey: .buttonTheme) ?? buttonTheme
        backgroundImageId = try c.decodeIfPresent(String.self, forKey: .backgroundImageId)
        backgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? backgroundOpacity
        // 새 필드는 모르는 값(다른 버전이 쓴 케이스 등)이어도 테마 전체를 잃지 않게 `try?` 로 받는다.
        backgroundImageContentMode = (try? c.decodeIfPresent(BackgroundImageContentMode.self,
                                                             forKey: .backgroundImageContentMode)) ?? backgroundImageContentMode
        backgroundImageScale = (try? c.decodeIfPresent(Double.self, forKey: .backgroundImageScale)) ?? backgroundImageScale
        hapticEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticEnabled) ?? hapticEnabled
        hapticStrength = try c.decodeIfPresent(HapticStrength.self, forKey: .hapticStrength) ?? hapticStrength
        clickSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .clickSoundEnabled) ?? clickSoundEnabled
        customKeyBackground = try c.decodeIfPresent(CodableColor.self, forKey: .customKeyBackground) ?? customKeyBackground
        customKeyText = try c.decodeIfPresent(CodableColor.self, forKey: .customKeyText) ?? customKeyText
        customFunctionKeyBackground = try c.decodeIfPresent(CodableColor.self, forKey: .customFunctionKeyBackground) ?? customFunctionKeyBackground
        keyBackgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .keyBackgroundOpacity) ?? keyBackgroundOpacity
        functionKeyBackgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .functionKeyBackgroundOpacity) ?? functionKeyBackgroundOpacity
        hapticOnTap = try c.decodeIfPresent(Bool.self, forKey: .hapticOnTap) ?? hapticOnTap
        hapticOnLongPress = try c.decodeIfPresent(Bool.self, forKey: .hapticOnLongPress) ?? hapticOnLongPress
        hapticOnLayerSwitch = try c.decodeIfPresent(Bool.self, forKey: .hapticOnLayerSwitch) ?? hapticOnLayerSwitch
        hapticOnAbbreviationConfirm = try c.decodeIfPresent(Bool.self, forKey: .hapticOnAbbreviationConfirm) ?? hapticOnAbbreviationConfirm
    }
}

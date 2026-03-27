import Foundation
import CoreGraphics

/// Swipe angle preset mode
enum SwipeMode: String, Codable, CaseIterable {
    case right    // Right-hand optimized
    case left     // Left-hand optimized
    case both     // Bimanual (symmetric 45° sectors)
    case custom   // User-defined angles
}

/// Swipe length threshold
enum SwipeLength: String, Codable, CaseIterable {
    case short
    case normal
    case long

    /// Minimum swipe distance in points
    var threshold: CGFloat {
        switch self {
        case .short:  return 12.0
        case .normal: return 20.0
        case .long:   return 30.0
        }
    }

    var displayName: String {
        switch self {
        case .short:  return "짧게"
        case .normal: return "보통"
        case .long:   return "길게"
        }
    }
}

/// What a diagonal direction should resolve to
enum DiagonalMapping: String, Codable, CaseIterable {
    case normalizeUp    // ↖/↗ → treated as ↑
    case normalizeDown  // ↙/↘ → treated as ↓
    case normalizeLeft  // ↖/↙ → treated as ←
    case normalizeRight // ↗/↘ → treated as →
    case vowelI         // ↗ → ㅣ (default for upRight)
    case vowelEu        // ↘ → ㅡ (default for downRight)
    case vowelO         // → ㅗ
    case vowelU         // → ㅜ
    case vowelA         // → ㅏ
    case vowelEo        // → ㅓ
    case disabled       // No vowel output

    var displayName: String {
        switch self {
        case .normalizeUp:    return "↑ 정규화 (ㅗ)"
        case .normalizeDown:  return "↓ 정규화 (ㅜ)"
        case .normalizeLeft:  return "← 정규화 (ㅓ)"
        case .normalizeRight: return "→ 정규화 (ㅏ)"
        case .vowelI:         return "ㅣ"
        case .vowelEu:        return "ㅡ"
        case .vowelO:         return "ㅗ"
        case .vowelU:         return "ㅜ"
        case .vowelA:         return "ㅏ"
        case .vowelEo:        return "ㅓ"
        case .disabled:       return "비활성"
        }
    }
}

/// Per-direction sector configuration
struct DirectionSector: Codable, Equatable {
    /// Center angle of this sector in degrees (0=right, 90=up, 180=left, 270=down)
    var centerAngle: Double
    /// Half-width of sector in degrees (sector spans centerAngle ± halfWidth)
    var halfWidth: Double = 22.5 // Default: 45° total

    var startAngle: Double { centerAngle - halfWidth }
    var endAngle: Double { centerAngle + halfWidth }
}

/// Swipe profile containing angle and length settings
struct SwipeProfile: Codable, Equatable {
    var mode: SwipeMode = .both
    var swipeLength: SwipeLength = .normal

    /// 8 direction sectors (order: →, ↗, ↑, ↖, ←, ↙, ↓, ↘)
    var sectors: [DirectionSector] = DirectionSector.defaultSectors

    /// Diagonal direction mappings (default: both diagonals → ㅣ/ㅡ)
    var upLeftMapping: DiagonalMapping = .vowelI            // ↖ → ㅣ
    var upRightMapping: DiagonalMapping = .vowelI           // ↗ → ㅣ
    var downLeftMapping: DiagonalMapping = .vowelEu          // ↙ → ㅡ
    var downRightMapping: DiagonalMapping = .vowelEu         // ↘ → ㅡ

    /// Predefined profiles
    static let bothHands = SwipeProfile(mode: .both)

    static let rightHand: SwipeProfile = {
        var profile = SwipeProfile(mode: .right)
        // Widen right sector (ㅏ direction)
        profile.sectors[0].halfWidth = 27.5
        profile.sectors[1].halfWidth = 20.0
        profile.sectors[7].halfWidth = 20.0
        return profile
    }()

    static let leftHand: SwipeProfile = {
        var profile = SwipeProfile(mode: .left)
        // Widen left sector (ㅓ direction)
        profile.sectors[4].halfWidth = 27.5
        profile.sectors[3].halfWidth = 20.0
        profile.sectors[5].halfWidth = 20.0
        return profile
    }()
}

extension DirectionSector {
    /// Default 8 sectors at 45° intervals
    /// Order: → (0°), ↗ (45°), ↑ (90°), ↖ (135°), ← (180°), ↙ (225°), ↓ (270°), ↘ (315°)
    static let defaultSectors: [DirectionSector] = [
        DirectionSector(centerAngle: 0),      // → ㅏ
        DirectionSector(centerAngle: 45),     // ↗ ㅣ
        DirectionSector(centerAngle: 90),     // ↑ ㅗ
        DirectionSector(centerAngle: 135),    // ↖ → ↑ 정규화
        DirectionSector(centerAngle: 180),    // ← ㅓ
        DirectionSector(centerAngle: 225),    // ↙ → ↓ 정규화
        DirectionSector(centerAngle: 270),    // ↓ ㅜ
        DirectionSector(centerAngle: 315),    // ↘ ㅡ
    ]

    /// Direction labels for display
    static let directionLabels = ["→ ㅏ", "↗ ㅣ", "↑ ㅗ", "↖", "← ㅓ", "↙", "↓ ㅜ", "↘ ㅡ"]
    static let directionSymbols = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
}

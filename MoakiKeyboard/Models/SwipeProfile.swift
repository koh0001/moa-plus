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

/// Swipe profile containing angle and length settings
struct SwipeProfile: Codable, Equatable {
    var mode: SwipeMode = .both
    /// 8 sector boundary angles (degrees). Default: 8 × 45° uniform.
    var sectorAngles: [Double] = [22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5]
    var swipeLength: SwipeLength = .normal

    /// Predefined profiles
    static let bothHands = SwipeProfile(mode: .both)

    static let rightHand: SwipeProfile = {
        // Right-hand: slightly wider sectors for rightward swipes
        var profile = SwipeProfile(mode: .right)
        // Widen right sector (ㅏ direction) by shifting neighbors
        profile.sectorAngles = [27.5, 67.5, 112.5, 152.5, 202.5, 247.5, 292.5, 337.5]
        return profile
    }()

    static let leftHand: SwipeProfile = {
        // Left-hand: slightly wider sectors for leftward swipes
        var profile = SwipeProfile(mode: .left)
        profile.sectorAngles = [22.5, 67.5, 117.5, 157.5, 207.5, 247.5, 292.5, 332.5]
        return profile
    }()
}

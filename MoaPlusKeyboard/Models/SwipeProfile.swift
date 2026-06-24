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

    /// Fraction of the current center-key width that the finger must
    /// travel before a swipe direction is recorded. Calibrated so that
    /// on a 50pt center-key (≈ iPhone 17 Pro Korean layout) the values
    /// reproduce the legacy absolute thresholds 12 / 20 / 30 pt; on a
    /// smaller iPhone SE (~38pt center key) the thresholds shrink
    /// proportionally, and on iPhone Pro Max (~60pt) they grow.
    private var keyWidthRatio: CGFloat {
        switch self {
        case .short:  return 0.24
        case .normal: return 0.40
        case .long:   return 0.60
        }
    }

    /// Effective swipe threshold for the current device's keyboard
    /// geometry. Pass the live center-key width — the GestureAnalyzer
    /// already owns this value via `keyWidth`.
    func threshold(keyWidth: CGFloat) -> CGFloat {
        // Guard against zero / negative widths from view layout that
        // hasn't run yet. Falls back to the legacy 50pt-equivalent so
        // unit tests and pre-layout invocations stay deterministic.
        let width = keyWidth > 0 ? keyWidth : 50
        return width * keyWidthRatio
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
    /// Half-width of sector in degrees (sector spans centerAngle ± halfWidth).
    /// Retained as the symmetric base used by the four-way path and the
    /// legacy visualisation; per-side recognition reads `leftHalfWidth` /
    /// `rightHalfWidth`.
    ///
    /// Assigning `halfWidth` resets both sides to that symmetric value (so any
    /// existing `sector.halfWidth = x` call site keeps recognising the same
    /// way it always did). To make a side independent, assign the side
    /// *after* `halfWidth`.
    var halfWidth: Double = 22.5 { // Default: 45° total
        didSet {
            leftHalfWidth = halfWidth
            rightHalfWidth = halfWidth
        }
    }

    /// Independent half-width on the CCW (left, increasing-angle) side of the
    /// center. Default equals `halfWidth` → symmetric, identical to legacy.
    var leftHalfWidth: Double = 22.5
    /// Independent half-width on the CW (right, decreasing-angle) side of the
    /// center. Default equals `halfWidth` → symmetric, identical to legacy.
    var rightHalfWidth: Double = 22.5

    var startAngle: Double { centerAngle - halfWidth }
    var endAngle: Double { centerAngle + halfWidth }

    /// Memberwise initialiser is preserved (a custom `init(from:)` is provided
    /// in an extension so older JSON without per-side fields stays decodable).
    init(centerAngle: Double,
         halfWidth: Double = 22.5,
         leftHalfWidth: Double? = nil,
         rightHalfWidth: Double? = nil) {
        self.centerAngle = centerAngle
        self.halfWidth = halfWidth
        self.leftHalfWidth = leftHalfWidth ?? halfWidth
        self.rightHalfWidth = rightHalfWidth ?? halfWidth
    }
}

// MARK: - Forward-compatible decoding (DirectionSector)
//
// `leftHalfWidth` / `rightHalfWidth` are decoded with `decodeIfPresent` and
// fall back to `halfWidth`, so older persisted JSON (which only has
// `centerAngle` + `halfWidth`) decodes as a symmetric sector — bit-for-bit the
// same recognition as before per-side widths existed.
extension DirectionSector {
    private enum CodingKeys: String, CodingKey {
        case centerAngle, halfWidth, leftHalfWidth, rightHalfWidth
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let center = try c.decode(Double.self, forKey: .centerAngle)
        let half = try c.decodeIfPresent(Double.self, forKey: .halfWidth) ?? 22.5
        let left = try c.decodeIfPresent(Double.self, forKey: .leftHalfWidth) ?? half
        let right = try c.decodeIfPresent(Double.self, forKey: .rightHalfWidth) ?? half
        self.init(centerAngle: center, halfWidth: half,
                  leftHalfWidth: left, rightHalfWidth: right)
    }
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

    /// When `true`, only the four cardinal directions (↑↓←→) are recognised.
    /// Each cardinal claims a full 90° quadrant (±45°) and the diagonals are
    /// disabled entirely. Resolves the "ㅗ/ㅜ 각도를 넓혀도 적용 안 됨" report:
    /// in 8-way mode the diagonal-first priority in `GestureDirection.from`
    /// caps how far a cardinal can effectively widen, so users who want a
    /// diagonal-free layout get cardinals auto-balanced to 90° here instead
    /// of fighting per-sector sliders. Default `false` keeps 8-way behaviour.
    var fourWayMode: Bool = false

    /// Global axis rotation in degrees applied to the entire sector ring
    /// (math convention: positive rotates sectors counter-clockwise). This is
    /// a separate axis from per-column `rotationOffsetDeg`; the two are summed
    /// when computing the effective rotation. Default `0` keeps legacy
    /// behaviour. Range ±20° is enforced by the UI.
    var axisRotation: Double = 0

    /// When `true` (default), an angle that no sector claims (a gap opened by
    /// per-side narrowing) is recognised as the nearest-center direction —
    /// `GestureDirection.from`'s STEP3 fallback — so narrowing never leaves a
    /// dead zone. When `false`, an unclaimed angle returns nil (the swipe is
    /// dropped), so narrowing a side turns it into an intentionally inactive
    /// zone. Default `true` keeps the dead-zone-free behaviour.
    var gapFillNearest: Bool = true

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

// MARK: - Forward-compatible decoding
//
// Defined in an extension so the memberwise initialiser (used by the static
// presets above and `SwipeProfile(mode:)` call sites) is preserved. Every
// field is decoded with `decodeIfPresent` and falls back to its default, so
// older persisted JSON that predates a field (e.g. `fourWayMode`) still
// decodes cleanly instead of throwing `keyNotFound` and wiping the user's
// entire gesture configuration via `load(...) ?? .default`.
extension SwipeProfile {
    private enum CodingKeys: String, CodingKey {
        case mode, swipeLength, sectors
        case upLeftMapping, upRightMapping, downLeftMapping, downRightMapping
        case fourWayMode, axisRotation, gapFillNearest
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        mode = try c.decodeIfPresent(SwipeMode.self, forKey: .mode) ?? .both
        swipeLength = try c.decodeIfPresent(SwipeLength.self, forKey: .swipeLength) ?? .normal
        sectors = try c.decodeIfPresent([DirectionSector].self, forKey: .sectors) ?? DirectionSector.defaultSectors
        upLeftMapping = try c.decodeIfPresent(DiagonalMapping.self, forKey: .upLeftMapping) ?? .vowelI
        upRightMapping = try c.decodeIfPresent(DiagonalMapping.self, forKey: .upRightMapping) ?? .vowelI
        downLeftMapping = try c.decodeIfPresent(DiagonalMapping.self, forKey: .downLeftMapping) ?? .vowelEu
        downRightMapping = try c.decodeIfPresent(DiagonalMapping.self, forKey: .downRightMapping) ?? .vowelEu
        fourWayMode = try c.decodeIfPresent(Bool.self, forKey: .fourWayMode) ?? false
        axisRotation = try c.decodeIfPresent(Double.self, forKey: .axisRotation) ?? 0
        gapFillNearest = try c.decodeIfPresent(Bool.self, forKey: .gapFillNearest) ?? true
    }
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

extension Array where Element == DirectionSector {
    /// Applies per-column diagonal width deltas the way the recogniser does
    /// (`GestureAnalyzer.effectiveSectors`): the ㅣ delta widens ↗(1)/↖(3) and
    /// the ㅡ delta widens ↙(5)/↘(7). The delta is added to **both** per-side
    /// widths so a user's left/right asymmetry survives — it never assigns
    /// `halfWidth`, whose `didSet` would mirror-reset the two sides and wipe
    /// that asymmetry. With both deltas 0 this is a no-op, so the mapping /
    /// editor pies (which pass 0) render the exact per-side widths the user set.
    ///
    /// Shared by the recogniser and every settings pie chart so the visual and
    /// the actual recognition can never drift apart.
    func applyingDiagonalDeltas(iDelta: Double, euDelta: Double) -> [DirectionSector] {
        var copy = self
        for idx in [1, 3] where idx < copy.count {
            copy[idx].leftHalfWidth += iDelta
            copy[idx].rightHalfWidth += iDelta
        }
        for idx in [5, 7] where idx < copy.count {
            copy[idx].leftHalfWidth += euDelta
            copy[idx].rightHalfWidth += euDelta
        }
        return copy
    }
}

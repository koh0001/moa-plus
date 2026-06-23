import Foundation
import CoreGraphics

enum GestureDirection: String, CaseIterable {
    case up        // ↑
    case down      // ↓
    case left      // ←
    case right     // →
    case upLeft    // ↖
    case upRight   // ↗
    case downLeft  // ↙
    case downRight // ↘

    /// Sector index → GestureDirection mapping used by data-driven judgment.
    /// Order matches `DirectionSector.defaultSectors` and
    /// `GestureTestModel.sectorIndex` (0:→ 1:↗ 2:↑ 3:↖ 4:← 5:↙ 6:↓ 7:↘).
    private static let sectorOrder: [GestureDirection] = [
        .right, .upRight, .up, .upLeft, .left, .downLeft, .down, .downRight
    ]

    /// Diagonals are checked first so that user-driven widening of a
    /// diagonal (e.g. `verticalIWidthDelta` enlarging ↗) actually eats
    /// into the adjacent cardinal — matching the visual sector model
    /// used by `GestureTestView`.
    private static let diagonalSectorIndices = [1, 3, 5, 7]
    private static let cardinalSectorIndices = [0, 2, 4, 6]

    /// Convenience for callers without per-column settings (e.g. unit
    /// tests). Uses the default 8 × 45° sectors and no rotation.
    static func from(vector: CGVector, threshold: CGFloat = 20) -> GestureDirection? {
        from(vector: vector,
             sectors: DirectionSector.defaultSectors,
             rotationOffset: 0,
             threshold: threshold)
    }

    /// Data-driven judgment that respects user-configurable sector widths
    /// (per-column `verticalIWidthDelta` / `horizontalEuWidthDelta` are
    /// expected to be folded into the supplied `sectors` by the caller)
    /// and per-column `rotationOffset` (degrees, math convention: positive
    /// rotates sectors counter-clockwise).
    ///
    /// The caller passes already-customised sectors so this function stays
    /// pure — no global settings lookups happen here.
    ///
    /// Boundary handling: a sector includes its endpoints. Diagonal-first
    /// priority resolves any overlap that user widening creates. If the
    /// sector ring leaves a gap (only possible with negative deltas
    /// shrinking everything), the function returns nil rather than
    /// guessing — gaps are a misconfiguration the caller should surface.
    static func from(vector: CGVector,
                     sectors: [DirectionSector],
                     rotationOffset: Double,
                     threshold: CGFloat,
                     fourWay: Bool = false) -> GestureDirection? {
        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        guard magnitude >= threshold else { return nil }

        // iOS y-axis is inverted; convert to math convention where
        // 0° = right and 90° = up.
        let angle = atan2(-vector.dy, vector.dx) * 180 / .pi
        let normalized = positiveModulo(angle, 360)

        // Subtract rotationOffset so a positive offset rotates the sector
        // ring CCW — equivalent to rotating the incoming vector CW.
        let relative = positiveModulo(normalized - rotationOffset, 360)

        // Four-way mode: diagonals are disabled and each cardinal owns a full
        // 90° quadrant (±45°). Snap to the nearest cardinal so widening a
        // cardinal is never capped by an adjacent diagonal sector. Sector
        // half-widths are ignored here — the quadrant split is fixed at 45°.
        if fourWay {
            for index in cardinalSectorIndices
            where index < sectors.count && index < sectorOrder.count {
                let sector = sectors[index]
                let delta = abs(signedAngularDistance(from: sector.centerAngle, to: relative))
                if delta <= 45 {
                    return sectorOrder[index]
                }
            }
            return nil
        }

        for index in diagonalSectorIndices + cardinalSectorIndices
        where index < sectors.count && index < sectorOrder.count {
            let sector = sectors[index]
            let delta = abs(signedAngularDistance(from: sector.centerAngle, to: relative))
            if delta <= sector.halfWidth {
                return sectorOrder[index]
            }
        }
        return nil
    }

    private static func positiveModulo(_ value: Double, _ modulus: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: modulus)
        return r < 0 ? r + modulus : r
    }

    /// Smallest signed angular distance from `a` to `b` (degrees), result
    /// in (-180, 180].
    private static func signedAngularDistance(from a: Double, to b: Double) -> Double {
        let diff = (b - a).truncatingRemainder(dividingBy: 360)
        if diff > 180 { return diff - 360 }
        if diff <= -180 { return diff + 360 }
        return diff
    }

    var symbol: String {
        switch self {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .upLeft: return "↖"
        case .upRight: return "↗"
        case .downLeft: return "↙"
        case .downRight: return "↘"
        }
    }

    var isCardinal: Bool {
        switch self {
        case .up, .down, .left, .right: return true
        default: return false
        }
    }

    var isDiagonal: Bool {
        !isCardinal
    }

    /// Check if two directions are exactly opposite (e.g., up↔down, left↔right)
    func isOpposite(to other: GestureDirection) -> Bool {
        switch (self, other) {
        case (.up, .down), (.down, .up),
             (.left, .right), (.right, .left),
             (.upLeft, .downRight), (.downRight, .upLeft),
             (.upRight, .downLeft), (.downLeft, .upRight):
            return true
        default:
            return false
        }
    }

    private static let adjacencyMap: [GestureDirection: Set<GestureDirection>] = [
        .up: [.upLeft, .upRight],
        .down: [.downLeft, .downRight],
        .left: [.upLeft, .downLeft],
        .right: [.upRight, .downRight],
        .upLeft: [.up, .left],
        .upRight: [.up, .right],
        .downLeft: [.down, .left],
        .downRight: [.down, .right]
    ]

    /// Check if two directions are adjacent (e.g., up and upRight are adjacent)
    func isAdjacentTo(_ other: GestureDirection) -> Bool {
        Self.adjacencyMap[self]?.contains(other) ?? false
    }
}

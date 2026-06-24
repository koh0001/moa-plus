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
    /// priority (STEP2) resolves any overlap that user widening creates. If
    /// per-side narrowing leaves a gap that no sector claims, STEP3 falls back
    /// to the nearest-center sector so a narrowed direction never produces a
    /// dead zone (user-confirmed rule: "넓히면 뺏고, 좁힌 빈곳은 가장 가까운
    /// 방향"). nil is returned only below `threshold` (too short a swipe) or
    /// when `sectors` is empty.
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

        // STEP 1: a cardinal the user has widened past its base (22.5°) on the
        // claiming side takes priority over the diagonal that would otherwise
        // eat that angle. Sign convention: positive signedAngularDistance =
        // CCW = left side → leftHalfWidth; negative = CW = right side →
        // rightHalfWidth. Only fires when the side exceeds base AND the angle
        // is past base but within the widened side, so the base range stays
        // diagonal-first (per-column behaviour preserved). On conflict the
        // cardinal nearest the incoming angle wins.
        var widenedCardinal: (direction: GestureDirection, distance: Double)?
        for index in cardinalSectorIndices
        where index < sectors.count && index < sectorOrder.count {
            let sector = sectors[index]
            let signed = signedAngularDistance(from: sector.centerAngle, to: relative)
            let side = signed >= 0 ? sector.leftHalfWidth : sector.rightHalfWidth
            let delta = abs(signed)
            if side > sector.halfWidth && delta > sector.halfWidth && delta <= side {
                if widenedCardinal == nil || delta < widenedCardinal!.distance {
                    widenedCardinal = (sectorOrder[index], delta)
                }
            }
        }
        if let widenedCardinal {
            return widenedCardinal.direction
        }

        // STEP 2: legacy diagonal-first sweep, now per-side. A sector claims
        // the angle when |signedDist| <= the half-width on the side the angle
        // falls. Default sectors have left == right == halfWidth so this is
        // identical to the previous `delta <= sector.halfWidth` check.
        for index in diagonalSectorIndices + cardinalSectorIndices
        where index < sectors.count && index < sectorOrder.count {
            let sector = sectors[index]
            let signed = signedAngularDistance(from: sector.centerAngle, to: relative)
            let side = signed >= 0 ? sector.leftHalfWidth : sector.rightHalfWidth
            if abs(signed) <= side {
                return sectorOrder[index]
            }
        }

        // STEP 3: nearest-center fallback. Reached only when per-side
        // narrowing has opened a gap that neither STEP1 nor STEP2 claimed —
        // assign the angle to the sector whose center is closest so a narrowed
        // direction never leaves a dead zone. With default sectors STEP2 tiles
        // all 360°, so this never fires (legacy output is bit-identical). On a
        // distance tie the earlier index in `sectorOrder` wins (strict `<`),
        // matching STEP1's tie-break convention.
        var nearest: (direction: GestureDirection, distance: Double)?
        for index in 0..<min(sectors.count, sectorOrder.count) {
            let delta = abs(signedAngularDistance(from: sectors[index].centerAngle, to: relative))
            if nearest == nil || delta < nearest!.distance {
                nearest = (sectorOrder[index], delta)
            }
        }
        return nearest?.direction
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

    /// Standard center angle of each direction (math convention: 0°=→, 90°=↑).
    private var standardAngle: Double {
        switch self {
        case .right:     return 0
        case .upRight:   return 45
        case .up:        return 90
        case .upLeft:    return 135
        case .left:      return 180
        case .downLeft:  return 225
        case .down:      return 270
        case .downRight: return 315
        }
    }

    /// Smallest angle between two directions' center angles (0...180°).
    /// Used to size how sharply a multi-stroke gesture turned: 180° = exact
    /// reversal (↑↓), 135° = near-opposite (↑↘), 90° = right angle (↑→).
    func angularGap(to other: GestureDirection) -> Double {
        let diff = abs(standardAngle - other.standardAngle).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }
}

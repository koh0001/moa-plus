import Foundation
import CoreGraphics

class GestureAnalyzer {
    private struct DirectionSegment {
        var direction: GestureDirection
        var magnitude: CGFloat
    }

    private var touchPoints: [CGPoint] = []
    private var directions: [GestureDirection] = []
    private var directionMagnitudes: [CGFloat] = []
    private var lastDirectionChangePoint: CGPoint?

    private let threshold: CGFloat
    private let reversalThreshold: CGFloat
    private let directionChangeThreshold: CGFloat

    /// Configurable gesture settings (defaults to standard if not set)
    var settings: GestureSettings = .default

    /// Column ID for per-column gesture correction (1-5, 0 = no column override)
    var columnId: Int = 0

    /// Live center-key width, set by the view layer once geometry is
    /// known. Drives the proportional swipe threshold so the same
    /// "보통" / "길게" preset feels right on every iPhone size.
    /// Default 50 reproduces the legacy absolute thresholds for
    /// pre-layout calls and unit tests.
    var keyWidth: CGFloat = 50

    /// Effective swipe threshold considering column overrides + the
    /// device's center-key width.
    var effectiveThreshold: CGFloat {
        if columnId > 0 {
            return settings.effectiveSwipeThreshold(forColumn: columnId, keyWidth: keyWidth)
        }
        return settings.swipeProfile.swipeLength.threshold(keyWidth: keyWidth)
    }

    /// Effective direction-change threshold considering column overrides.
    /// If the analyzer was constructed with a custom `directionChangeThreshold`
    /// (legacy/test path) we honour that value; otherwise we read it from
    /// settings so user customisation in the UI flows through to actual
    /// judgment.
    var effectiveDirectionChangeThreshold: CGFloat {
        if hasCustomDirectionChangeThreshold {
            return directionChangeThreshold
        }
        if columnId > 0 {
            return settings.effectiveDirectionChangeThreshold(forColumn: columnId)
        }
        return settings.directionChangeThreshold
    }

    /// Sector ring with per-column rotation+delta adjustments folded in,
    /// ready to hand to `GestureDirection.from`.
    private var effectiveSectors: [DirectionSector] {
        var sectors = settings.swipeProfile.sectors
        guard columnId > 0 else { return sectors }
        let iDelta = settings.verticalIWidthDelta(forColumn: columnId)
        let euDelta = settings.horizontalEuWidthDelta(forColumn: columnId)
        // ↗ (1) and ↖ (3) widen with the ㅣ delta; ↙ (5) and ↘ (7) widen
        // with the ㅡ delta. Cardinals stay at their base widths and are
        // shrunk implicitly by the diagonal-first priority in
        // `GestureDirection.from`.
        for index in [1, 3] where index < sectors.count {
            sectors[index].halfWidth += iDelta
        }
        for index in [5, 7] where index < sectors.count {
            sectors[index].halfWidth += euDelta
        }
        return sectors
    }

    private var effectiveRotationOffset: Double {
        guard columnId > 0 else { return 0 }
        return settings.effectiveRotationOffset(forColumn: columnId)
    }

    private let hasCustomDirectionChangeThreshold: Bool

    /// Designated initialiser. Tests usually pin all three thresholds for
    /// deterministic behaviour; the runtime keyboard creates the analyzer
    /// without arguments and lets it read every threshold from `settings`.
    init(threshold: CGFloat = KeyboardMetrics.gestureThreshold,
         reversalThreshold: CGFloat = KeyboardMetrics.reversalThreshold,
         directionChangeThreshold: CGFloat? = nil) {
        self.threshold = threshold  // Note: effectiveThreshold takes precedence at runtime
        self.reversalThreshold = reversalThreshold
        self.directionChangeThreshold = directionChangeThreshold ?? KeyboardMetrics.directionChangeThreshold
        self.hasCustomDirectionChangeThreshold = directionChangeThreshold != nil
    }

    convenience init(settings: GestureSettings, columnId: Int = 0) {
        self.init()
        self.settings = settings
        self.columnId = columnId
    }

    func reset() {
        touchPoints.removeAll(keepingCapacity: true)
        directions.removeAll(keepingCapacity: true)
        directionMagnitudes.removeAll(keepingCapacity: true)
        lastDirectionChangePoint = nil
    }

    func addPoint(_ point: CGPoint) {
        touchPoints.append(point)
        analyzeLatestMovement()
    }

    func getDirections() -> [GestureDirection] {
        return directions
    }

    func getStartPoint() -> CGPoint? {
        return touchPoints.first
    }

    private func analyzeLatestMovement() {
        guard touchPoints.count >= 2 else { return }

        guard let referencePoint = lastDirectionChangePoint ?? touchPoints.first,
              let currentPoint = touchPoints.last else { return }

        let vector = CGVector(
            dx: currentPoint.x - referencePoint.x,
            dy: currentPoint.y - referencePoint.y
        )

        let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)

        let sectors = effectiveSectors
        let rotation = effectiveRotationOffset

        // Try detecting direction with effective threshold first (respects
        // settings/column overrides, including rotation and ㅣ/ㅡ width deltas).
        var newDirection = GestureDirection.from(
            vector: vector,
            sectors: sectors,
            rotationOffset: rotation,
            threshold: effectiveThreshold
        )

        // If standard threshold fails, try lower reversal threshold for opposite directions
        if newDirection == nil, let lastDirection = directions.last, magnitude >= reversalThreshold {
            if let candidate = GestureDirection.from(
                vector: vector,
                sectors: sectors,
                rotationOffset: rotation,
                threshold: reversalThreshold
            ),
               candidate.isOpposite(to: lastDirection) {
                newDirection = candidate
            }
        }

        guard let newDirection else { return }

        let changeThreshold = effectiveDirectionChangeThreshold

        // Check if this is a new direction or continuation
        if let lastDirection = directions.last {
            // Only add if direction changed
            if newDirection != lastDirection {
                // Make sure we've moved enough from the last direction change
                if magnitude >= changeThreshold || (newDirection.isOpposite(to: lastDirection) && magnitude >= reversalThreshold) {
                    directions.append(newDirection)
                    directionMagnitudes.append(magnitude)
                    lastDirectionChangePoint = currentPoint
                }
            }
        } else {
            // First direction
            directions.append(newDirection)
            directionMagnitudes.append(magnitude)
            lastDirectionChangePoint = currentPoint
        }
    }

    func finalizeGesture() -> [GestureDirection] {
        let segments = zip(directions, directionMagnitudes).map {
            DirectionSegment(direction: $0.0, magnitude: $0.1)
        }
        return normalizeSegments(segments).map { $0.direction }
    }

    /// Keep intentional turns for 3-stroke gestures (important for ㅙ/ㅞ),
    /// while removing duplicate and jitter-only segments.
    private func normalizeSegments(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var collapsed = collapseConsecutiveDuplicates(segments)
        collapsed = collapseTinyOscillations(collapsed)
        collapsed = trimTinyLeadingAndTrailingNoise(collapsed)
        return collapsed
    }

    private func collapseConsecutiveDuplicates(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [DirectionSegment] = [segments[0]]
        for segment in segments.dropFirst() {
            if segment.direction == result.last?.direction {
                if segment.magnitude > (result.last?.magnitude ?? 0) {
                    result[result.count - 1].magnitude = segment.magnitude
                }
                continue
            }
            result.append(segment)
        }
        return result
    }

    private func collapseTinyOscillations(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count >= 3 else { return segments }

        var result = segments
        var index = 1

        let jitterMagnitudeCap = max(reversalThreshold, directionChangeThreshold * 0.8)
        let jitterRatio: CGFloat = 0.75

        while index < result.count - 1 {
            let previous = result[index - 1]
            let current = result[index]
            let next = result[index + 1]

            let returnsToPrevious = previous.direction == next.direction
            let isAdjacentJitter = current.direction.isAdjacentTo(previous.direction)
            let isTinySegment = current.magnitude <= jitterMagnitudeCap ||
                current.magnitude <= min(previous.magnitude, next.magnitude) * jitterRatio

            if returnsToPrevious && isAdjacentJitter && isTinySegment {
                result[index - 1].magnitude = max(previous.magnitude, next.magnitude)
                result.remove(at: index + 1)
                result.remove(at: index)
                if index > 1 {
                    index -= 1
                }
                continue
            }

            index += 1
        }

        return result
    }

    private func trimTinyLeadingAndTrailingNoise(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count > 1 else { return segments }

        var result = segments
        let edgeNoiseCap = max(reversalThreshold, directionChangeThreshold * 0.8)

        if let first = result.first, let second = result.dropFirst().first {
            if first.magnitude <= edgeNoiseCap && first.direction.isAdjacentTo(second.direction) {
                result.removeFirst()
            }
        }

        if result.count > 1, let last = result.last, let previous = result.dropLast().last {
            if last.magnitude <= edgeNoiseCap && last.direction.isAdjacentTo(previous.direction) {
                result.removeLast()
            }
        }

        return result
    }

}

// Extension to help with gesture visualization
extension GestureAnalyzer {
    var directionString: String {
        directions.map { $0.symbol }.joined()
    }

    var hasGesture: Bool {
        !directions.isEmpty
    }
}

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

    /// Effective reversal threshold. Scales with the user's swipeLength
    /// preset and per-column outwardDistanceMultiplier so "긋기 길이 길게"
    /// also relaxes opposite-direction registration. Falls back to the
    /// constructor-supplied value when that path was used (tests).
    var effectiveReversalThreshold: CGFloat {
        // Legacy/test constructor path: respect the explicit value.
        if reversalThreshold != KeyboardMetrics.reversalThreshold {
            return reversalThreshold
        }
        return settings.effectiveReversalThreshold(forColumn: columnId, keyWidth: keyWidth)
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
        let fourWay = settings.swipeProfile.fourWayMode

        // Try detecting direction with effective threshold first (respects
        // settings/column overrides, including rotation and ㅣ/ㅡ width deltas).
        var newDirection = GestureDirection.from(
            vector: vector,
            sectors: sectors,
            rotationOffset: rotation,
            threshold: effectiveThreshold,
            fourWay: fourWay
        )

        let effReversal = effectiveReversalThreshold

        // If standard threshold fails, try lower reversal threshold for large-angle
        // turns. sensitivity 0 keeps this to exact opposites (기존 isOpposite 동작);
        // higher sensitivities also admit near-opposite / right-angle turns so
        // multi-stroke vowels register without returning to the origin.
        if newDirection == nil, let lastDirection = directions.last, magnitude >= effReversal {
            if let candidate = GestureDirection.from(
                vector: vector,
                sectors: sectors,
                rotationOffset: rotation,
                threshold: effReversal,
                fourWay: fourWay
            ),
               qualifiesAsTurn(gap: candidate.angularGap(to: lastDirection)) {
                newDirection = candidate
            }
        }

        guard let newDirection else { return }

        let changeThreshold = effectiveDirectionChangeThreshold

        // Check if this is a new direction or continuation
        if let lastDirection = directions.last {
            // Only add if direction changed
            if newDirection != lastDirection {
                let gap = newDirection.angularGap(to: lastDirection)
                let turnThreshold = turnRegistrationThreshold(
                    gap: gap, changeThreshold: changeThreshold, reversal: effReversal
                )
                // 진폭 비율 가드: 새 turn 스트로크가 직전 스트로크 진폭 대비 너무
                // 작으면(손떨림) 등록하지 않는다 — 단일 모음(ㅗ/ㅜ/ㅏ/ㅓ)이 복합
                // 모음으로 과승격되는 것을 막는다. sensitivity 0 에서는 비율 0 이라
                // 가드가 비활성 → 기존 동작 보존.
                let prevMagnitude = directionMagnitudes.last ?? magnitude
                let passesAmplitudeGuard = magnitude >= prevMagnitude * minTurnAmplitudeRatio
                if magnitude >= turnThreshold && passesAmplitudeGuard {
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

    /// 2차(낮은 reversal 임계) 방향 분류를 허용할 turn 인지 — sensitivity 기반.
    /// sensitivity 0 은 정확한 반대(180°)만 허용해 기존 isOpposite 동작과 동등하다.
    private func qualifiesAsTurn(gap: Double) -> Bool {
        switch settings.multiStrokeTurnSensitivity {
        case ...0: return gap > 179
        case 1:    return gap >= 135
        default:   return gap >= 90
        }
    }

    /// 방향 전환 각도(gap)와 사용자 민감도에 따른 새 스트로크 등록 변위 임계.
    /// 큰 각도 turn(멀티스트로크 모음의 왕복)일수록 낮은 임계를 적용해 원점 복귀
    /// 없이 등록되게 한다.
    /// - sensitivity 0: 정확한 반대(180°)만 reversal, 그 외 change — 기존 동작과 동등.
    /// - sensitivity 1: near-opposite(≥135°) reversal, 직각(≥90°) 중간.
    /// - sensitivity 2: 직각(≥90°) reversal, 완만(≥45°) 중간.
    private func turnRegistrationThreshold(gap: Double, changeThreshold: CGFloat, reversal: CGFloat) -> CGFloat {
        let mid = (reversal + changeThreshold) / 2
        switch settings.multiStrokeTurnSensitivity {
        case ...0:
            return gap > 179 ? reversal : changeThreshold
        case 1:
            if gap >= 135 { return reversal }
            if gap >= 90 { return mid }
            return changeThreshold
        default: // 2 이상
            if gap >= 90 { return reversal }
            if gap >= 45 { return mid }
            return changeThreshold
        }
    }

    /// 떨림 컷용 진폭 비율: 새 turn 스트로크가 직전 스트로크 진폭의 이 비율
    /// 이상일 때만 등록. sensitivity 0 = 0(가드 비활성, 기존 동작 보존).
    private var minTurnAmplitudeRatio: CGFloat {
        switch settings.multiStrokeTurnSensitivity {
        case ...0: return 0
        case 1:    return 0.3
        default:   return 0.4
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

        let jitterMagnitudeCap = max(effectiveReversalThreshold, directionChangeThreshold * 0.8)
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
        let edgeNoiseCap = max(effectiveReversalThreshold, directionChangeThreshold * 0.8)

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

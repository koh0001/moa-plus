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
    /// 현재 stroke가 처음 등록된 지점(누적 magnitude/finalize 기준).
    private var lastDirectionChangePoint: CGPoint?
    /// 현재 stroke에서 마지막으로 같은 방향이 관측된 점. 방향이 바뀌면 이 점이
    /// 곧 "turn 지점"이 되어 새 stroke 변위의 측정 기준이 된다. 같은 방향이
    /// 이어질 때마다 최근 점으로 전진한다.
    private var strokeAnchorPoint: CGPoint?

    private let threshold: CGFloat
    private let reversalThreshold: CGFloat
    private let directionChangeThreshold: CGFloat

    /// Configurable gesture settings (defaults to standard if not set)
    var settings: GestureSettings = .default

    /// Column ID for per-column gesture correction (1-5, 0 = no column override)
    var columnId: Int = 0

    /// vowel-primitive 키(ㅣ/ㅡ)는 4방향 파생모음(←→↑↓)만 쓰므로 카디널만
    /// 인식하도록 강제. 대각선을 무조건 상하로 정규화(normalizedCardinal)하던
    /// 탓에 ㅡ키 좌우(ㅛㅠ)가 기운 긋기에서 ㅗㅜ 로 뒤바뀌던 문제를 막는다.
    /// (fourWayMode 와 동일하게 GestureDirection.from 의 카디널 스냅을 켠다.)
    var forceCardinalOnly: Bool = false

    /// Live center-key width, set by the view layer once geometry is
    /// known. Drives the proportional swipe threshold so the same
    /// "보통" / "길게" preset feels right on every iPhone size.
    /// Default 50 reproduces the legacy absolute thresholds for
    /// pre-layout calls and unit tests.
    var keyWidth: CGFloat = 50

    /// Effective swipe threshold considering column overrides + the
    /// device's center-key width.
    var effectiveThreshold: CGFloat {
        let base: CGFloat
        if columnId > 0 {
            base = settings.effectiveSwipeThreshold(forColumn: columnId, keyWidth: keyWidth)
        } else {
            base = settings.swipeProfile.swipeLength.threshold(keyWidth: keyWidth)
        }
        // ㅣ/ㅡ 전용 키(우측 끝 좁은 키)는 수평(←→) 긋기 거리가 부족해 첫 방향
        // 등록에 실패하고 탭(ㅡ/ㅣ)으로 폴백되곤 한다 — ㅛㅠ 가 안 되던 핵심 원인.
        // 긋기 길이 설정(짧게/보통/길게)과 무관하게 keyWidth 기반의 낮은 고정
        // 임계(~10pt)를 써서 '길게' 설정에서도 짧은 긋기가 인식되게 한다.
        return forceCardinalOnly ? keyWidth * Self.narrowKeyThresholdRatio : base
    }

    /// vowel-primitive(ㅣ/ㅡ) 좁은 키 첫-방향 임계 (keyWidth 대비 ≈ 10pt).
    private static let narrowKeyThresholdRatio: CGFloat = 0.2

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
        let sectors = settings.swipeProfile.sectors
        guard columnId > 0 else { return sectors }
        // ↗(1)/↖(3) widen with the ㅣ delta; ↙(5)/↘(7) with the ㅡ delta —
        // added to both per-side widths so any user asymmetry survives.
        // Shared with the settings pie charts via `applyingDiagonalDeltas`
        // so the visual can never drift from what `from()` actually claims
        // (`testColumn5SteepDiagonalStaysAsUpRight` depends on the result).
        return sectors.applyingDiagonalDeltas(
            iDelta: settings.verticalIWidthDelta(forColumn: columnId),
            euDelta: settings.horizontalEuWidthDelta(forColumn: columnId))
    }

    private var effectiveRotationOffset: Double {
        // Global axis rotation applies to every column (and to columnId 0);
        // per-column rotationOffset is summed on top of it.
        let global = settings.swipeProfile.axisRotation
        guard columnId > 0 else { return global }
        return global + settings.effectiveRotationOffset(forColumn: columnId)
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
        strokeAnchorPoint = nil
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
        guard touchPoints.count >= 2,
              let currentPoint = touchPoints.last,
              let startPoint = touchPoints.first else { return }

        let sectors = effectiveSectors
        let rotation = effectiveRotationOffset
        let fourWay = settings.swipeProfile.fourWayMode || forceCardinalOnly
        let fillGap = settings.swipeProfile.gapFillNearest

        // 방향 값은 "최근 window"(reversal 거리만큼의 궤적)로 판정한다. 먼 stroke
        // 시작점 기준이 아니라 직전 짧은 궤적을 보므로, 긴 진입 stroke(자음 대각선
        // ↗/↙)에 이은 후속 카디널이 진입 방향에 흡수되거나(↗→ → ↗) 전환 중간에
        // 엉뚱한 방향이 끼어드는(↙↑ → ↙←↑) 왜곡이 사라진다.
        let windowRef = touchPoints[windowReferenceIndex(arcLength: effectiveDirectionWindow)]
        let dirVector = CGVector(
            dx: currentPoint.x - windowRef.x,
            dy: currentPoint.y - windowRef.y
        )

        // window 벡터는 길이가 짧으므로 reversal 절반 임계로 방향만 분류한다. 실제
        // "등록" 여부는 아래의 누적/turn 변위 게이트가 결정한다.
        guard let newDirection = GestureDirection.from(
            vector: dirVector,
            sectors: sectors,
            rotationOffset: rotation,
            threshold: effectiveDirectionThreshold,
            fourWay: fourWay,
            fillGap: fillGap
        ) else { return }

        if let lastDirection = directions.last {
            if newDirection == lastDirection {
                // 같은 방향 연장: 다음 turn 측정 기준점(anchor)을 최근 점으로 전진.
                strokeAnchorPoint = currentPoint
                return
            }

            let gap = newDirection.angularGap(to: lastDirection)
            let changeThreshold = effectiveDirectionChangeThreshold
            let effReversal = effectiveReversalThreshold
            let baseTurn = turnRegistrationThreshold(
                gap: gap, changeThreshold: changeThreshold, reversal: effReversal
            )
            // reversal(왕복)은 낮은 임계로 즉시 등록해 촘촘한 반전(ㅛ ↑↓↑, ㅠ ↓↑↓)을
            // 보존한다. 비reversal(직각/완만 turn)은 full-swipe 임계를 바닥으로 둬,
            // 정수직 stroke 안의 작은 ↗ 흔들림이나 끝부분 휨이 새 stroke 로 과등록
            // 되는 것을 막는다(ㅗ → ㅘ 오인식 방지).
            let turnThreshold = qualifiesAsTurn(gap: gap)
                ? baseTurn
                : max(baseTurn, effectiveThreshold)

            // turn 변위는 "직전 stroke 의 마지막 관측점(= turn 지점)"부터 잰다. 새
            // stroke 자체 길이만 보므로, 긴 진입 stroke 뒤의 누적 부풀림 없이 작은
            // 곁가지(wobble)는 미달로 버리고 의도된 후속만 등록한다. 방향이 원래대로
            // 복귀하면 위의 `newDirection == lastDirection` 분기에서 anchor 가 전진해
            // 곁가지가 자연히 무시된다.
            let anchor = strokeAnchorPoint ?? lastDirectionChangePoint ?? startPoint
            let dx = currentPoint.x - anchor.x
            let dy = currentPoint.y - anchor.y
            let displacement = sqrt(dx * dx + dy * dy)

            // 진폭 비율 가드: sensitivity 0 에서는 비율 0 이라 비활성(기존 동작 보존).
            let prevMagnitude = directionMagnitudes.last ?? displacement
            let passesAmplitudeGuard = displacement >= prevMagnitude * minTurnAmplitudeRatio
            if displacement >= turnThreshold && passesAmplitudeGuard {
                directions.append(newDirection)
                directionMagnitudes.append(displacement)
                lastDirectionChangePoint = currentPoint
                strokeAnchorPoint = currentPoint
            }
        } else {
            // 첫 방향: 시작점부터 누적 변위가 full swipe 임계를 넘어야 등록(탭/짧은
            // 떨림은 방향으로 잡지 않음).
            let dx = currentPoint.x - startPoint.x
            let dy = currentPoint.y - startPoint.y
            let displacement = sqrt(dx * dx + dy * dy)
            if displacement >= effectiveThreshold {
                directions.append(newDirection)
                directionMagnitudes.append(displacement)
                lastDirectionChangePoint = currentPoint
                strokeAnchorPoint = currentPoint
            }
        }
    }

    /// 현재 점에서 궤적을 거슬러 올라가 누적 호 길이가 `arcLength` 이상이 되는
    /// 가장 가까운 과거 점의 인덱스. 못 채우면(아직 짧으면) 시작점(0). 점 밀도와
    /// 무관하게 "최근 arcLength 만큼의 궤적"을 가리키므로 기기/터치 샘플링 레이트가
    /// 달라도 방향 판정이 일관된다.
    private func windowReferenceIndex(arcLength: CGFloat) -> Int {
        guard touchPoints.count >= 2 else { return 0 }
        var accumulated: CGFloat = 0
        var index = touchPoints.count - 1
        while index > 0 {
            let p0 = touchPoints[index - 1]
            let p1 = touchPoints[index]
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            accumulated += sqrt(dx * dx + dy * dy)
            index -= 1
            if accumulated >= arcLength { return index }
        }
        return 0
    }

    /// 방향 판정용 window 호 길이(= reversal 거리). 최근 이만큼의 궤적으로 방향을
    /// 본다. 컬럼/keyWidth 보정이 이미 반영된 effectiveReversalThreshold 를 재사용.
    private var effectiveDirectionWindow: CGFloat { effectiveReversalThreshold }

    /// window 벡터의 방향 분류 임계. window 길이의 절반이라 직선에 가까운 궤적은
    /// 통과하고 거의 정지한 구간은 무시한다(최소 1pt 가드).
    private var effectiveDirectionThreshold: CGFloat {
        max(effectiveReversalThreshold * 0.5, 1)
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
    ///
    /// 주의: forceCardinalOnly(ㅣ/ㅡ 키)에서 0.6 을 강제하던 코드를 제거했다.
    /// ㅣ/ㅡ 키는 천지인 멀티스트로크(↑↓↑=ㅛ, ↓↑↓=ㅠ, ←→←=ㅕ, →←→=ㅑ)를
    /// 만드는 유일한 키인데, 거기서 가드를 강제하면 가운데 반전 획(↑/↓)이
    /// 첫 획의 60% 진폭에 못 미쳐 잘려 멀티스트로크가 깨졌다(ㅠ→ㅜ 회귀).
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

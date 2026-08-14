import Foundation
import CoreGraphics

class GestureAnalyzer {
    private struct DirectionSegment {
        var direction: GestureDirection
        var magnitude: CGFloat
        var vector: CGVector
    }

    private var touchPoints: [CGPoint] = []
    private var directions: [GestureDirection] = []
    private var directionMagnitudes: [CGFloat] = []
    /// 각 stroke 의 순 변위(origin → 마지막 관측점). 순정 모아키의 "첫 획 8방향
    /// 잠정 → 후속 획 도착 시 4방향 재해석"(영상 A8-A13 판독)을 재현하려면 첫
    /// 획의 실제 각도가 필요해서, 방향 enum 과 나란히 벡터를 보관한다.
    private var directionVectors: [CGVector] = []
    /// 현재 stroke가 처음 등록된 지점(누적 magnitude/finalize 기준).
    private var lastDirectionChangePoint: CGPoint?
    /// 현재 stroke에서 마지막으로 같은 방향이 관측된 점. 방향이 바뀌면 이 점이
    /// 곧 "turn 지점"이 되어 새 stroke 변위의 측정 기준이 된다. 같은 방향이
    /// 이어질 때마다 최근 점으로 전진한다.
    private var strokeAnchorPoint: CGPoint?
    /// 현재 stroke가 **시작된** 점. `strokeAnchorPoint` 와 달리 같은 방향이
    /// 이어져도 전진하지 않는다.
    ///
    /// `directionMagnitudes` 는 원래 stroke 가 *등록된 순간의* 변위만 담고 있었다.
    /// 등록은 임계를 넘자마자 일어나므로, 60pt 를 그은 획도 임계값(≈20pt)으로
    /// 기록됐다. `normalizeSegments` 의 비율 판정들(jitter 비교, 후행 노이즈)이
    /// 전부 "직전 획 대비"를 전제하는데 그 기준값이 실제 획 길이가 아니라
    /// 임계값이었다는 뜻 — 노이즈와 의도적 획을 비율로 구분할 수 없었다.
    /// 이 점을 기준으로 매 관측마다 magnitude 를 실제 길이로 갱신한다.
    private var strokeOriginPoint: CGPoint?

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

    /// 후행 노이즈 판정용 "직전 획 대비" 비율. 실측 분리(노이즈 0.24~0.32 /
    /// 의도적 마지막 획 0.55)의 중간에 두어 양쪽 모두 여유 마진을 준다.
    private static let trailingNoiseRatio: CGFloat = 0.4

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
        directionVectors.removeAll(keepingCapacity: true)
        lastDirectionChangePoint = nil
        strokeAnchorPoint = nil
        strokeOriginPoint = nil
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
                // stroke 원점은 그대로 두고 magnitude 만 실제 길이로 갱신한다.
                if let origin = strokeOriginPoint, !directionMagnitudes.isEmpty {
                    let ex = currentPoint.x - origin.x
                    let ey = currentPoint.y - origin.y
                    directionMagnitudes[directionMagnitudes.count - 1] = sqrt(ex * ex + ey * ey)
                    directionVectors[directionVectors.count - 1] = CGVector(dx: ex, dy: ey)
                }
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
                directionVectors.append(CGVector(dx: dx, dy: dy))
                lastDirectionChangePoint = currentPoint
                strokeAnchorPoint = currentPoint
                strokeOriginPoint = anchor
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
                directionVectors.append(CGVector(dx: dx, dy: dy))
                lastDirectionChangePoint = currentPoint
                strokeAnchorPoint = currentPoint
                strokeOriginPoint = startPoint
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

    /// 방향 판정용 window 호 길이. 최근 이만큼의 궤적으로 방향을 본다.
    ///
    /// 반전 **등록** 임계(`effectiveReversalThreshold`)와 분리해 swipe 임계의
    /// 절반(보통 길이 기준 ≈ 키폭 20%)으로 고정한다. 원래는 등록 임계를 재사용
    /// 했는데, v2.0 실측 반영으로 등록 임계를 키폭 30%로 올리자 window 도 함께
    /// 커져 방향 분류가 늦어졌고, 그동안 같은-방향 분기가 anchor 를 되돌림 경로
    /// 안으로 전진시켜 등록에 필요한 실제 되돌림이 (window + 임계)로 부풀었다 —
    /// 의도적인 키폭 50% 되돌림(ㅚ/ㅐ)까지 뭉개지는 과소인식
    /// (`test_moderateIntentionalReversal_stillRegisters` 가드).
    private var effectiveDirectionWindow: CGFloat {
        let base: CGFloat = columnId > 0
            ? settings.effectiveSwipeThreshold(forColumn: columnId, keyWidth: keyWidth)
            : settings.swipeProfile.swipeLength.threshold(keyWidth: keyWidth)
        return base * 0.5
    }

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
        finalizeGestureDetailed().directions
    }

    /// finalize 결과 + "첫 획 카디널 재해석" 후보.
    ///
    /// 순정 모아키 실측(영상 A8-A13/C/F 판독): 첫 획은 8방향으로 잠정 분류되고
    /// (↗↖=ㅣ, ↙↘=ㅡ 단독 인정), **후속 획이 등록되는 순간 첫 획을 실제 각도
    /// 기준 4방향으로 재해석한 해석도 함께 성립**한다 — ↗(≤45°) 왕복 = →← = ㅐ,
    /// ↖ 후 ↘ = ←→ = ㅔ, ↙(수직 쪽) ↑↓ = ㅠ 등. `firstStrokeCardinal` 은 그
    /// 재해석에 쓸 첫 획의 4방향 스냅 값이다(첫 획이 카디널이거나 획이 1개면 nil).
    /// 채택 여부는 `VowelResolver` 가 트라이 매칭 결과를 비교해 결정한다.
    func finalizeGestureDetailed() -> (directions: [GestureDirection], firstStrokeCardinal: GestureDirection?) {
        let segments = zip(directions, zip(directionMagnitudes, directionVectors)).map {
            DirectionSegment(direction: $0.0, magnitude: $0.1.0, vector: $0.1.1)
        }
        let normalized = normalizeSegments(segments)
        return (normalized.map { $0.direction },
                firstStrokeCardinal(of: normalized))
    }

    /// 재해석을 발동시키는 두 번째 획의 최소 크기 (keyWidth 대비).
    /// 순정 실측에서 진짜 후속 획은 키 폭의 ~0.9배 이상(ㅐ 왕복 150~290px,
    /// ㅢ 반환 145~405px, ↙↑↓=ㅠ 의 ↑ 168px / 키 피치 154px 기준)이고,
    /// 손 떼며 생기는 호 꼬리는 ~0.45배 이하였다(특성화 테스트 21pt / 50pt).
    /// 0.6 은 양쪽 모두에 마진을 준 중간값 — 꼬리가 재해석을 발동시켜 ㅡ 가
    /// ㅔ 로 승격되는 회귀(`test_upwardArcTailAfterDownLeft…`)를 막는다.
    private static let reinterpretMinSecondStrokeRatio: CGFloat = 0.6

    /// 진행 중(미확정) 제스처의 첫 획 카디널 스냅 — 실시간 미리보기용.
    /// finalize 의 노이즈 트림 전 원시 첫 획을 쓰므로 최종값과 미세하게 다를 수
    /// 있지만, 미리보기는 어차피 획마다 갱신되므로 허용한다.
    func currentFirstStrokeCardinal() -> GestureDirection? {
        guard directions.count >= 2,
              let first = directions.first, first.isDiagonal,
              let vector = directionVectors.first,
              directionMagnitudes.count >= 2,
              directionMagnitudes[1] >= keyWidth * Self.reinterpretMinSecondStrokeRatio
        else { return nil }
        return cardinalSnap(of: vector)
    }

    private func firstStrokeCardinal(of segments: [DirectionSegment]) -> GestureDirection? {
        guard segments.count >= 2,
              let first = segments.first, first.direction.isDiagonal,
              segments[1].magnitude >= keyWidth * Self.reinterpretMinSecondStrokeRatio
        else { return nil }
        return cardinalSnap(of: first.vector)
    }

    /// 벡터를 사용자 섹터 회전을 존중한 4방향(90° 사분면)으로 스냅한다.
    /// 순정 실측에서 첫 획 4방향 경계는 45° 옥탄트와 정합했다(A8-A13 §3-4).
    private func cardinalSnap(of vector: CGVector) -> GestureDirection? {
        GestureDirection.from(
            vector: vector,
            sectors: effectiveSectors,
            rotationOffset: effectiveRotationOffset,
            threshold: 1,
            fourWay: true,
            fillGap: true
        )
    }

    /// Keep intentional turns for 3-stroke gestures (important for ㅙ/ㅞ),
    /// while removing duplicate and jitter-only segments.
    private func normalizeSegments(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var collapsed = collapseConsecutiveDuplicates(segments)
        collapsed = collapseTinyOscillations(collapsed)
        collapsed = collapseCornerBounces(collapsed)
        collapsed = trimTinyLeadingAndTrailingNoise(collapsed)
        return collapsed
    }

    /// 모서리 튕김 흡수 — v2.0 실기기 실측(build 17 이후 잔여 오타) 대응.
    ///
    /// 세로 체인에서 ↓ 를 긋고 →(ㅘ)/←(ㅕ) 로 꺾는 모서리에서 손가락이 살짝
    /// 위로 들리며 작은 ↑ 가 등록되면 ↑↓**↑**→ 가 되고, 트라이가 ㅛ 에서 멈춰
    /// ㅘ/ㅕ 를 가로챈다. 릴리즈 꼬리와 달리 **중간** 획이라 후행 트림이 못
    /// 걷어낸다.
    ///
    /// 순정 판정 모델(실측: turn ≤55° 흡수 + net 변위 즉시 재판정)에서는 이런
    /// 전환부 움직임이 다음 획의 net 벡터에 흡수된다. 여기서는 그 등가로,
    /// **양옆 획보다 훨씬 작은(50% 미만 + 절대 상한) 중간 획**을 다음 획에
    /// 벡터째 합친다. 의도적 체인(↑↓↑↓=ㅠ 등)은 획 크기가 서로 비슷해 비율
    /// 가드에 걸리지 않는다. 대상은 두 갈래:
    ///   - 반전 튕김(직전과 ≥135°): ↓ 끝의 ↑ 들림
    ///   - 인접 곡선(양옆 모두와 ≤45°): ↓→ 코너를 ↘ 로 스치는 경우
    /// 직전==다음(왕복 복귀)은 `collapseTinyOscillations` 소관이라 제외.
    private func collapseCornerBounces(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard segments.count >= 3 else { return segments }

        var result = segments
        // 순수 키폭 비례 (기본 설정 기준 키폭 42%). edgeNoiseCap 처럼
        // `directionChangeThreshold * 0.8`(고정 12pt) 바닥을 섞으면 SE 급
        // 좁은 키(키폭 ~38pt)에서 고정 바닥이 이겨 흡수 창이 키폭 대비
        // 과대해진다 — 반전 등록 임계(키폭 28%)는 이미 키폭 비례라 그대로
        // 1.5배만 쓴다.
        let bounceCap = effectiveReversalThreshold * 1.5
        var index = 1

        while index < result.count - 1 {
            let previous = result[index - 1]
            let current = result[index]
            let next = result[index + 1]

            let gapToPrevious = current.direction.angularGap(to: previous.direction)
            let isReversalBounce = gapToPrevious >= 135
            let isAdjacentCurve = current.direction.isAdjacentTo(previous.direction)
                && current.direction.isAdjacentTo(next.direction)
            let isSmall = current.magnitude <= bounceCap
                && current.magnitude < min(previous.magnitude, next.magnitude) * 0.5

            if (isReversalBounce || isAdjacentCurve) && isSmall
                && next.direction != previous.direction {
                result[index + 1].vector.dx += current.vector.dx
                result[index + 1].vector.dy += current.vector.dy
                let mergedLength = sqrt(result[index + 1].vector.dx * result[index + 1].vector.dx
                                        + result[index + 1].vector.dy * result[index + 1].vector.dy)
                result[index + 1].magnitude = max(next.magnitude, mergedLength)
                result.remove(at: index)
                continue
            }
            index += 1
        }
        return result
    }

    private func collapseConsecutiveDuplicates(_ segments: [DirectionSegment]) -> [DirectionSegment] {
        guard !segments.isEmpty else { return [] }

        var result: [DirectionSegment] = [segments[0]]
        for segment in segments.dropFirst() {
            if segment.direction == result.last?.direction {
                if segment.magnitude > (result.last?.magnitude ?? 0) {
                    result[result.count - 1].magnitude = segment.magnitude
                }
                result[result.count - 1].vector.dx += segment.vector.dx
                result[result.count - 1].vector.dy += segment.vector.dy
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
                result[index - 1].vector.dx += current.vector.dx + next.vector.dx
                result[index - 1].vector.dy += current.vector.dy + next.vector.dy
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

        // 후행 노이즈: 인접(≤45°) 조건을 요구하지 않는다.
        //
        // 손가락을 떼며 튕기는 꼬리는 방향이 급격한 경우가 더 흔하다 — 실측에서
        // ↙ 뒤의 ↗(180°)·↑(135°)·↘(90°) 꼬리가 전부 인접이 아니어서 트림을
        // 빠져나갔고, 그 결과 ㅡ 가 ㅢ/ㅗ/ㅘ 로 승격돼 "'으'가 '워'로" 오타가 났다
        // (앱스토어 리뷰 3건, `GestureOverDetectionCharacterizationTests` 재현).
        // 인접 조건은 "완만하게 흘러내린 꼬리"만 잡아 의도와 정반대였다.
        //
        // 크기 상한(`edgeNoiseCap`)은 그대로 두므로 의도적으로 그은 마지막 획은
        // 남는다 — ㅙ(↑→←)/ㅞ(↓←→)의 짧은 마지막 획(실측 25pt)이 회귀 가드다.
        // 꼬리는 한 획이 아닐 수 있다 — 손을 떼며 그리는 호는 ↑ 후 → 처럼 두
        // 조각으로 등록된다(실측). 하나만 지우면 남은 조각이 승격을 일으키므로
        // 조건을 만족하는 동안 반복해서 걷어낸다.
        //
        // 판정은 **절대 크기 + 직전 획 대비 비율**을 모두 본다.
        // 절대 크기만 쓰면 ㅒ(→←→←)/ㅖ/ㅙ/ㅞ 처럼 마지막 획이 짧아지기 쉬운
        // 의도적 4·3획 모음이 함께 잘린다(실측: 30pt 마지막 획이 사라져 얘→야,
        // 왜→와). 비율만 쓰면 짧은 진입 획 뒤의 꼬리를 놓친다.
        // 실측 분리: 노이즈 꼬리 15~20pt / 진입 63pt = 0.24~0.32,
        //            의도적 마지막 획 30pt / 직전 55pt = 0.55.
        // 인접(≤45°) 꼬리는 기존대로 비율과 무관하게 제거한다(완만한 흘림).
        //
        // ⚠️ 비율을 절대 크기와 분리해 단독 컷으로 쓰지 말 것: 재촬영 S2 판독
        // (2026-08-14)에서 순정은 300px+ 진입 후 60~80px 되돌림(비율 0.2~0.27)도
        // 전부 획으로 인정했다 — 순정의 되돌림 판정은 절대 크기(~키폭 30%,
        // `reversalThresholdRatio` 참고)이며, 여기 트림은 그 하한 아래로 등록된
        // 경계 사례만 정리하는 안전망이다.
        while result.count > 1, let last = result.last, let previous = result.dropLast().last {
            let isTinyAbsolute = last.magnitude <= edgeNoiseCap
            let isTinyRelative = last.magnitude < previous.magnitude * Self.trailingNoiseRatio
            guard isTinyAbsolute && (isTinyRelative || last.direction.isAdjacentTo(previous.direction)) else { break }
            result.removeLast()
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

    /// 획 하나의 계측값 — 긋기 테스트 화면의 "획별 측정" 표시용.
    /// 실기기 실측(T2)에서 "어느 각도에서 다른 모음으로 넘어가는지 확인 불가"
    /// 피드백을 받아 추가했다.
    struct StrokeInfo: Identifiable {
        let id: Int
        let direction: GestureDirection
        let magnitude: CGFloat
        let vector: CGVector

        /// 수학 좌표 각도(0° = 오른쪽, 반시계 방향 +, 0..<360). 화면 y 는
        /// 아래로 증가하므로 dy 부호를 뒤집는다 — `DirectionSector.centerAngle`
        /// 과 같은 규약이라 섹터 경계 각도와 직접 비교할 수 있다.
        var angleDegrees: Double {
            let deg = atan2(Double(-vector.dy), Double(vector.dx)) * 180 / .pi
            return deg < 0 ? deg + 360 : deg
        }
    }

    /// 등록된 원시 획 목록(노이즈 트림 전) — 진행 중 실시간 표시용.
    func currentStrokeInfos() -> [StrokeInfo] {
        zip(directions, zip(directionMagnitudes, directionVectors)).enumerated().map { index, entry in
            StrokeInfo(id: index, direction: entry.0, magnitude: entry.1.0, vector: entry.1.1)
        }
    }

    /// finalize 와 동일한 노이즈 트림을 거친 획 목록 — 손을 뗀 뒤 "최종" 표시용.
    /// `finalizeGestureDetailed()` 처럼 상태를 바꾸지 않는다.
    func finalizedStrokeInfos() -> [StrokeInfo] {
        let segments = zip(directions, zip(directionMagnitudes, directionVectors)).map {
            DirectionSegment(direction: $0.0, magnitude: $0.1.0, vector: $0.1.1)
        }
        return normalizeSegments(segments).enumerated().map { index, segment in
            StrokeInfo(id: index, direction: segment.direction,
                       magnitude: segment.magnitude, vector: segment.vector)
        }
    }
}

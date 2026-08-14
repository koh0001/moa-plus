import Foundation
import CoreGraphics

/// Unified gesture settings combining swipe profile and column overrides
struct GestureSettings: Codable, Equatable {
    var swipeProfile: SwipeProfile = .bothHands
    var columnOverrides: [ColumnGestureOverride] = ColumnGestureOverride.defaults

    /// Distance (in points) the finger must move from the previous
    /// direction-change point before a *non-opposite* direction switch
    /// is recorded. Larger values reject end-of-swipe lateral drift
    /// (the ㅗ → ㅘ misclassification reported in PR G15).
    var directionChangeThreshold: CGFloat = KeyboardMetrics.directionChangeThreshold

    /// Fraction of the effective swipe threshold to use for opposite-
    /// direction reversals (↑→↓, ←→→, etc.). Reversals get a smaller
    /// threshold so multi-stroke vowels (ㅚ/ㅞ) stay fluid, and the value
    /// scales with the user's swipeLength preset.
    ///
    /// 기본 0.70 = 보통 길이(키폭 40%) 기준 **키폭의 28%**. 순정 모아키 adb
    /// 정밀 실측(2026-08-14, 갤럭시 S22+ 터치 주입)의 되돌림 인정 하한
    /// **42px = 키 너비 150px 의 28%** 에 맞춘 값이다 (41px 미등록 / 42px 등록,
    /// 진입 획 길이 무관 = 절대 임계). 이전 기본 0.5(키폭 20%)는 순정보다
    /// 민감해, v2.0 실기기 실측에서 손 떼는 꼬리가 획으로 등록돼
    /// ㅚ→ㅛ(a5)·ㅕ→ㅖ(b6) 승격 오타를 만들었다.
    var reversalThresholdRatio: CGFloat = 0.70

    /// 멀티스트로크 모음(ㅛ ㅑ ㅕ 등)을 원점 복귀 없이 "큰 각도 방향 전환"만으로
    /// 인식하는 민감도. 0 = 끔(기본 — ㅗ/ㅜ/ㅏ/ㅓ 단일 안정성 최우선, 기존 동작 보존),
    /// 1 = 보통, 2 = 민감. 높일수록 작은 왕복도 새 스트로크로 등록되지만 단일 모음이
    /// 복합 모음(ㅗ→ㅚ→ㅛ 등)으로 과승격될 위험이 커진다. 떨림 오인식은 진폭 비율
    /// 가드(직전 스트로크 대비 일정 비율 이상일 때만 등록)로 완화한다.
    var multiStrokeTurnSensitivity: Int = 0

    /// Get effective swipe threshold for a specific column. `keyWidth`
    /// must be the live center-key width measured by the view layer so
    /// the same swipeLength preset behaves consistently across iPhone
    /// SE through Pro Max (and iPad).
    func effectiveSwipeThreshold(forColumn columnId: Int, keyWidth: CGFloat) -> CGFloat {
        let baseThreshold = swipeProfile.swipeLength.threshold(keyWidth: keyWidth)
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        return baseThreshold * CGFloat(override.outwardDistanceMultiplier)
    }

    /// Effective reversal threshold = effective swipe threshold × ratio.
    /// Inherits per-column outward-distance multipliers automatically so
    /// columns the user has tuned to be more/less sensitive get matching
    /// reversal sensitivity. `columnId == 0` returns the base.
    func effectiveReversalThreshold(forColumn columnId: Int, keyWidth: CGFloat) -> CGFloat {
        let base: CGFloat = {
            if columnId > 0 {
                return effectiveSwipeThreshold(forColumn: columnId, keyWidth: keyWidth)
            }
            return swipeProfile.swipeLength.threshold(keyWidth: keyWidth)
        }()
        return base * reversalThresholdRatio
    }

    /// Effective direction-change threshold for a specific column. The
    /// global `directionChangeThreshold` is the base; columns can apply
    /// a non-zero `directionChangeThresholdDelta` to be stricter or
    /// looser about second-stroke registration.
    func effectiveDirectionChangeThreshold(forColumn columnId: Int) -> CGFloat {
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        let adjusted = directionChangeThreshold + CGFloat(override.directionChangeThresholdDelta)
        return max(0, adjusted)
    }

    /// Get effective rotation offset for a specific column
    func effectiveRotationOffset(forColumn columnId: Int) -> Double {
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        return override.rotationOffsetDeg
    }

    /// Get ㅣ sector width delta for a specific column
    func verticalIWidthDelta(forColumn columnId: Int) -> Double {
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        return override.verticalIWidthDelta
    }

    /// Get ㅡ sector width delta for a specific column
    func horizontalEuWidthDelta(forColumn columnId: Int) -> Double {
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        return override.horizontalEuWidthDelta
    }

    static let `default` = GestureSettings()
}

// MARK: - Forward-compatible decoding
//
// Every field decoded with `decodeIfPresent` + default so older persisted JSON
// predating a field (e.g. `multiStrokeTurnSensitivity`) decodes cleanly instead
// of throwing `keyNotFound` and wiping the user's gesture settings via
// `load(...) ?? .default`. In an extension to preserve the memberwise init.
extension GestureSettings {
    private enum CodingKeys: String, CodingKey {
        case swipeProfile, columnOverrides, directionChangeThreshold
        case reversalThresholdRatio, multiStrokeTurnSensitivity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        swipeProfile = try c.decodeIfPresent(SwipeProfile.self, forKey: .swipeProfile) ?? .bothHands
        columnOverrides = try c.decodeIfPresent([ColumnGestureOverride].self, forKey: .columnOverrides) ?? ColumnGestureOverride.defaults
        directionChangeThreshold = try c.decodeIfPresent(CGFloat.self, forKey: .directionChangeThreshold) ?? KeyboardMetrics.directionChangeThreshold
        // 마이그레이션: 0.5 는 v2.0 까지의 기본값이고 이 값을 바꿀 UI 가 없으므로,
        // 저장된 0.5 는 "사용자 선택"이 아니라 옛 기본값이다 — 새 기본(0.70,
        // 순정 adb 실측 정합)으로 승격해 기존 설치에도 튜닝이 도달하게 한다.
        let storedReversal = try c.decodeIfPresent(CGFloat.self, forKey: .reversalThresholdRatio)
        reversalThresholdRatio = (storedReversal == nil || storedReversal == 0.5) ? 0.70 : storedReversal!
        multiStrokeTurnSensitivity = try c.decodeIfPresent(Int.self, forKey: .multiStrokeTurnSensitivity) ?? 0
    }
}

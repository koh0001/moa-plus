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
    /// threshold so multi-stroke vowels (ㅚ/ㅞ) stay fluid, but the value
    /// now scales with the user's swipeLength preset — previously this
    /// was a hardcoded 10pt and would not respond to "긋기 길이 길게".
    /// Default 0.5 keeps the historical 20pt → 10pt ratio.
    var reversalThresholdRatio: CGFloat = 0.5

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
        reversalThresholdRatio = try c.decodeIfPresent(CGFloat.self, forKey: .reversalThresholdRatio) ?? 0.5
        multiStrokeTurnSensitivity = try c.decodeIfPresent(Int.self, forKey: .multiStrokeTurnSensitivity) ?? 0
    }
}

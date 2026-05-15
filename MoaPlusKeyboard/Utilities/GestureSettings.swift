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

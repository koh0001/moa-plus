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
    /// Opposite reversals (e.g. ↑ → ↓ for ㅚ) keep using the lower
    /// `KeyboardMetrics.reversalThreshold` so multi-stroke vowels stay
    /// fluid.
    var directionChangeThreshold: CGFloat = KeyboardMetrics.directionChangeThreshold

    /// Get effective swipe threshold for a specific column. `keyWidth`
    /// must be the live center-key width measured by the view layer so
    /// the same swipeLength preset behaves consistently across iPhone
    /// SE through Pro Max (and iPad).
    func effectiveSwipeThreshold(forColumn columnId: Int, keyWidth: CGFloat) -> CGFloat {
        let baseThreshold = swipeProfile.swipeLength.threshold(keyWidth: keyWidth)
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        return baseThreshold * CGFloat(override.outwardDistanceMultiplier)
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

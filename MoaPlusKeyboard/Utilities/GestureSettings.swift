import Foundation
import CoreGraphics

/// Unified gesture settings combining swipe profile and column overrides
struct GestureSettings: Codable, Equatable {
    var swipeProfile: SwipeProfile = .bothHands
    var columnOverrides: [ColumnGestureOverride] = ColumnGestureOverride.defaults

    /// Edge-specific outward distance multipliers
    var leftEdgeOutwardDistanceMultiplier: Double = 0.85
    var rightEdgeOutwardDistanceMultiplier: Double = 0.85

    /// Long-press configuration
    var longPressDelayMs: Int = 500
    var movementToleranceForLongPress: CGFloat = 10.0

    /// Get effective swipe threshold for a specific column
    func effectiveSwipeThreshold(forColumn columnId: Int) -> CGFloat {
        let baseThreshold = swipeProfile.swipeLength.threshold
        let override = ColumnGestureOverride.override(forColumn: columnId, from: columnOverrides)
        return baseThreshold * CGFloat(override.outwardDistanceMultiplier)
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

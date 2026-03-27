import Foundation

/// Per-column gesture override for improving edge-key accuracy
struct ColumnGestureOverride: Codable, Equatable {
    /// Column index (1-based: 1=leftmost, 5=rightmost)
    let columnId: Int

    /// Rotation offset applied to all angle sectors for this column (degrees)
    var rotationOffsetDeg: Double = 0.0

    /// Additional width delta for ㅣ (vertical) recognition sector (degrees)
    var verticalIWidthDelta: Double = 0.0

    /// Additional width delta for ㅡ (horizontal) recognition sector (degrees)
    var horizontalEuWidthDelta: Double = 0.0

    /// Distance multiplier for outward swipes (>1.0 = more lenient)
    var outwardDistanceMultiplier: Double = 1.0

    /// Whether this column uses override values or falls back to global
    var isEnabled: Bool = true

    /// Default overrides for each column
    static let defaults: [ColumnGestureOverride] = [
        // Column 1 (ㅃ/ㅂ/ㅁ/ㅋ) - leftmost, needs outward compensation
        ColumnGestureOverride(columnId: 1, rotationOffsetDeg: 5.0, verticalIWidthDelta: 3.0, horizontalEuWidthDelta: 2.0, outwardDistanceMultiplier: 0.85),
        // Column 2 (ㅉ/ㅈ/ㄴ/ㅌ) - near-left, mild compensation
        ColumnGestureOverride(columnId: 2, rotationOffsetDeg: 2.0, verticalIWidthDelta: 1.5, horizontalEuWidthDelta: 1.0),
        // Column 3 (ㄸ/ㄷ/ㅇ/ㅊ) - center, use global defaults
        ColumnGestureOverride(columnId: 3),
        // Column 4 (ㄲ/ㄱ/ㄹ/ㅍ) - near-right, mild compensation
        ColumnGestureOverride(columnId: 4, rotationOffsetDeg: -2.0, verticalIWidthDelta: 1.5, horizontalEuWidthDelta: 1.0),
        // Column 5 (ㅆ/ㅅ/ㅎ) - rightmost, needs outward compensation
        ColumnGestureOverride(columnId: 5, rotationOffsetDeg: -5.0, verticalIWidthDelta: 3.0, horizontalEuWidthDelta: 2.0, outwardDistanceMultiplier: 0.85),
    ]

    /// Get the override for a given column, returning the default if not found
    static func override(forColumn columnId: Int, from overrides: [ColumnGestureOverride]?) -> ColumnGestureOverride {
        if let overrides = overrides,
           let override = overrides.first(where: { $0.columnId == columnId }),
           override.isEnabled {
            return override
        }
        return defaults.first(where: { $0.columnId == columnId }) ?? ColumnGestureOverride(columnId: columnId)
    }
}

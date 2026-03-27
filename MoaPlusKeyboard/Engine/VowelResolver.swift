import Foundation

class VowelResolver {
    private let patternTrie = VowelPattern.patternTrie

    /// Custom diagonal mappings from SwipeProfile (updated per gesture)
    var swipeProfile: SwipeProfile = .bothHands

    struct Resolution {
        let vowel: Jungseong?
        let hasMoreMatches: Bool
    }

    func resolve(directions: [GestureDirection]) -> Resolution {
        guard !directions.isEmpty else {
            return Resolution(vowel: nil, hasMoreMatches: false)
        }

        // Check if first stroke is a diagonal with direct vowel mapping
        if directions.count == 1, let directVowel = resolveDirectDiagonal(directions[0]) {
            return Resolution(vowel: directVowel, hasMoreMatches: true)
        }

        let normalized = normalizeForMatching(directions)
        let match = patternTrie.match(normalized)
        return Resolution(vowel: match.vowel, hasMoreMatches: match.hasLongerMatch)
    }

    // For real-time feedback during gesture
    func peekVowel(directions: [GestureDirection]) -> Jungseong? {
        guard !directions.isEmpty else { return nil }

        // Direct diagonal mapping check
        if directions.count == 1, let directVowel = resolveDirectDiagonal(directions[0]) {
            return directVowel
        }

        let normalized = normalizeForMatching(directions)
        return patternTrie.match(normalized).vowel
    }

    // Check if current directions could potentially match a vowel
    func hasPotentialMatch(directions: [GestureDirection]) -> Bool {
        guard !directions.isEmpty else { return false }

        if directions.count == 1 && resolveDirectDiagonal(directions[0]) != nil {
            return true
        }

        let normalized = normalizeForMatching(directions)
        let match = patternTrie.match(normalized)
        return match.vowel != nil || match.hasLongerMatch
    }

    // MARK: - Direct diagonal vowel mapping

    /// Resolve a diagonal direction to a vowel based on SwipeProfile mapping
    private func resolveDirectDiagonal(_ direction: GestureDirection) -> Jungseong? {
        let mapping: DiagonalMapping
        switch direction {
        case .upLeft:    mapping = swipeProfile.upLeftMapping
        case .upRight:   mapping = swipeProfile.upRightMapping
        case .downLeft:  mapping = swipeProfile.downLeftMapping
        case .downRight: mapping = swipeProfile.downRightMapping
        default: return nil
        }

        let vowel: Jungseong?
        switch mapping {
        case .vowelI:  vowel = Jungseong.ㅣ
        case .vowelEu: vowel = Jungseong.ㅡ
        case .vowelO:  vowel = Jungseong.ㅗ
        case .vowelU:  vowel = Jungseong.ㅜ
        case .vowelA:  vowel = Jungseong.ㅏ
        case .vowelEo: vowel = Jungseong.ㅓ
        case .normalizeUp, .normalizeDown, .normalizeLeft, .normalizeRight:
            vowel = nil // Handled by normalization path
        case .disabled:
            vowel = nil
        }
        return vowel
    }

    /// Get the normalized direction for a diagonal based on its mapping
    private func normalizedDirection(for direction: GestureDirection) -> GestureDirection {
        let mapping: DiagonalMapping
        switch direction {
        case .upLeft:    mapping = swipeProfile.upLeftMapping
        case .upRight:   mapping = swipeProfile.upRightMapping
        case .downLeft:  mapping = swipeProfile.downLeftMapping
        case .downRight: mapping = swipeProfile.downRightMapping
        default: return direction
        }

        switch mapping {
        case .normalizeUp, .vowelO:    return .up
        case .normalizeDown, .vowelU:  return .down
        case .normalizeLeft, .vowelEo: return .left
        case .normalizeRight, .vowelA: return .right
        case .vowelI:  return .upRight   // Normalize to ↗ so pattern trie recognizes ㅣ patterns
        case .vowelEu: return .downRight // Normalize to ↘ so pattern trie recognizes ㅡ patterns
        case .disabled: return direction
        }
    }

    // MARK: - Normalization

    /// Normalization rules:
    /// 1. First stroke: diagonals resolved via SwipeProfile mapping (normalize or direct vowel).
    /// 2. From the second stroke onward, diagonals are mapped to a single cardinal axis.
    /// 3. Consecutive identical directions collapse into one stroke.
    private func normalizeForMatching(_ directions: [GestureDirection]) -> [GestureDirection] {
        guard !directions.isEmpty else { return [] }

        var normalized: [GestureDirection] = []
        normalized.reserveCapacity(directions.count)

        for (index, direction) in directions.enumerated() {
            let next: GestureDirection
            if index == 0 {
                next = normalizeFirstStroke(direction)
            } else {
                next = normalizeTrailingStroke(direction, previous: normalized.last)
            }

            // Treat repeated same-direction segments as one stroke.
            if normalized.last != next {
                normalized.append(next)
            }
        }

        return normalized
    }

    private func normalizeFirstStroke(_ direction: GestureDirection) -> GestureDirection {
        guard direction.isDiagonal else { return direction }
        return normalizedDirection(for: direction)
    }

    private func normalizeTrailingStroke(_ direction: GestureDirection,
                                         previous: GestureDirection?) -> GestureDirection {
        guard direction.isDiagonal else { return direction }

        guard let (vertical, horizontal) = diagonalComponents(of: direction) else {
            return direction
        }

        guard let previous else {
            return vertical
        }

        // If the previous stroke is horizontal, keep the diagonal's horizontal intent.
        if previous == .left || previous == .right {
            return horizontal
        }

        // For vertical previous strokes, choose horizontal only when the diagonal
        // shares the same vertical intent (e.g. ↑ then ↗ => →, ↓ then ↘ => →).
        if previous == vertical {
            return horizontal
        }

        return vertical
    }

    private func diagonalComponents(of direction: GestureDirection) -> (vertical: GestureDirection, horizontal: GestureDirection)? {
        switch direction {
        case .upRight:   return (.up, .right)
        case .upLeft:    return (.up, .left)
        case .downRight: return (.down, .right)
        case .downLeft:  return (.down, .left)
        default:         return nil
        }
    }
}

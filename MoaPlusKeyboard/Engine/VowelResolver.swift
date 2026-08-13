import Foundation

class VowelResolver {
    private let patternTrie = VowelPattern.patternTrie

    /// Custom diagonal mappings from SwipeProfile (updated per gesture)
    var swipeProfile: SwipeProfile = .bothHands

    struct Resolution {
        let vowel: Jungseong?
        let hasMoreMatches: Bool
    }

    /// - Parameter firstStrokeCardinal: 첫 획(대각선)의 실제 각도를 4방향으로
    ///   스냅한 값 (`GestureAnalyzer.finalizeGestureDetailed()`). 순정 모아키는
    ///   첫 획을 8방향으로 잠정 분류했다가 **후속 획이 오면 4방향으로 재해석**
    ///   한다(영상 A8-A13/C/F 실측: ↗ 왕복=ㅐ, ↖↘=ㅔ, ↙↑↓=ㅠ). 두 해석을 모두
    ///   트라이에 넣어 **더 많은 간선을 따라간 쪽**을 채택하고, 동률이면 기존
    ///   해석을 유지한다 — ↙↗=ㅢ(천지인 ㅡ+ㅣ)가 재해석(←→=ㅔ)에 밀리지 않게.
    func resolve(directions: [GestureDirection],
                 firstStrokeCardinal: GestureDirection? = nil) -> Resolution {
        guard !directions.isEmpty else {
            return Resolution(vowel: nil, hasMoreMatches: false)
        }

        // Check if first stroke is a diagonal with direct vowel mapping
        if directions.count == 1, let directVowel = resolveDirectDiagonal(directions[0]) {
            return Resolution(vowel: directVowel, hasMoreMatches: true)
        }

        let normalized = normalizeForMatching(directions)
        let match = patternTrie.match(normalized)

        if let alt = cardinalReinterpretation(directions, firstStrokeCardinal: firstStrokeCardinal) {
            let altMatch = patternTrie.match(alt)
            if altMatch.vowel != nil,
               match.vowel == nil || altMatch.matchedCount > match.matchedCount {
                return Resolution(vowel: altMatch.vowel, hasMoreMatches: altMatch.hasLongerMatch)
            }
        }

        return Resolution(vowel: match.vowel, hasMoreMatches: match.hasLongerMatch)
    }

    /// 첫 획을 4방향 스냅으로 바꾼 대안 시퀀스. 첫 획이 대각선이고 후속 획이
    /// 있을 때만 성립한다.
    private func cardinalReinterpretation(_ directions: [GestureDirection],
                                          firstStrokeCardinal: GestureDirection?) -> [GestureDirection]? {
        guard let cardinal = firstStrokeCardinal,
              cardinal.isCardinal,
              directions.count >= 2,
              directions[0].isDiagonal else { return nil }
        return normalizeForMatching([cardinal] + directions.dropFirst())
    }

    /// Single-stroke direction → Jungseong, mirroring the first-stroke
    /// branch of `resolve(directions:)`. Cardinals map directly
    /// (←ㅓ →ㅏ ↑ㅗ ↓ㅜ); diagonals follow the active SwipeProfile's
    /// DiagonalMapping. Used by slot-B vowel key (no multi-stroke compound).
    /// Returns nil for `.disabled` mappings.
    func resolveSingleStroke(direction: GestureDirection) -> Jungseong? {
        if let directVowel = resolveDirectDiagonal(direction) {
            return directVowel
        }
        switch direction {
        case .left:  return .ㅓ
        case .right: return .ㅏ
        case .up:    return .ㅗ
        case .down:  return .ㅜ
        case .upLeft, .upRight, .downLeft, .downRight:
            // Diagonal had no direct vowel mapping (e.g. .normalize* or
            // .disabled). Fall back to the normalized cardinal.
            switch normalizedDirection(for: direction) {
            case .left:  return .ㅓ
            case .right: return .ㅏ
            case .up:    return .ㅗ
            case .down:  return .ㅜ
            default:     return nil
            }
        }
    }

    // For real-time feedback during gesture
    func peekVowel(directions: [GestureDirection],
                   firstStrokeCardinal: GestureDirection? = nil) -> Jungseong? {
        guard !directions.isEmpty else { return nil }

        // Direct diagonal mapping check
        if directions.count == 1, let directVowel = resolveDirectDiagonal(directions[0]) {
            return directVowel
        }

        // 미리보기도 입력 확정(resolve)과 같은 재해석 우선순위를 쓴다.
        return resolve(directions: directions, firstStrokeCardinal: firstStrokeCardinal).vowel
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
                next = normalizeTrailingStroke(direction, previous: normalized.last,
                                               first: normalized.first)
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
                                         previous: GestureDirection?,
                                         first: GestureDirection? = nil) -> GestureDirection {
        // 순정 실측(영상 R2 6/6 + F1 #8·F3 #3 + B2 #7): **수평으로 시작한**
        // 제스처에서 직각(↑/↓) 후속 획은 수평 반전으로 스냅된다 —
        // →↓/→↑=ㅐ, ←↑/←↓=ㅔ, →↓→=ㅑ. 수평 시작 트라이에는 직각 간선이
        // 없기 때문. 반전으로 접어 주면 나머지는 기존 트라이(→←=ㅐ …)가 처리.
        // 수직 시작 제스처에는 적용하지 않는다 — 직각 간선이 실재하고(↑→=ㅘ,
        // ↓←=ㅝ), 중간 수평 노이즈 뒤의 수직 획을 접으면 ㅛ(↑←↓↑ 등)의 skip
        // 관대함이 깨진다. 순정도 수직 시작에서 무효 직각 획은 그냥 버린다
        // (영상 D4 att04: ↑→ 후 진짜 ↓ 획 폐기).
        if direction == .up || direction == .down,
           previous == .left || previous == .right,
           first == .left || first == .right {
            return previous == .left ? .right : .left
        }
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

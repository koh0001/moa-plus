import Foundation

struct VowelPattern {
    let vowel: Jungseong
    let directions: [GestureDirection]

    init(_ vowel: Jungseong, _ directions: GestureDirection...) {
        self.vowel = vowel
        self.directions = directions
    }

    static let allPatterns: [VowelPattern] = [
        // Basic vowels (왼쪽 대각선만 정규화: ↖→↑, ↙→↓)
        VowelPattern(.ㅗ, .up),                           // ↑ (↖도 정규화로 처리됨)
        VowelPattern(.ㅜ, .down),                         // ↓ (↙도 정규화로 처리됨)
        VowelPattern(.ㅏ, .right),                        // →
        VowelPattern(.ㅓ, .left),                         // ←
        VowelPattern(.ㅡ, .downRight),                    // ↘ → ㅡ
        VowelPattern(.ㅣ, .upRight),                      // ↗ → ㅣ

        // Y-vowels (triple direction)
        VowelPattern(.ㅛ, .up, .down, .up),               // ↑↓↑
        VowelPattern(.ㅠ, .down, .up, .down),             // ↓↑↓
        VowelPattern(.ㅑ, .right, .left, .right),         // →←→
        VowelPattern(.ㅕ, .left, .right, .left),          // ←→←

        // Complex vowels (diphthongs)
        VowelPattern(.ㅘ, .up, .right),                   // ↑→
        VowelPattern(.ㅙ, .up, .right, .left),            // ↑→←
        VowelPattern(.ㅝ, .down, .left),                  // ↓←
        VowelPattern(.ㅞ, .down, .left, .right),          // ↓←→
        VowelPattern(.ㅚ, .up, .down),                    // ↑↓
        VowelPattern(.ㅟ, .down, .up),                    // ↓↑

        // 세로 체인 확장 (순정 실측: 영상 A8-A13 판독, 팝업 고→괴→과→괘 /
        // 보→뵈→뵤→뷰 로 확인). ㅚ(↑↓) 뒤에 →가 오면 ㅘ, 이어 ←면 ㅙ,
        // ㅛ(↑↓↑) 뒤에 ↓가 오면 ㅠ. ㅠ 뒤 간선은 순정에도 없음(4획째 무시).
        VowelPattern(.ㅘ, .up, .down, .right),            // ↑↓→
        VowelPattern(.ㅙ, .up, .down, .right, .left),     // ↑↓→←
        VowelPattern(.ㅠ, .up, .down, .up, .down),        // ↑↓↑↓

        // 세로 체인 ← 갈래 (순정 실측: 영상 R7 — ↑↓←→=ㅖ 5/5, 팝업
        // 오→외→여→예 / 두→뒤→둬→뒈). ㅚ 뒤 ←는 ㅗ+ㅓ 조합이 없어 ㅗ를
        // 버리고 ㅕ로 재출발, ㅟ 뒤 ←는 ㅜ+ㅓ=ㅝ 가 유효해 ㅜ 유지.
        // ⚠️ ↑↓ 끝 ← 꼬리가 ㅚ→ㅕ 로 승격되는 회귀 축 —
        // `testE2E_upDownWithSmallLeftTail_staysOe` 가드 먼저 확인.
        VowelPattern(.ㅕ, .up, .down, .left),             // ↑↓←
        VowelPattern(.ㅖ, .up, .down, .left, .right),     // ↑↓←→
        VowelPattern(.ㅝ, .down, .up, .left),             // ↓↑←
        VowelPattern(.ㅞ, .down, .up, .left, .right),     // ↓↑←→

        // Ae/E vowels
        VowelPattern(.ㅐ, .right, .left),                 // →←
        VowelPattern(.ㅒ, .right, .left, .right, .left),  // →←→←
        VowelPattern(.ㅔ, .left, .right),                 // ←→
        VowelPattern(.ㅖ, .left, .right, .left, .right),  // ←→←→

        // Eu-i (ㅡ + ㅣ)
        VowelPattern(.ㅢ, .downRight, .upLeft),           // ↘↖ (오른쪽아래-왼쪽위)
        VowelPattern(.ㅢ, .downRight, .up),               // ↘↑ (오른쪽아래-위)
    ]

    // Build a trie for efficient pattern matching
    static let patternTrie: PatternTrie = {
        let trie = PatternTrie()
        for pattern in allPatterns {
            trie.insert(pattern)
        }
        return trie
    }()
}

// Trie for efficient pattern matching
class PatternTrie {
    class Node {
        var children: [GestureDirection: Node] = [:]
        var vowel: Jungseong?
        var isPartialMatch: Bool = false // True if this is a prefix of a longer pattern
    }

    let root = Node()

    func insert(_ pattern: VowelPattern) {
        var current = root
        for (index, direction) in pattern.directions.enumerated() {
            if current.children[direction] == nil {
                current.children[direction] = Node()
            }
            current = current.children[direction]!

            // Mark intermediate nodes as partial matches
            if index < pattern.directions.count - 1 {
                current.isPartialMatch = true
            }
        }
        current.vowel = pattern.vowel
    }

    struct MatchResult {
        let vowel: Jungseong?
        let consumedCount: Int
        let hasLongerMatch: Bool
        /// 트라이에서 실제로 따라간 간선 수 (skip 된 획은 제외). 두 해석 후보의
        /// "얼마나 잘 맞았나"를 비교하는 기준 — consumedCount 는 skip 을 포함해
        /// 부풀 수 있어 비교 지표로 부적합하다.
        let matchedCount: Int
    }

    func match(_ directions: [GestureDirection]) -> MatchResult {
        var current = root
        var lastMatch: (vowel: Jungseong, count: Int)?
        var hasLongerMatch = false
        var matchedCount = 0

        for (index, direction) in directions.enumerated() {
            guard let next = current.children[direction] else {
                // Skip an unmatched stroke instead of aborting, so a stray /
                // noise stroke mid-gesture (e.g. ↑←↓↑ for ㅛ) doesn't void the
                // whole input — error tolerance for multi-stroke vowels.
                continue
            }
            current = next
            matchedCount += 1

            if let vowel = current.vowel {
                lastMatch = (vowel, index + 1)
            }

            if index == directions.count - 1 && !current.children.isEmpty {
                hasLongerMatch = true
            }
        }

        if let match = lastMatch {
            return MatchResult(vowel: match.vowel, consumedCount: match.count, hasLongerMatch: hasLongerMatch, matchedCount: matchedCount)
        }

        return MatchResult(vowel: nil, consumedCount: 0, hasLongerMatch: !current.children.isEmpty, matchedCount: matchedCount)
    }
}

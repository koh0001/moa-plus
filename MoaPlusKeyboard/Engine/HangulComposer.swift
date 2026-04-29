import Foundation

class HangulComposer {
    enum State: Equatable {
        case empty
        case choseong(Choseong)
        case choseongJungseong(Choseong, Jungseong)
        case complete(Choseong, Jungseong, Jongseong)
        /// Vowel(s) typed without a leading consonant. Held pending so that
        /// further 천지인 (cheonjiin) input can compose into a richer vowel
        /// (e.g. ㅡ → ㅢ, ㅣ + ㆍ → ㅏ). Committed when a non-combinable
        /// input arrives.
        case standaloneVowel(Jungseong)
        /// Accumulating ㆍ strokes (1 or 2). Used for the 천지인 3-stroke
        /// patterns where ㆍ leads (ㆍ+ㆍ+ㅣ→ㅕ, ㆍ+ㆍ+ㅡ→ㅛ). Optional
        /// choseong rides along so ㅇ+ㆍ+ㆍ+ㅣ→여, etc.
        case dotPending(choseong: Choseong?, dotCount: Int)
    }

    private(set) var state: State = .empty
    private(set) var composedText: String = ""

    var currentComposingCharacter: Character? {
        switch state {
        case .empty:
            return nil
        case .choseong(let cho):
            return cho.compatibilityCharacter
        case .choseongJungseong(let cho, let jung):
            return HangulConstants.composeSyllable(choseong: cho, jungseong: jung)
        case .complete(let cho, let jung, let jong):
            return HangulConstants.composeSyllable(choseong: cho, jungseong: jung, jongseong: jong)
        case .standaloneVowel(let jung):
            return jung.compatibilityCharacter
        case .dotPending(let cho, _):
            // dotPending may render as multiple Characters ("ㄱㆍㆍ") so a
            // single Character can't represent it. Callers needing the full
            // visual sequence should use `composingDisplay` / `displayText`.
            // We return the leading consonant (or nil) here for legacy
            // single-Character consumers; ViewModel uses `composingDisplay`.
            return cho?.compatibilityCharacter
        }
    }

    /// Full composing string (may be multi-character for dotPending).
    /// Use this when rendering composing text to the host text field.
    var composingDisplay: String {
        switch state {
        case .dotPending(let cho, let count):
            let dots = String(repeating: "ㆍ", count: count)
            if let cho = cho {
                return String(cho.compatibilityCharacter) + dots
            }
            return dots
        default:
            return currentComposingCharacter.map { String($0) } ?? ""
        }
    }

    var displayText: String {
        let composing = composingDisplay
        if !composing.isEmpty {
            return composedText + composing
        }
        return composedText
    }

    func reset() {
        state = .empty
        composedText = ""
    }

    /// Retrieves and clears any committed text waiting to be inserted
    func flushCommittedText() -> String {
        let text = composedText
        composedText = ""
        return text
    }

    func commitCurrent() {
        switch state {
        case .dotPending(let cho, let count):
            if let cho = cho {
                composedText.append(cho.compatibilityCharacter)
            }
            composedText.append(String(repeating: "ㆍ", count: count))
        default:
            if let char = currentComposingCharacter {
                composedText.append(char)
            }
        }
        state = .empty
    }

    // Input a consonant (choseong)
    func inputChoseong(_ choseong: Choseong) -> ComposerAction {
        switch state {
        case .empty:
            state = .choseong(choseong)
            return .update

        case .choseong:
            // Commit current choseong and start new one
            commitCurrent()
            state = .choseong(choseong)
            return .commitAndUpdate

        case .choseongJungseong(let cho, let jung):
            // Try to add as jongseong
            if let jongseong = Jongseong.from(choseong) {
                state = .complete(cho, jung, jongseong)
                return .update
            } else {
                // This consonant can't be jongseong (ㄸ, ㅃ, ㅉ)
                // Commit current and start new
                commitCurrent()
                state = .choseong(choseong)
                return .commitAndUpdate
            }

        case .complete(let cho, let jung, let jong):
            // Try to combine with existing jongseong
            if let doubleJong = jong.combineWith(choseong) {
                state = .complete(cho, jung, doubleJong)
                return .update
            } else {
                // Can't combine - commit and start new
                commitCurrent()
                state = .choseong(choseong)
                return .commitAndUpdate
            }

        case .standaloneVowel:
            // Pending standalone vowel must commit before consonant starts.
            commitCurrent()
            state = .choseong(choseong)
            return .commitAndUpdate

        case .dotPending:
            // Pending ㆍ stroke(s) (with or without leading consonant) cannot
            // form a syllable with a fresh choseong. Commit the buffered text
            // (consonant + raw ㆍ count) and start a new choseong.
            commitCurrent()
            state = .choseong(choseong)
            return .commitAndUpdate
        }
    }

    // Input a vowel (jungseong)
    func inputJungseong(_ jungseong: Jungseong) -> ComposerAction {
        switch state {
        case .empty:
            // ㆍ leads → start dot accumulator (천지인 3-stroke patterns).
            if jungseong == .ㆍ {
                state = .dotPending(choseong: nil, dotCount: 1)
                return .update
            }
            // Hold the vowel as pending so 천지인 (cheonjiin) sequences can
            // continue to compose (e.g. ㅡ + ㅣ = ㅢ, ㅣ + ㆍ = ㅏ).
            state = .standaloneVowel(jungseong)
            return .update

        case .standaloneVowel(let prev):
            // Try to combine the pending vowel with the new one.
            if let combined = combineVowels(prev, jungseong) {
                state = .standaloneVowel(combined)
                return .update
            } else {
                // Not combinable — commit pending vowel.
                commitCurrent()
                if jungseong == .ㆍ {
                    state = .dotPending(choseong: nil, dotCount: 1)
                    return .commitAndUpdate
                }
                state = .standaloneVowel(jungseong)
                return .commitAndUpdate
            }

        case .choseong(let cho):
            // ㆍ alone cannot form a modern syllable with a leading consonant.
            // Hold consonant + ㆍ as a dot-accumulator so ㅇ+ㆍ+ㆍ+ㅣ→여 etc.
            if jungseong == .ㆍ {
                state = .dotPending(choseong: cho, dotCount: 1)
                return .update
            }
            state = .choseongJungseong(cho, jungseong)
            return .update

        case .dotPending(let cho, let count):
            return resolveDotPending(cho: cho, count: count, with: jungseong)

        case .choseongJungseong(let cho, let jung):
            // Try to combine vowels (covers ㅡ+ㅣ=ㅢ, ㅏ+ㆍ=ㅑ, ㅣ+ㆍ=ㅏ, etc.)
            if let combined = combineVowels(jung, jungseong) {
                // Sanity guard: combined should never be the bare ㆍ — every
                // ㆍ-producing combination above resolves to a modern jamo.
                if combined == .ㆍ {
                    commitCurrent()
                    state = .dotPending(choseong: nil, dotCount: 1)
                    return .commitAndUpdate
                }
                state = .choseongJungseong(cho, combined)
                return .update
            } else {
                // Can't combine - commit and output standalone vowel
                commitCurrent()
                if jungseong == .ㆍ {
                    state = .dotPending(choseong: nil, dotCount: 1)
                    return .commitAndUpdate
                }
                composedText.append(jungseong.compatibilityCharacter)
                return .commitAndCommit
            }

        case .complete(let cho, let jung, let jong):
            // Vowel after complete syllable - move jongseong to new syllable
            if let split = jong.splitDoubleJongseong() {
                // Double jongseong - keep first part, move second
                let previousChar = HangulConstants.composeSyllable(choseong: cho, jungseong: jung, jongseong: split.0)
                composedText.append(previousChar)
                if jungseong == .ㆍ {
                    state = .dotPending(choseong: split.1, dotCount: 1)
                    return .commitAndUpdate
                }
                state = .choseongJungseong(split.1, jungseong)
                return .commitAndUpdate
            } else if let newChoseong = jong.toChoseong {
                // Single jongseong - move to new syllable
                let previousChar = HangulConstants.composeSyllable(choseong: cho, jungseong: jung)
                composedText.append(previousChar)
                if jungseong == .ㆍ {
                    state = .dotPending(choseong: newChoseong, dotCount: 1)
                    return .commitAndUpdate
                }
                state = .choseongJungseong(newChoseong, jungseong)
                return .commitAndUpdate
            } else {
                // Shouldn't happen, but handle gracefully
                commitCurrent()
                if jungseong == .ㆍ {
                    state = .dotPending(choseong: nil, dotCount: 1)
                    return .commitAndUpdate
                }
                composedText.append(jungseong.compatibilityCharacter)
                return .commitAndCommit
            }
        }
    }

    /// Resolve a `dotPending` state when a fresh vowel arrives.
    /// 천지인 3-stroke patterns:
    ///   1 dot + ㅣ → ㅓ        2 dots + ㅣ → ㅕ
    ///   1 dot + ㅡ → ㅗ        2 dots + ㅡ → ㅛ
    ///   N dots + ㆍ → N+1 dots (or commit + restart at 1 dot when N == 2)
    ///   N dots + other vowel → commit raw dots, start fresh standaloneVowel
    private func resolveDotPending(cho: Choseong?, count: Int, with jung: Jungseong) -> ComposerAction {
        if jung == .ㆍ {
            if count == 1 {
                state = .dotPending(choseong: cho, dotCount: 2)
                return .update
            }
            // count == 2 → ㆍㆍㆍ has no standard 천지인 mapping. Commit the
            // existing buffer (consonant + ㆍㆍ) and start a fresh single dot.
            commitCurrent()
            state = .dotPending(choseong: nil, dotCount: 1)
            return .commitAndUpdate
        }

        let resolvedJung: Jungseong?
        switch jung {
        case .ㅣ: resolvedJung = (count == 1) ? .ㅓ : .ㅕ
        case .ㅡ: resolvedJung = (count == 1) ? .ㅗ : .ㅛ
        default:  resolvedJung = nil
        }

        guard let resolved = resolvedJung else {
            // Other vowel after dotPending — commit raw text and start fresh.
            commitCurrent()
            state = .standaloneVowel(jung)
            return .commitAndUpdate
        }

        if let cho = cho {
            state = .choseongJungseong(cho, resolved)
        } else {
            state = .standaloneVowel(resolved)
        }
        return .update
    }

    // Delete the last input
    func deleteBackward() -> ComposerAction {
        switch state {
        case .empty:
            if !composedText.isEmpty {
                let lastChar = composedText.removeLast()
                // If it's a composed syllable, decompose and continue editing
                if let (cho, jung, jong) = HangulConstants.decomposeSyllable(lastChar) {
                    if jong == .none {
                        state = .choseong(cho)
                    } else {
                        state = .complete(cho, jung, jong)
                    }
                    return .update
                }
                return .delete
            }
            return .none

        case .choseong:
            state = .empty
            return .update

        case .choseongJungseong:
            state = .empty
            return .update

        case .complete(let cho, let jung, let jong):
            // Check if jongseong is double
            if let split = jong.splitDoubleJongseong() {
                state = .complete(cho, jung, split.0)
            } else {
                state = .choseongJungseong(cho, jung)
            }
            return .update

        case .standaloneVowel:
            // Drop the pending standalone vowel without committing.
            state = .empty
            return .update

        case .dotPending(let cho, let count):
            if count > 1 {
                state = .dotPending(choseong: cho, dotCount: count - 1)
                return .update
            }
            // Last ㆍ removed — fall back to the held consonant or empty.
            if let cho = cho {
                state = .choseong(cho)
            } else {
                state = .empty
            }
            return .update
        }
    }

    // Try to combine two vowels
    private func combineVowels(_ first: Jungseong, _ second: Jungseong) -> Jungseong? {
        switch (first, second) {
        case (.ㅗ, .ㅏ): return .ㅘ
        case (.ㅗ, .ㅐ): return .ㅙ
        case (.ㅗ, .ㅣ): return .ㅚ
        case (.ㅜ, .ㅓ): return .ㅝ
        case (.ㅜ, .ㅔ): return .ㅞ
        case (.ㅜ, .ㅣ): return .ㅟ
        case (.ㅡ, .ㅣ): return .ㅢ
        case (.ㅏ, .ㅣ): return .ㅐ
        case (.ㅑ, .ㅣ): return .ㅒ
        case (.ㅓ, .ㅣ): return .ㅔ
        case (.ㅕ, .ㅣ): return .ㅖ
        case (.ㅘ, .ㅣ): return .ㅙ
        case (.ㅝ, .ㅣ): return .ㅞ
        // 천지인 (cheonjiin) ㆍ combinations.
        case (.ㅣ, .ㆍ): return .ㅏ
        case (.ㆍ, .ㅣ): return .ㅓ
        case (.ㆍ, .ㅡ): return .ㅗ
        case (.ㅡ, .ㆍ): return .ㅜ
        case (.ㅏ, .ㆍ): return .ㅑ
        case (.ㅓ, .ㆍ): return .ㅕ
        case (.ㅗ, .ㆍ): return .ㅛ
        case (.ㅜ, .ㆍ): return .ㅠ
        default: return nil
        }
    }

    enum ComposerAction {
        case none           // No change
        case update         // Update the composing character
        case commit         // Commit character to text
        case delete         // Delete from text
        case commitAndUpdate    // Commit previous and update composing
        case commitAndCommit    // Commit previous and commit new
    }
}

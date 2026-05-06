import Foundation

/// Delimiter characters that trigger abbreviation expansion check
private let expansionDelimiters: Set<Character> = [" ", "\n", ".", ",", "!", "?", ";", ":"]

/// Abbreviation engine delegate
protocol AbbreviationEngineDelegate: AnyObject {
    /// Called when an expansion should be applied
    /// - Parameters:
    ///   - trigger: The original trigger text to be replaced
    ///   - replacement: The expansion text
    ///   - delimiter: The delimiter character that triggered the expansion
    func abbreviationEngine(_ engine: AbbreviationEngine, shouldReplace trigger: String, with replacement: String, delimiter: Character)

    /// Called when a single suggestion candidate should be shown
    func abbreviationEngine(_ engine: AbbreviationEngine, showCandidateFor expansion: ShortcutExpansion)

    /// Called when multiple candidates should be shown for selection
    func abbreviationEngine(_ engine: AbbreviationEngine, showCandidatesFor expansions: [ShortcutExpansion])

    /// Called when candidate bar should be dismissed
    func abbreviationEngineDidDismissCandidate(_ engine: AbbreviationEngine)

    /// Called when backspace restoration occurs
    /// - Parameters:
    ///   - replacement: The expansion text to be removed
    ///   - original: The original trigger text to be restored
    func abbreviationEngine(_ engine: AbbreviationEngine, shouldRestore original: String, removing replacement: String)
}

/// Trie-based abbreviation expansion engine
final class AbbreviationEngine {
    weak var delegate: AbbreviationEngineDelegate?

    /// Current input buffer (accumulated characters)
    private(set) var buffer: String = ""

    /// The expansion store containing all abbreviations
    private var store: ShortcutExpansionStore = ShortcutExpansionStore()

    /// Last applied expansion for backspace restoration
    private var lastExpansion: AppliedExpansion?

    /// Whether a candidate is currently being shown
    private(set) var isShowingCandidate: Bool = false

    /// Current pending candidate (for suggestion mode)
    private var pendingCandidate: ShortcutExpansion?

    /// All pending candidates when multiple matches exist
    private(set) var pendingCandidates: [ShortcutExpansion] = []

    /// Tracks whether the last action was an expansion (for backspace restore)
    private(set) var canRestoreLastExpansion: Bool = false

    /// Master switch. When `false`, `processCharacter` and `processBackspace`
    /// short-circuit so the engine has no observable effect on input — but
    /// the loaded trigger trie stays intact, so flipping back to `true`
    /// resumes work without a reload.
    var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                buffer.removeAll(keepingCapacity: true)
                isShowingCandidate = false
                pendingCandidate = nil
                pendingCandidates = []
                canRestoreLastExpansion = false
                lastExpansion = nil
            }
        }
    }

    // MARK: - Trie for fast trigger lookup

    private class TrieNode {
        var children: [Character: TrieNode] = [:]
        var expansions: [ShortcutExpansion] = []
    }

    private var trieRoot = TrieNode()

    // MARK: - Initialization

    init() {}

    /// Load expansions from store and rebuild the trie
    func loadExpansions(_ store: ShortcutExpansionStore) {
        self.store = store
        rebuildTrie()
    }

    /// Rebuild the trie index from current store
    private func rebuildTrie() {
        trieRoot = TrieNode()
        for expansion in store.enabledExpansions {
            var node = trieRoot
            for char in expansion.trigger {
                let child = node.children[char] ?? {
                    let newNode = TrieNode()
                    node.children[char] = newNode
                    return newNode
                }()
                node = child
            }
            node.expansions.append(expansion)
        }
    }

    // MARK: - Input Processing

    /// Process a character input
    /// Call this for each confirmed character (after Hangul composition is complete)
    func processCharacter(_ char: Character) {
        guard isEnabled else { return }

        // Any new input invalidates backspace restoration
        canRestoreLastExpansion = false
        lastExpansion = nil

        // Check if this is a delimiter
        if expansionDelimiters.contains(char) {
            checkAndExpand(delimiter: char)
            return
        }

        // Accumulate in buffer
        buffer.append(char)

        // Dismiss any showing candidate
        if isShowingCandidate {
            isShowingCandidate = false
            pendingCandidate = nil
            delegate?.abbreviationEngineDidDismissCandidate(self)
        }
    }

    /// Process a composed Hangul syllable
    /// This should be called when a complete syllable is committed
    func processComposedText(_ text: String) {
        canRestoreLastExpansion = false
        lastExpansion = nil

        for char in text {
            buffer.append(char)
        }
    }

    /// Process backspace
    /// Returns true if backspace was handled (restoration occurred)
    @discardableResult
    func processBackspace() -> Bool {
        guard isEnabled else { return false }

        // Check if we should restore the original trigger
        if canRestoreLastExpansion, let last = lastExpansion {
            delegate?.abbreviationEngine(self, shouldRestore: last.trigger, removing: last.replacement)
            buffer = last.trigger
            canRestoreLastExpansion = false
            lastExpansion = nil
            return true
        }

        // Normal backspace: remove last character from buffer
        if !buffer.isEmpty {
            buffer.removeLast()
        }

        // Dismiss candidate if showing
        if isShowingCandidate {
            isShowingCandidate = false
            pendingCandidate = nil
            delegate?.abbreviationEngineDidDismissCandidate(self)
        }

        return false
    }

    /// Reset the buffer (e.g. on cursor movement or focus change)
    func resetBuffer() {
        buffer = ""
        canRestoreLastExpansion = false
        lastExpansion = nil
        if isShowingCandidate {
            isShowingCandidate = false
            pendingCandidate = nil
            delegate?.abbreviationEngineDidDismissCandidate(self)
        }
    }

    /// Confirm a pending suggestion candidate
    func confirmPendingCandidate(delimiter: Character = " ") {
        guard let candidate = pendingCandidate else { return }
        applyExpansion(candidate, delimiter: delimiter)
        isShowingCandidate = false
        pendingCandidate = nil
        pendingCandidates = []
    }

    /// Confirm a specific candidate from multiple choices
    func confirmSpecificCandidate(_ expansion: ShortcutExpansion, delimiter: Character = " ") {
        applyExpansion(expansion, delimiter: delimiter)
        isShowingCandidate = false
        pendingCandidate = nil
        pendingCandidates = []
    }

    /// Dismiss pending candidate without applying
    func dismissPendingCandidate() {
        isShowingCandidate = false
        pendingCandidate = nil
        delegate?.abbreviationEngineDidDismissCandidate(self)
    }

    // MARK: - Expansion Logic

    /// Check buffer against trie and expand if match found
    private func checkAndExpand(delimiter: Character) {
        let matches = lookupTrie(buffer)
        guard !matches.isEmpty else {
            buffer = ""
            return
        }

        if matches.count == 1 {
            let expansion = matches[0]
            switch expansion.commitMode {
            case .onDelimiter:
                applyExpansion(expansion, delimiter: delimiter)
            case .suggestion:
                pendingCandidates = matches
                pendingCandidate = expansion
                isShowingCandidate = true
                delegate?.abbreviationEngine(self, showCandidatesFor: matches)
            }
        } else {
            // Multiple matches — always show candidate picker
            pendingCandidates = matches
            pendingCandidate = matches[0]
            isShowingCandidate = true
            delegate?.abbreviationEngine(self, showCandidatesFor: matches)
        }

        buffer = ""
    }

    /// Apply an expansion
    private func applyExpansion(_ expansion: ShortcutExpansion, delimiter: Character) {
        let trigger = buffer.isEmpty ? expansion.trigger : buffer

        delegate?.abbreviationEngine(self, shouldReplace: trigger, with: expansion.replacement, delimiter: delimiter)

        // Store for backspace restoration
        lastExpansion = AppliedExpansion(trigger: trigger, replacement: expansion.replacement)
        canRestoreLastExpansion = true
        buffer = ""
    }

    /// Look up a string in the trie
    private func lookupTrie(_ text: String) -> [ShortcutExpansion] {
        var node = trieRoot
        for char in text {
            guard let next = node.children[char] else {
                return []
            }
            node = next
        }
        return node.expansions
    }

    /// Check if the current buffer has any potential matches (prefix exists in trie)
    func hasPartialMatch() -> Bool {
        var node = trieRoot
        for char in buffer {
            guard let next = node.children[char] else {
                return false
            }
            node = next
        }
        return true
    }
}

// MARK: - Supporting Types

private extension AbbreviationEngine {
    struct AppliedExpansion {
        let trigger: String
        let replacement: String
    }
}

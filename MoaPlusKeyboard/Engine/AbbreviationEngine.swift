import Foundation

/// Delimiter characters that trigger abbreviation expansion check
private let expansionDelimiters: Set<Character> = [" ", "\n", ".", ",", "!", "?", ";", ":"]

/// 어절 경계 구분자 — 버퍼를 **리셋**한다. 트리거에 포함될 수 없다.
///
/// 공백이 트리거 내용까지 겸하면 확정 신호와 역할이 겹쳐서, 짧은 트리거가 긴 트리거를
/// 가로채고(`ㅋ` vs `ㅋ ㅋ`) 삭제 개수 규칙도 갈라진다. 그래서 공백 포함 트리거는
/// 지원하지 않기로 했다 (CLAUDE.md §약어 트리거 매칭 규칙).
private let boundaryDelimiters: Set<Character> = [" ", "\n"]

/// 내용 겸 확정 구분자 — 버퍼에 **누적**되면서 동시에 확정 판정을 트리거한다.
/// 덕분에 `.ㅎㅌ` `ㅏ..` 처럼 기호가 낀 트리거가 조회 문자열로 만들어질 수 있다.
private let contentDelimiters: Set<Character> = expansionDelimiters.subtracting(boundaryDelimiters)

/// Abbreviation engine delegate
protocol AbbreviationEngineDelegate: AnyObject {
    /// Called when an expansion should be applied
    /// - Parameters:
    ///   - trigger: The original trigger text to be replaced
    ///   - replacement: The expansion text
    ///   - delimiter: The delimiter character that triggered the expansion
    /// - Returns: 실제로 치환했는지. `false` 면 엔진이 되돌리기 상태를 세우지 않는다 —
    ///   델리게이트가 화면 검증에 실패해 치환을 포기했는데 엔진만 "확장함" 으로 남으면
    ///   사용자가 누른 구분자가 삼켜지고 백스페이스가 엉뚱한 복원을 한다.
    @discardableResult
    func abbreviationEngine(_ engine: AbbreviationEngine, shouldReplace trigger: String, with replacement: String, delimiter: Character) -> Bool

    /// Called when a single suggestion candidate should be shown
    func abbreviationEngine(_ engine: AbbreviationEngine, showCandidateFor expansion: ShortcutExpansion)

    /// Called when multiple candidates should be shown for selection
    func abbreviationEngine(_ engine: AbbreviationEngine, showCandidatesFor expansions: [ShortcutExpansion])

    /// Called when candidate bar should be dismissed
    func abbreviationEngineDidDismissCandidate(_ engine: AbbreviationEngine)

    /// Called when backspace restoration occurs
    /// - Parameters:
    ///   - original: The original trigger text to be restored
    ///   - replacement: The expansion text to be removed
    ///   - delimiter: The delimiter that was inserted alongside the replacement
    func abbreviationEngine(_ engine: AbbreviationEngine, shouldRestore original: String, removing replacement: String, delimiter: Character)
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

    /// 후보 표시 시점에 화면에 실재하던 트리거 문자열.
    /// 접미 매칭에서는 버퍼(`안녕.ㅎㅌ`)와 트리거(`.ㅎㅌ`)가 다르므로 확정 시 이 값을 쓴다.
    private var pendingTrigger: String = ""

    /// 후보를 띄운 구분자. 확정 시 이 문자를 다시 삽입한다.
    private var pendingDelimiter: Character = " "

    /// 백스페이스로 확장을 되돌릴지 (설정에서 끌 수 있음)
    var isUndoOnBackspaceEnabled: Bool = true

    /// 활성 트리거 중 가장 긴 길이 — 버퍼 상한. 익스텐션 메모리(~30MB) 보호용이자
    /// 접미 매칭 탐색 범위이기도 하다. `rebuildTrie()` 에서 갱신한다.
    private(set) var maxTriggerLength: Int = 1

    /// 내용 구분자를 포함한 트리거가 하나라도 있는지. 없으면 접미 매칭을 통째로 건너뛴다.
    private var hasSymbolTriggers: Bool = false

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
                pendingTrigger = ""
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
        var longest = 1
        var sawSymbolTrigger = false
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
            longest = max(longest, expansion.trigger.count)
            if expansion.trigger.contains(where: { contentDelimiters.contains($0) }) {
                sawSymbolTrigger = true
            }
        }
        // 상한은 반드시 "가장 긴 활성 트리거" 이상이어야 한다. 상수로 고정하면 그보다
        // 긴 트리거가 조용히 동작을 멈춘다.
        maxTriggerLength = longest
        hasSymbolTriggers = sawSymbolTrigger
        trimBuffer()
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
            let expanded = checkAndExpand(delimiter: char)
            if boundaryDelimiters.contains(char) {
                // 공백/개행 = 어절 경계. 무조건 버퍼를 비운다.
                buffer = ""
            } else if !expanded && !isShowingCandidate {
                // 기호는 확정 신호이자 **내용 문자**다. 확장이 일어나지 않았다면
                // 버퍼에 남겨야 다음 확정 시점에 `.ㅎㅌ` `ㅏ..` 가 조회된다.
                appendToBuffer(char)
            }
            return
        }

        // Accumulate in buffer
        appendToBuffer(char)

        // Dismiss any showing candidate
        dismissCandidateIfNeeded()
    }

    /// Process a composed Hangul syllable
    /// This should be called when a complete syllable is committed
    func processComposedText(_ text: String) {
        guard isEnabled else { return }
        canRestoreLastExpansion = false
        lastExpansion = nil

        for char in text {
            appendToBuffer(char)
        }
    }

    /// 버퍼에 한 글자 추가하고 상한을 넘으면 앞에서 잘라낸다.
    private func appendToBuffer(_ char: Character) {
        buffer.append(char)
        trimBuffer()
    }

    /// 버퍼를 `maxTriggerLength` 이하로 유지한다. 정확 매칭은 버퍼 전체가 트리거와 같아야
    /// 성립하므로 상한을 넘는 앞부분은 어떤 매칭에도 기여하지 못한다.
    private func trimBuffer() {
        guard buffer.count > maxTriggerLength else { return }
        buffer.removeFirst(buffer.count - maxTriggerLength)
    }

    private func dismissCandidateIfNeeded() {
        guard isShowingCandidate else { return }
        isShowingCandidate = false
        pendingCandidate = nil
        pendingTrigger = ""
        delegate?.abbreviationEngineDidDismissCandidate(self)
    }

    /// Process backspace
    /// Returns true if backspace was handled (restoration occurred)
    @discardableResult
    func processBackspace() -> Bool {
        guard isEnabled else { return false }

        // Check if we should restore the original trigger
        if isUndoOnBackspaceEnabled, canRestoreLastExpansion, let last = lastExpansion {
            delegate?.abbreviationEngine(self, shouldRestore: last.trigger, removing: last.replacement, delimiter: last.delimiter)
            buffer = last.trigger
            canRestoreLastExpansion = false
            lastExpansion = nil
            return true
        }

        // Normal backspace: remove last character from buffer
        if !buffer.isEmpty {
            buffer.removeLast()
        }

        dismissCandidateIfNeeded()

        return false
    }

    /// Reset the buffer (e.g. on cursor movement or focus change)
    func resetBuffer() {
        buffer = ""
        canRestoreLastExpansion = false
        lastExpansion = nil
        dismissCandidateIfNeeded()
    }

    /// Confirm a pending suggestion candidate.
    /// - Parameter delimiter: 생략하면 후보를 띄운 **그 구분자**를 그대로 쓴다.
    ///   공백을 하드코딩하면 사용자가 `.` 로 확정했는데 공백이 삽입된다.
    func confirmPendingCandidate(delimiter: Character? = nil) {
        guard let candidate = pendingCandidate else { return }
        applyExpansion(candidate,
                       trigger: resolvedPendingTrigger(for: candidate),
                       delimiter: delimiter ?? pendingDelimiter)
        clearPendingCandidateState()
    }

    /// Confirm a specific candidate from multiple choices
    func confirmSpecificCandidate(_ expansion: ShortcutExpansion, delimiter: Character? = nil) {
        applyExpansion(expansion,
                       trigger: resolvedPendingTrigger(for: expansion),
                       delimiter: delimiter ?? pendingDelimiter)
        clearPendingCandidateState()
    }

    /// Dismiss pending candidate without applying
    func dismissPendingCandidate() {
        isShowingCandidate = false
        pendingCandidate = nil
        pendingTrigger = ""
        delegate?.abbreviationEngineDidDismissCandidate(self)
    }

    /// 후보를 띄울 때 기록해 둔 화면상 트리거. 기록이 비었으면(직접 확정 등)
    /// 등록된 트리거로 대체한다.
    private func resolvedPendingTrigger(for expansion: ShortcutExpansion) -> String {
        pendingTrigger.isEmpty ? expansion.trigger : pendingTrigger
    }

    private func clearPendingCandidateState() {
        isShowingCandidate = false
        pendingCandidate = nil
        pendingCandidates = []
        pendingTrigger = ""
        pendingDelimiter = " "
    }

    // MARK: - Expansion Logic

    /// Check buffer against trie and expand if match found.
    /// - Returns: `true` 일 때만 실제 치환이 일어났다. 후보 바를 띄운 경우는 `false` —
    ///   호출측(`inputSpace` 등)이 구분자를 그대로 삽입해야 하기 때문이다.
    @discardableResult
    private func checkAndExpand(delimiter: Character) -> Bool {
        guard let match = findMatch() else {
            return false
        }
        let matches = match.expansions

        if matches.count == 1, matches[0].commitMode == .onDelimiter {
            return applyExpansion(matches[0], trigger: match.trigger, delimiter: delimiter)
        }

        // 후보 선택 모드 또는 다중 매칭 — 사용자가 탭할 때까지 대기
        pendingCandidates = matches
        pendingCandidate = matches[0]
        pendingTrigger = match.trigger
        pendingDelimiter = delimiter
        isShowingCandidate = true
        delegate?.abbreviationEngine(self, showCandidatesFor: matches)
        buffer = ""
        return false
    }

    /// 확정 시점에 버퍼에서 트리거를 찾는다.
    ///
    /// 1. **정확 매칭** — 버퍼 전체가 트리거인 경우. 기존 동작 그대로다.
    /// 2. **접미 매칭** — 실패하면 버퍼의 꼬리를 길이 순으로 훑는다. 단 **내용 구분자를
    ///    포함한 트리거만** 대상이다. 이 제한이 없으면 평범한 `ㅎㅌ` 가 "안녕ㅎㅌ" 끝에서도
    ///    터져 기존 사용자가 전부 깨진다. 기호 트리거는 반대로 `안녕.ㅎㅌ` 처럼 앞말에
    ///    붙여 쓰는 것이 전형적 사용이라 어절 중간에서도 발동시킨다
    ///    (CLAUDE.md §약어 트리거 매칭 규칙).
    private func findMatch() -> (trigger: String, expansions: [ShortcutExpansion])? {
        let exact = lookupTrie(buffer)
        if !exact.isEmpty {
            return (buffer, exact)
        }
        guard hasSymbolTriggers else { return nil }

        let chars = Array(buffer)
        // 버퍼 전체 길이는 정확 매칭에서 이미 시도했으므로 그 다음 길이부터 훑는다.
        let upper = min(chars.count - 1, maxTriggerLength)
        guard upper >= 1 else { return nil }
        for length in stride(from: upper, through: 1, by: -1) {
            let suffix = chars[(chars.count - length)...]
            guard suffix.contains(where: { contentDelimiters.contains($0) }) else { continue }
            let candidate = String(suffix)
            let matches = lookupTrie(candidate)
            if !matches.isEmpty {
                return (candidate, matches)
            }
        }
        return nil
    }

    /// Apply an expansion.
    /// - Parameter trigger: 화면에서 지워야 할 **실제 문자열**. 접미 매칭에서는 버퍼
    ///   (`안녕.ㅎㅌ`)와 트리거(`.ㅎㅌ`)가 다르므로 반드시 매칭된 쪽을 넘겨야 한다.
    ///   버퍼 길이로 지우면 앞 글자(`안녕`)를 먹는다.
    @discardableResult
    private func applyExpansion(_ expansion: ShortcutExpansion, trigger: String, delimiter: Character) -> Bool {
        let applied = delegate?.abbreviationEngine(self,
                                                   shouldReplace: trigger,
                                                   with: expansion.replacement,
                                                   delimiter: delimiter) ?? false
        buffer = ""
        guard applied else {
            // 델리게이트가 포기했다 — 엔진도 "확장 안 함" 상태로 남아야 호출측이
            // 구분자를 정상 삽입하고, 백스페이스가 엉뚱한 복원을 하지 않는다.
            canRestoreLastExpansion = false
            lastExpansion = nil
            return false
        }

        // Store for backspace restoration
        lastExpansion = AppliedExpansion(trigger: trigger, replacement: expansion.replacement, delimiter: delimiter)
        canRestoreLastExpansion = true
        return true
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
        let delimiter: Character
    }
}

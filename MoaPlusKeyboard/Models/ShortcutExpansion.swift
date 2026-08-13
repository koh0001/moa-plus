import Foundation

/// Abbreviation expansion entry
struct ShortcutExpansion: Codable, Equatable, Identifiable {
    var id: UUID = UUID()

    /// Trigger string (Korean consonant sequence, e.g. "ㅎㅅㅁㅇ")
    var trigger: String

    /// Replacement text (e.g. "koh@move.kr")
    var replacement: String

    /// How the expansion is confirmed
    var commitMode: CommitMode = .onDelimiter

    /// Whether this expansion is active
    var isEnabled: Bool = true

    /// Whether the expansion was favorited by user
    var isFavorite: Bool = false

    enum CommitMode: String, Codable, CaseIterable {
        /// Show candidate bar, user taps to confirm
        case suggestion
        /// Auto-confirm when delimiter (space/enter/punctuation) is typed
        case onDelimiter

        var displayName: String {
            switch self {
            case .suggestion:  return "후보 선택"
            case .onDelimiter: return "자동 확정"
            }
        }
    }

    // MARK: - Built-in Examples

    static let examples: [ShortcutExpansion] = [
        ShortcutExpansion(trigger: "ㅇㅎ", replacement: "확인했습니다.", isEnabled: false),
        ShortcutExpansion(trigger: "ㄱㅅ", replacement: "감사합니다.", isEnabled: false),
        ShortcutExpansion(trigger: "ㅈㅅ", replacement: "죄송합니다.", isEnabled: false),
        ShortcutExpansion(trigger: "ㅅㄱ", replacement: "수고하셨습니다.", isEnabled: false),
        ShortcutExpansion(trigger: "ㅇㄴ", replacement: "안녕하세요.", isEnabled: false),
    ]
}

/// Container for managing all shortcut expansions
///
/// `Equatable` 은 `KeyboardSettings.loadAll()` 이 값이 실제로 바뀐 항목만
/// 대입하기 위해 필요하다 — 무조건 재대입하면 @Published 가 매번 발행돼
/// 무관한 설정 하나에도 키보드 트리 전체가 재구성된다.
struct ShortcutExpansionStore: Codable, Equatable {
    var expansions: [ShortcutExpansion] = []

    /// Find matching expansion for a given trigger
    func findExpansion(forTrigger trigger: String) -> ShortcutExpansion? {
        return expansions.first(where: { $0.trigger == trigger && $0.isEnabled })
    }

    /// All enabled expansions
    var enabledExpansions: [ShortcutExpansion] {
        return expansions.filter(\.isEnabled)
    }

    /// Favorites
    var favoriteExpansions: [ShortcutExpansion] {
        return expansions.filter(\.isFavorite)
    }

    mutating func add(_ expansion: ShortcutExpansion) {
        expansions.append(expansion)
    }

    mutating func remove(id: UUID) {
        expansions.removeAll(where: { $0.id == id })
    }

    mutating func update(_ expansion: ShortcutExpansion) {
        if let index = expansions.firstIndex(where: { $0.id == expansion.id }) {
            expansions[index] = expansion
        }
    }
}

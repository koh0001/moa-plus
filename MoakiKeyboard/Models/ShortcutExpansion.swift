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
        ShortcutExpansion(trigger: "ㅎㅅㅁㅇ", replacement: "koh@move.kr", isEnabled: false),
        ShortcutExpansion(trigger: "ㅈㅅㅎㄴㄷ", replacement: "죄송합니다. 확인 후 다시 회신드리겠습니다.", isEnabled: false),
        ShortcutExpansion(trigger: "ㅎㅇㅎㅅ", replacement: "확인했습니다.", isEnabled: false),
    ]
}

/// Container for managing all shortcut expansions
struct ShortcutExpansionStore: Codable {
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

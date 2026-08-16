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

/// 신규 트리거 등록 시 허용 강도.
///
/// **등록 검증 전용**이다. 엔진은 이 값을 보지 않는다 — 이미 저장된 짧은 트리거는 계속
/// 동작해야 하므로(소급 적용 없음) 런타임에 길이로 거르면 기존 사용자가 깨진다.
enum AbbreviationTriggerPolicy: String, Codable, CaseIterable {
    /// 2자 이상. 단 **기호로 시작하는** 트리거는 기호를 뺀 글자가 2자 이상이어야 한다.
    /// `ㅎㅌ` ✅ / `ㅏ..` ✅ / `.ㄱㅅ` ✅ / `.ㄱ` ❌ / `ㅋ` ❌
    case safe
    /// 한 글자도 허용. 오입력을 감수하고 짧은 트리거를 쓰려는 사용자용.
    case free

    var displayName: String {
        switch self {
        case .safe: return "안전"
        case .free: return "자유"
        }
    }

    var footerText: String {
        switch self {
        case .safe:
            return "2자 이상인 트리거만 등록할 수 있습니다. 기호로 시작하는 트리거(예: .ㄱㅅ)는 문장 중간에서도 변환되므로 기호를 뺀 글자가 2자 이상이어야 합니다."
        case .free:
            return "한 글자 트리거도 등록할 수 있습니다. 짧은 트리거는 의도치 않게 변환될 수 있습니다."
        }
    }

    /// 트리거 문자열 검증. 통과하면 `nil`, 아니면 사용자에게 보여줄 사유.
    ///
    /// 공백 불허는 두 정책 모두 동일하다 — 금지 사유가 오입력이 아니라 "확정 신호와
    /// 트리거 내용의 이중 역할" 이라는 구조적 충돌이라 설정으로 풀 수 없다.
    func validationMessage(for trigger: String) -> String? {
        if trigger.isEmpty {
            return "트리거를 입력하세요."
        }
        if trigger.contains(where: { $0 == " " || $0 == "\n" }) {
            return "트리거에는 띄어쓰기를 넣을 수 없습니다. 스페이스는 단축어를 확정하는 신호로 쓰입니다."
        }
        guard self == .safe else { return nil }

        if trigger.count < 2 {
            return "트리거는 2자 이상이어야 합니다. 한 글자 트리거를 쓰려면 ‘자유’ 를 선택하세요."
        }
        // 기호로 **시작하는** 트리거만 더 엄격히 본다. 이런 트리거는 접미 매칭으로
        // 문장 중간 어디서든 발동할 수 있어서, 실질 글자가 하나뿐이면(`.ㄱ`) 마침표로
        // 끝나는 아무 문장 뒤에서 터진다. 반대로 `ㅏ..` 처럼 기호로 *끝나는* 트리거는
        // 앞부분이 먼저 일치해야 하므로 같은 위험이 없다.
        if let first = trigger.first, !first.isLetter, !first.isNumber {
            let substantive = trigger.filter { $0.isLetter || $0.isNumber }.count
            if substantive < 2 {
                return "기호로 시작하는 트리거는 기호를 뺀 글자가 2자 이상이어야 합니다(예: .ㄱㅅ). 그렇지 않으면 마침표로 끝나는 문장 뒤에서 실수로 변환될 수 있습니다."
            }
        }
        return nil
    }
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

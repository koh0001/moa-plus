import Foundation

/// Per-key long-press auxiliary input configuration
struct SecondaryKeyAction: Codable, Equatable, Identifiable {
    var id: String { keyId }

    /// Key identifier (consonant character, e.g. "ㅂ")
    let keyId: String

    /// Small hint label shown on the key (e.g. "1")
    var visibleHint: String

    /// Primary output when long-press is triggered
    var primaryLongPressOutput: String

    /// Additional outputs shown in popup fan-out
    var popupOutputs: [String]

    /// Hint position adjustment for edge columns
    var hintInsetDirection: HintInsetDirection = .none

    enum HintInsetDirection: String, Codable {
        case none        // Default position (top-right)
        case inwardLeft  // Shift hint leftward (for right-edge keys)
        case inwardRight // Shift hint rightward (for left-edge keys)
    }

    // MARK: - Default Mappings

    /// Default long-press mappings: left-to-right number assignment
    /// Row 1 (doubles): ㅃ=1, ㅉ=2, ㄸ=3, ㄲ=4, ㅆ=5
    /// Row 2 (singles): ㅂ=6, ㅈ=7, ㄷ=8, ㄱ=9, ㅅ=0
    /// Row 3: ㅁ, ㄴ, ㅇ, ㄹ, ㅎ (special characters)
    /// Row 4: ㅋ, ㅌ, ㅊ, ㅍ (special characters)
    static let defaults: [SecondaryKeyAction] = [
        // Row 1 - Double consonants (1-5)
        SecondaryKeyAction(keyId: "ㅃ", visibleHint: "1", primaryLongPressOutput: "1", popupOutputs: ["1", "!", "~"], hintInsetDirection: .inwardRight),
        SecondaryKeyAction(keyId: "ㅉ", visibleHint: "2", primaryLongPressOutput: "2", popupOutputs: ["2", "@"]),
        SecondaryKeyAction(keyId: "ㄸ", visibleHint: "3", primaryLongPressOutput: "3", popupOutputs: ["3", "#"]),
        SecondaryKeyAction(keyId: "ㄲ", visibleHint: "4", primaryLongPressOutput: "4", popupOutputs: ["4", "$"]),
        SecondaryKeyAction(keyId: "ㅆ", visibleHint: "5", primaryLongPressOutput: "5", popupOutputs: ["5", "%"], hintInsetDirection: .inwardLeft),

        // Row 2 - Single consonants (6-0)
        SecondaryKeyAction(keyId: "ㅂ", visibleHint: "6", primaryLongPressOutput: "6", popupOutputs: ["6", "^"], hintInsetDirection: .inwardRight),
        SecondaryKeyAction(keyId: "ㅈ", visibleHint: "7", primaryLongPressOutput: "7", popupOutputs: ["7", "&"]),
        SecondaryKeyAction(keyId: "ㄷ", visibleHint: "8", primaryLongPressOutput: "8", popupOutputs: ["8", "*"]),
        SecondaryKeyAction(keyId: "ㄱ", visibleHint: "9", primaryLongPressOutput: "9", popupOutputs: ["9", "(", ")"]),
        SecondaryKeyAction(keyId: "ㅅ", visibleHint: "0", primaryLongPressOutput: "0", popupOutputs: ["0", "-", "_", "+", "="], hintInsetDirection: .inwardLeft),

        // Row 3 - Consonants with special chars
        SecondaryKeyAction(keyId: "ㅁ", visibleHint: ",", primaryLongPressOutput: ",", popupOutputs: [",", "<", "{"], hintInsetDirection: .inwardRight),
        SecondaryKeyAction(keyId: "ㄴ", visibleHint: ".", primaryLongPressOutput: ".", popupOutputs: [".", ">", "}"]),
        SecondaryKeyAction(keyId: "ㅇ", visibleHint: "?", primaryLongPressOutput: "?", popupOutputs: ["?", "/", "\\"]),
        SecondaryKeyAction(keyId: "ㄹ", visibleHint: "!", primaryLongPressOutput: "!", popupOutputs: ["!", "|", "~"]),
        SecondaryKeyAction(keyId: "ㅎ", visibleHint: "'", primaryLongPressOutput: "'", popupOutputs: ["'", "\"", "`"], hintInsetDirection: .inwardLeft),

        // Row 4 - Bottom consonants
        SecondaryKeyAction(keyId: "ㅋ", visibleHint: ":", primaryLongPressOutput: ":", popupOutputs: [":", ";"]),
        SecondaryKeyAction(keyId: "ㅌ", visibleHint: "@", primaryLongPressOutput: "@", popupOutputs: ["@", "#"]),
        SecondaryKeyAction(keyId: "ㅊ", visibleHint: "₩", primaryLongPressOutput: "₩", popupOutputs: ["₩", "$", "€"]),
        SecondaryKeyAction(keyId: "ㅍ", visibleHint: "…", primaryLongPressOutput: "…", popupOutputs: ["…", "·", "•"]),

        // English number row (PR G17) — long-tap produces shift+number special characters
        SecondaryKeyAction(keyId: "1", visibleHint: "!", primaryLongPressOutput: "!", popupOutputs: ["!"]),
        SecondaryKeyAction(keyId: "2", visibleHint: "@", primaryLongPressOutput: "@", popupOutputs: ["@"]),
        SecondaryKeyAction(keyId: "3", visibleHint: "#", primaryLongPressOutput: "#", popupOutputs: ["#"]),
        SecondaryKeyAction(keyId: "4", visibleHint: "$", primaryLongPressOutput: "$", popupOutputs: ["$"]),
        SecondaryKeyAction(keyId: "5", visibleHint: "%", primaryLongPressOutput: "%", popupOutputs: ["%"]),
        SecondaryKeyAction(keyId: "6", visibleHint: "^", primaryLongPressOutput: "^", popupOutputs: ["^"]),
        SecondaryKeyAction(keyId: "7", visibleHint: "&", primaryLongPressOutput: "&", popupOutputs: ["&"]),
        SecondaryKeyAction(keyId: "8", visibleHint: "*", primaryLongPressOutput: "*", popupOutputs: ["*"]),
        SecondaryKeyAction(keyId: "9", visibleHint: "(", primaryLongPressOutput: "(", popupOutputs: ["("]),
        SecondaryKeyAction(keyId: "0", visibleHint: ")", primaryLongPressOutput: ")", popupOutputs: [")"]),
    ]

    /// Find the secondary action for a given key
    static func action(forKey keyId: String, from actions: [SecondaryKeyAction]? = nil) -> SecondaryKeyAction? {
        let source = actions ?? defaults
        return source.first(where: { $0.keyId == keyId })
    }

    // MARK: - 롱키 후보 (이슈 #37 — 후보의 유일한 출처)

    /// 괄호 자동 닫기가 켜진 문자 모드에서 팝업 후보에서 빼는 닫는 괄호.
    /// 여는 괄호를 넣으면 짝이 같이 들어가므로 닫는 괄호만 따로 고를 일이 없다.
    /// 뷰모델·팝업 오버레이·힌트가 각자 들고 있던 같은 목록을 여기로 모았다.
    static let closingBrackets: Set<String> = [")", "]", "}", ">", "」", "』", "》", "】", "〕"]

    /// 닫는 괄호를 후보에서 뺄 상황인가 — 괄호 자동 닫기 ON + 문자 모드.
    /// 심볼 모드는 "이 글자를 달라" 는 화면이라 빼면 `)` 의 대체 문자(`] } >`)가 사라진다.
    static func filtersClosingBrackets(autoBracketEnabled: Bool, mode: KeyboardMode) -> Bool {
        autoBracketEnabled && !mode.isSymbol
    }

    /// 롱키를 누르고 그대로 떼면 들어가는 글자 = 설정의 **롱프레스 출력**(앞뒤 공백 제거).
    /// 비어 있으면 팝업 후보 중 비어 있지 않은 첫 글자, 그것도 없으면 `""`.
    ///
    /// 이슈 #37: 손 뗄 때 `popupOutputs[0]` 을 넣고 이 값은 읽지 않아서, 롱프레스 출력만
    /// 바꾼 사용자(ㅈ: 후보 `7 &` 그대로)는 계속 7 을 받았다.
    var effectivePrimary: String {
        let primary = primaryLongPressOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        return popupOutputs.lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    /// 팝업 후보 — `effectivePrimary` 가 맨 앞(드래그 없이 떼면 이것), 나머지는 팝업 후보를
    /// 순서대로 공백 제거 후 빈 칸·중복(맨 앞 글자 포함)을 뺀 것.
    ///
    /// `filteringClosingBrackets` 는 **나머지에만** 적용한다. 맨 앞 글자는 사용자가 고른
    /// 결과라 닫는 괄호여도 남긴다 — 빼면 떼는 순간 다음 후보가 들어가고, 후보가 전부
    /// 닫는 괄호면 오버레이가 빈 팝업을 그린다. 맨 앞 글자가 없으면 `[]`.
    func effectiveCandidates(filteringClosingBrackets: Bool) -> [String] {
        let primary = effectivePrimary
        guard !primary.isEmpty else { return [] }
        var seen: Set<String> = [primary]
        var result = [primary]
        for raw in popupOutputs {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty, !seen.contains(item) else { continue }
            if filteringClosingBrackets && Self.closingBrackets.contains(item) { continue }
            seen.insert(item)
            result.append(item)
        }
        return result
    }

    /// 설정 화면 편집 결과. 롱프레스 출력·팝업 후보는 공백을 걷어 저장한다(앞뒤 공백이
    /// 붙은 출력은 키보드에서 공백까지 들어간다). 힌트를 손대지 않았으면(= 예전 롱프레스
    /// 출력과 같으면) 새 출력을 따라가게 한다 — 출력만 바꾸면 키에는 예전 글자가 남았다.
    func applyingEdit(visibleHint: String, primaryOutput: String, popupText: String) -> SecondaryKeyAction {
        let hint = visibleHint.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = primaryOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldPrimary = primaryLongPressOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = self
        updated.visibleHint = (hint == oldPrimary) ? primary : hint
        updated.primaryLongPressOutput = primary
        updated.popupOutputs = popupText
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        return updated
    }

    // MARK: - 일회성 이전 (이슈 #37)

    /// 수정 전에는 손 뗄 때 `popupOutputs[0]` 이 들어가고 롱프레스 출력은 무시됐다. 출력이
    /// 들어가게 고치면 저장된 매핑의 뜻이 바뀌므로, 기본 매핑에 있는 키만 한 번 옮겨 준다.
    ///
    /// - 출력이 **기본값 그대로**이고 첫 후보가 그와 다르면(= 후보 순서를 바꿔 결과를 고른
    ///   사용자) 첫 후보를 롱프레스 출력으로 삼는다 — 떼면 들어가는 글자가 그대로 유지된다.
    ///   힌트도 예전 출력과 같았으면 따라간다.
    /// - 출력을 **직접 고친** 항목은 출력·후보를 그대로 두되, 힌트가 기본값 그대로면(= 손대지
    ///   않았으면) 새 출력(`effectivePrimary`)으로 바꾼다. 수정 전 편집 화면은 힌트를 따라
    ///   바꾸지 않았고, 이제 떼면 그 출력이 들어가므로 키에 예전 글자가 남는다(이슈 #37 제보자
    ///   상태: ㅈ 힌트 7 · 출력 @). 그 뒤의 편집 화면(`applyingEdit`)은 **지금 저장된 출력**과
    ///   비교하므로 이 경우를 고치지 못한다.
    ///
    /// 기본 매핑(29개 모두 힌트 == 출력 == 첫 후보)과 힌트를 직접 고친 항목은 그대로 둔다.
    /// 결과에 다시 적용해도 바뀌지 않는다 — 첫 갈래는 출력 == 첫 후보가 되고 출력이 기본값에서
    /// 벗어나며, 둘째 갈래는 힌트가 기본값에서 벗어나(또는 이미 출력과 같아) 다시 걸리지 않는다.
    static func migratingForPrimaryOutput(_ actions: [SecondaryKeyAction]) -> [SecondaryKeyAction] {
        let defaultActions = Dictionary(
            defaults.map { ($0.keyId, $0) }, uniquingKeysWith: { first, _ in first })
        return actions.map { action in
            guard let defaultAction = defaultActions[action.keyId] else { return action }
            let primary = action.primaryLongPressOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = action.visibleHint.trimmingCharacters(in: .whitespacesAndNewlines)
            var migrated = action

            if primary == defaultAction.primaryLongPressOutput {
                // 출력은 기본값 — 후보 순서를 바꿨으면 첫 후보가 예전 결과였다.
                guard let firstPopup = action.popupOutputs.lazy
                          .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                          .first(where: { !$0.isEmpty }),
                      firstPopup != primary else { return action }
                if hint == primary {
                    migrated.visibleHint = firstPopup
                }
                migrated.primaryLongPressOutput = firstPopup
            } else {
                // 출력을 고쳤다(공백뿐인 출력 포함 — 그때 들어가는 글자는 첫 후보).
                // 힌트를 손대지 않았으면 이제 들어가는 글자를 따라간다.
                let output = action.effectivePrimary
                guard hint == defaultAction.visibleHint,
                      !output.isEmpty, output != hint else { return action }
                migrated.visibleHint = output
            }
            return migrated
        }
    }
}

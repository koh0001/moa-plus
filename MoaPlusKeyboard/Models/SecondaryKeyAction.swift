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
    ]

    /// Find the secondary action for a given key
    static func action(forKey keyId: String, from actions: [SecondaryKeyAction]? = nil) -> SecondaryKeyAction? {
        let source = actions ?? defaults
        return source.first(where: { $0.keyId == keyId })
    }
}

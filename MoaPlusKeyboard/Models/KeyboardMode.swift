import Foundation

/// Keyboard input mode. Letter mode (Korean/English) and Symbol mode are orthogonal.
enum KeyboardMode: Equatable {
    case korean
    case english
    /// Symbol mode remembers which letter mode to return to.
    case symbolFromKorean
    case symbolFromEnglish

    var isSymbol: Bool {
        switch self {
        case .symbolFromKorean, .symbolFromEnglish: return true
        case .korean, .english: return false
        }
    }

    var letterMode: KeyboardMode {
        switch self {
        case .korean, .symbolFromKorean: return .korean
        case .english, .symbolFromEnglish: return .english
        }
    }

    /// Toggle symbol on/off, preserving letter context.
    func toggleSymbol() -> KeyboardMode {
        switch self {
        case .korean: return .symbolFromKorean
        case .english: return .symbolFromEnglish
        case .symbolFromKorean: return .korean
        case .symbolFromEnglish: return .english
        }
    }

    /// Toggle letter mode (한/영). In symbol mode, this also exits symbol mode and switches to the opposite letter.
    func toggleLetter() -> KeyboardMode {
        switch self {
        case .korean: return .english
        case .english: return .korean
        case .symbolFromKorean: return .english   // 심볼 종료 + 영문
        case .symbolFromEnglish: return .korean   // 심볼 종료 + 한글
        }
    }
}

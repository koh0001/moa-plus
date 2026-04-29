import Foundation
import CoreGraphics

/// Content type for each key in the keyboard grid
enum KeyContent: Equatable {
    case consonant(Choseong)
    case symbol(String)
    case backspace
    // Moakey bimanual layout key types
    case vowelPrimitive(VowelPrimitiveType)  // ㆍ, ㅣ, ㅡ
    case functional(FunctionalKeyType)        // Mode switch, settings, etc.
    case systemSwitch                         // Globe key (system keyboard switch)
    case quickPunctuation(String)             // Period, comma, etc.
}

enum VowelPrimitiveType: String {
    case dot = "ㆍ"    // Middle dot (아래아)
    case bar = "ㅣ"    // Vertical bar
    case dash = "ㅡ"   // Horizontal dash

    var displayLabel: String { rawValue }
}

enum FunctionalKeyType: String {
    case modeToggle     // Korean ↔ Symbol toggle
    case specialChar    // Special character layer entry
    case settings       // Settings shortcut
    case space          // Space bar
    case returnKey      // Return/Enter
    case languageSwitch // Language switch (short tap = special char, long = system switch)
    case shift          // Shift / caps-lock for English mode
}

enum KeyboardMetrics {
    // Grid layout
    static let gridColumns = 7  // Expanded from 5 to 7
    static let gridRows = 4

    // Key sizing
    static let keySpacing: CGFloat = 4
    static let keyCornerRadius: CGFloat = 8

    // Width ratio for side symbol keys (relative to center keys)
    // Reads from settings; falls back to 0.35 default
    static var symbolWidthRatio: CGFloat {
        CGFloat(KeyboardSettings.shared.sideKeyWidthRatio)
    }

    // Width ratio for action keys (backspace/return) relative to total width
    static let actionKeyWidthRatio: CGFloat = 0.20

    // Function row
    static let functionRowHeight: CGFloat = 44

    // Keyboard height
    static let keyboardHeight: CGFloat = 260

    // Audio
    static let clickSoundID: UInt32 = 1104

    // Backspace timing
    static let wordDeleteRepeatInterval: TimeInterval = 0.12

    // Gesture thresholds
    static let gestureThreshold: CGFloat = 20        // Minimum distance to register direction
    static let reversalThreshold: CGFloat = 10       // Lower threshold for opposite direction reversals
    static let directionChangeThreshold: CGFloat = 15 // Distance before direction can change
    static let gestureTimeout: TimeInterval = 0.5    // Max time between direction changes

    // Calculate action key width (backspace/return) based on total width
    static func actionKeyWidth(for totalWidth: CGFloat) -> CGFloat {
        return totalWidth * actionKeyWidthRatio
    }

    // Calculate center key width based on available space
    // Row 0-2: side*2 + center*5 = 0.35*2 + 5 = 5.7 units
    static func centerKeyWidth(for totalWidth: CGFloat, columnCount: Int = 7, mode: KeyboardMode = .korean) -> CGFloat {
        let spacing = keySpacing * CGFloat(columnCount + 1)
        let availableWidth = totalWidth - spacing
        if columnCount == 10 {
            // English mode: 10 equal-width keys, no narrow side keys.
            return availableWidth / 10
        }
        // Korean + Symbol modes: col 0 AND col 6 widened to 1.3x sideRatio (좌우 대칭 정렬).
        // Total row = 1.3*sideRatio*c + 5*c + 1.3*sideRatio*c = c * (sideRatio*2.6 + 5)
        return availableWidth / (symbolWidthRatio * 2.6 + 5)
    }

    // Calculate key height based on available space
    static func keyHeight(for totalHeight: CGFloat) -> CGFloat {
        let availableHeight = totalHeight - functionRowHeight - keySpacing * CGFloat(gridRows + 2)
        return availableHeight / CGFloat(gridRows)
    }

    // Get key width for specific column and row (legacy: assumes 7-col Korean/symbol grid)
    static func keyWidth(for column: Int, row: Int, centerKeyWidth: CGFloat) -> CGFloat {
        let sideWidth = centerKeyWidth * symbolWidthRatio
        // Side columns (col 0 and col 6) are narrow
        if column == 0 || column == 6 {
            return sideWidth
        }
        return centerKeyWidth
    }

    /// Mode-aware key width. English layout uses uniform widths (with the
    /// last row's backspace stretched to fill remaining space).
    static func keyWidth(for column: Int, row: Int, centerKeyWidth: CGFloat, mode: KeyboardMode) -> CGFloat {
        switch mode {
        case .english:
            // All keys are equal-width (shift and backspace on last row are same width as letters).
            return centerKeyWidth
        case .korean, .symbolFromKorean, .symbolFromEnglish:
            let sideWidth = centerKeyWidth * symbolWidthRatio
            // Korean + Symbol modes: BOTH side columns (0 + 6) widened to 1.3x sideWidth.
            // 좌우 대칭으로 시각적 마진 균형 유지 (PR G7 + 좌우 균형 fix)
            if column == 0 || column == 6 {
                return sideWidth * 1.3
            }
            return keyWidth(for: column, row: row, centerKeyWidth: centerKeyWidth)
        }
    }

    // Get number of columns for a row in the active layout.
    static func columnCount(for row: Int, isSymbolMode: Bool) -> Int {
        let layout = isSymbolMode ? symbolLayout : koreanLayout
        guard row >= 0 && row < layout.count else { return 0 }
        return layout[row].count
    }

    /// Mode-aware column count.
    static func columnCount(for row: Int, mode: KeyboardMode) -> Int {
        let layout = activeLayout(for: mode)
        guard row >= 0 && row < layout.count else { return 0 }
        return layout[row].count
    }

    /// Returns the layout array (rows × columns) for the given mode.
    static func activeLayout(for mode: KeyboardMode) -> [[KeyContent]] {
        switch mode {
        case .korean: return koreanLayout
        case .english: return englishLayout
        case .symbolFromKorean, .symbolFromEnglish: return symbolLayout
        }
    }

    // Calculate key size based on available width (legacy method for compatibility)
    static func keySize(for totalWidth: CGFloat, totalHeight: CGFloat) -> CGSize {
        let keyWidth = centerKeyWidth(for: totalWidth)
        let keyHeightValue = keyHeight(for: totalHeight)
        return CGSize(width: keyWidth, height: keyHeightValue)
    }

    // Korean mode layout (7 columns × 4 rows, all rows uniform width)
    // Left column: special symbols, Center: consonants, Right column: backspace/vowel primitives
    static let koreanLayout: [[KeyContent]] = [
        [.symbol("~"), .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol("#")],
        [.symbol("^"), .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .backspace],
        [.symbol(";"), .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .vowelPrimitive(.bar)],
        [.symbol("*"), .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .vowelPrimitive(.dash), .vowelPrimitive(.dot)],
    ]

    // Symbol mode layout.
    // Same 7-col × 4-row geometry as Korean layout. Backspace at row 1 col 6
    // (matching Korean mode), col 6 = 1.3x sideWidth for unified grid alignment.
    // Digits are centered: row 0=1-3, row 1=4-6, row 2=7-9, row 3=*0#.
    static let symbolLayout: [[KeyContent]] = [
        [.symbol("~"), .symbol("!"), .symbol("1"), .symbol("2"), .symbol("3"), .symbol("@"), .symbol("$")],
        [.symbol("%"), .symbol("^"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("&"), .backspace],
        [.symbol("="), .symbol("-"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol("+"), .symbol(")")],
        [.symbol("/"), .symbol("?"), .symbol("*"), .symbol("0"), .symbol("#"), .symbol(":"), .symbol("(")],
    ]

    /// English QWERTY layout (4 rows: numbers + 3 letter rows).
    /// All keys are equal-width; sideKey ratio does not apply.
    /// Row 0: 1 2 3 4 5 6 7 8 9 0 (10 numbers)
    /// Row 1: q w e r t y u i o p (10)
    /// Row 2: a s d f g h j k l (9, centered)
    /// Row 3: shift z x c v b n m backspace (9, all equal-width)
    static let englishLayout: [[KeyContent]] = [
        [.symbol("1"), .symbol("2"), .symbol("3"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol("0")],
        [.symbol("q"), .symbol("w"), .symbol("e"), .symbol("r"), .symbol("t"), .symbol("y"), .symbol("u"), .symbol("i"), .symbol("o"), .symbol("p")],
        [.symbol("a"), .symbol("s"), .symbol("d"), .symbol("f"), .symbol("g"), .symbol("h"), .symbol("j"), .symbol("k"), .symbol("l")],
        [.functional(.shift), .symbol("z"), .symbol("x"), .symbol("c"), .symbol("v"), .symbol("b"), .symbol("n"), .symbol("m"), .backspace],
    ]

    // Long press number mapping for Korean mode
    // Only basic consonants (row 1-2) have number mappings
    // ㅂㅈㄷㄱㅅ → 1 2 3 4 5
    // ㅁㄴㅇㄹㅎ → 6 7 8 9 0
    // Long-press numbers aligned with SecondaryKeyAction.defaults
    // Row 0: ㅃ=1, ㅉ=2, ㄸ=3, ㄲ=4, ㅆ=5
    // Row 1: ㅂ=6, ㅈ=7, ㄷ=8, ㄱ=9, ㅅ=0
    // Row 2: ㅁ=,  ㄴ=.  ㅇ=?  ㄹ=!  ㅎ='
    // Row 3: ㅋ=:  ㅌ=@  ㅊ=₩  ㅍ=…
    static let longPressNumbers: [[String?]] = [
        [nil, "1", "2", "3", "4", "5", nil],   // row 0 (ㅃㅉㄸㄲㅆ)
        [nil, "6", "7", "8", "9", "0", nil],   // row 1 (ㅂㅈㄷㄱㅅ + backspace)
        [nil, ",", ".", "?", "!", "'", nil],   // row 2 (ㅁㄴㅇㄹㅎ + ㅣ)
        [nil, ":", "@", "₩", "…", nil, nil],   // row 3 (ㅋㅌㅊㅍ + ㅡ + ㆍ)
    ]

    // Get key content at grid position for given mode
    static func keyContent(at row: Int, column: Int, isSymbolMode: Bool) -> KeyContent? {
        let layout = isSymbolMode ? symbolLayout : koreanLayout
        guard row >= 0 && row < layout.count,
              column >= 0 && column < layout[row].count else {
            return nil
        }
        return layout[row][column]
    }

    /// Mode-aware key lookup. Preferred over the boolean variant for new call sites.
    static func keyContent(at row: Int, column: Int, mode: KeyboardMode) -> KeyContent? {
        let layout = activeLayout(for: mode)
        guard row >= 0 && row < layout.count,
              column >= 0 && column < layout[row].count else {
            return nil
        }
        return layout[row][column]
    }

    // Get consonant at grid position (for Korean mode only)
    static func consonant(at row: Int, column: Int) -> Choseong? {
        guard let content = keyContent(at: row, column: column, isSymbolMode: false) else {
            return nil
        }
        if case .consonant(let choseong) = content {
            return choseong
        }
        return nil
    }

    // Get long press number for position
    static func longPressNumber(at row: Int, column: Int) -> String? {
        guard row >= 0 && row < longPressNumbers.count,
              column >= 0 && column < longPressNumbers[row].count else {
            return nil
        }
        return longPressNumbers[row][column]
    }

    // MARK: - Bimanual Layout

    /// Bimanual layout metrics
    static let bimanualColumnCount = 5
    static let bimanualRowCount = 4
    static let vowelColumnWidth: CGFloat = 44.0

    /// Bimanual layout (5 columns × 4 rows of consonants)
    /// Plus right-side vowel primitives and bottom function row
    static let bimanualConsonantGrid: [[KeyContent]] = [
        // Row 1: Double consonants
        [.consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ)],
        // Row 2: Basic consonants
        [.consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ)],
        // Row 3: Remaining consonants
        [.consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ)],
        // Row 4: Bottom consonants
        [.consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspace],
    ]

    /// Right-side vowel primitive column
    static let vowelPrimitiveColumn: [KeyContent] = [
        .vowelPrimitive(.dot),   // ㆍ
        .vowelPrimitive(.bar),   // ㅣ
        .vowelPrimitive(.dash),  // ㅡ
    ]

    /// Bottom function row for bimanual layout
    static let bimanualFunctionRow: [KeyContent] = [
        .functional(.languageSwitch),  // Short tap: special chars / Long: system switch
        .functional(.modeToggle),      // Korean ↔ Symbol (123)
        .quickPunctuation(","),
        .functional(.space),
        .quickPunctuation("."),
        .functional(.returnKey),
    ]

    private static let columnMap: [Choseong: Int] = [
        .ㅃ: 1, .ㅂ: 1, .ㅁ: 1, .ㅋ: 1,
        .ㅉ: 2, .ㅈ: 2, .ㄴ: 2, .ㅌ: 2,
        .ㄸ: 3, .ㄷ: 3, .ㅇ: 3, .ㅊ: 3,
        .ㄲ: 4, .ㄱ: 4, .ㄹ: 4, .ㅍ: 4,
        .ㅆ: 5, .ㅅ: 5, .ㅎ: 5,
    ]

    /// Get the column index (1-5) for a consonant key in bimanual layout
    static func columnIndex(for choseong: Choseong) -> Int {
        return columnMap[choseong] ?? 3
    }
}

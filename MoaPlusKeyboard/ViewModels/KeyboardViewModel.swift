import SwiftUI
import Combine

// MARK: - Shift State

enum ShiftState: Equatable {
    case off
    case on        // single shot — auto-disables after one letter
    case locked    // caps lock — stays on until tapped again
}

// MARK: - Separated State Objects (reduce unnecessary redraws)

/// Gesture-related state — only GestureOverlayView observes this
class GestureState: ObservableObject {
    @Published var activeKey: (row: Int, column: Int)?
    @Published var previewVowel: Jungseong?
    @Published var directions: [GestureDirection] = []
    @Published var startPoint: CGPoint?
}

/// Long-press popup state — only popup overlay observes this
class PopupState: ObservableObject {
    @Published var text: String?
    @Published var candidates: [String] = []
    @Published var selectedIndex: Int = 0
}

// MARK: - ViewModel

class KeyboardViewModel: ObservableObject {
    let gestureState = GestureState()
    let popupState = PopupState()

    @Published var keyboardMode: KeyboardMode = .korean
    @Published var isSpecialCharLayerVisible: Bool = false
    @Published var shiftState: ShiftState = .off

    private var lastShiftTapTimestamp: Date?
    private static let doubleTapInterval: TimeInterval = 0.3

    /// Read-only convenience for callers that only ask "are we in a
    /// symbol layer right now?". Mode is mutated through `toggleSymbolMode()`
    /// or by assigning `keyboardMode` directly.
    var isSymbolMode: Bool { keyboardMode.isSymbol }
    @Published var isAbbreviationCandidateVisible: Bool = false
    @Published var abbreviationCandidate: ShortcutExpansion?
    @Published var abbreviationCandidates: [ShortcutExpansion] = []

    // Forwarding properties for backward compatibility
    var activeKey: (row: Int, column: Int)? {
        get { gestureState.activeKey }
        set { gestureState.activeKey = newValue }
    }
    var previewVowel: Jungseong? {
        get { gestureState.previewVowel }
        set { gestureState.previewVowel = newValue }
    }
    var gestureDirections: [GestureDirection] {
        get { gestureState.directions }
        set { gestureState.directions = newValue }
    }
    var gestureStartPoint: CGPoint? {
        get { gestureState.startPoint }
        set { gestureState.startPoint = newValue }
    }
    var longPressPopupText: String? {
        get { popupState.text }
        set { popupState.text = newValue }
    }
    var longPressPopupCandidates: [String] {
        get { popupState.candidates }
        set { popupState.candidates = newValue }
    }
    var longPressPopupSelectedIndex: Int {
        get { popupState.selectedIndex }
        set { popupState.selectedIndex = newValue }
    }

    private let composer = HangulComposer()
    private let gestureAnalyzer = GestureAnalyzer()
    private let vowelResolver = VowelResolver()
    private let abbreviationEngine = AbbreviationEngine()

    private var lastExpansionCount: Int = -1

    /// Reload abbreviation engine when settings change.
    /// Always syncs the master toggle so the user can flip the global
    /// switch without re-entering the keyboard. The trigger trie is only
    /// rebuilt when the expansion count actually changed.
    private func reloadAbbreviationEngine() {
        abbreviationEngine.delegate = self
        abbreviationEngine.isEnabled = KeyboardSettings.shared.abbreviationEnabled

        let currentCount = KeyboardSettings.shared.shortcutExpansionStore.expansions.count
        guard currentCount != lastExpansionCount else { return }
        lastExpansionCount = currentCount
        abbreviationEngine.loadExpansions(KeyboardSettings.shared.shortcutExpansionStore)
    }

    /// Tracks the last composing text to enable incremental updates
    private var lastComposingText: String = ""

    private let backspaceRepeatInitialDelay: TimeInterval
    private var isBackspacePressing = false
    private var backspaceInitialDelayTimer: Timer?
    private var backspaceRepeatTimer: Timer?
    private var backspaceAccelTimer: Timer?
    private var backspaceDeleteCount: Int = 0
    private var didHandleLongPressNumberInCurrentGesture = false
    /// Set when long-press on the English shift key has already toggled
    /// caps lock; the trailing tap (fired when the finger lifts) must be
    /// suppressed, otherwise it would call `toggleShift()` and immediately
    /// undo the lock.
    private var didHandleShiftLongPressInCurrentGesture = false

    weak var delegate: KeyboardViewModelDelegate?

    init(backspaceRepeatInitialDelay: TimeInterval = 0.4) {
        self.backspaceRepeatInitialDelay = backspaceRepeatInitialDelay
        reloadAbbreviationEngine()
    }

    /// Push the live center-key width into the gesture analyzer so the
    /// proportional swipe thresholds adapt to the current device. The
    /// view layer owns the geometry; this method is the only seam.
    func setCenterKeyWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        gestureAnalyzer.keyWidth = width
    }

    deinit {
        stopBackspaceRepeat()
    }

    var composingText: String {
        composer.displayText
    }

    // MARK: - Mode Toggle

    func toggleSymbolMode() {
        stopBackspaceRepeat()
        commitCurrent()
        keyboardMode = keyboardMode.toggleSymbol()
        triggerHapticFeedback()
    }

    func toggleLetterMode() {
        stopBackspaceRepeat()
        commitCurrent()
        keyboardMode = keyboardMode.toggleLetter()
        // Abbreviation engine applies in both Korean and English; reset the
        // buffer so half-typed triggers don't leak across modes.
        abbreviationEngine.resetBuffer()
        shiftState = .off  // reset shift when switching language mode
        triggerHapticFeedback()
    }

    func toggleShift() {
        let now = Date()
        let isDoubleTap: Bool = {
            guard let last = lastShiftTapTimestamp else { return false }
            return now.timeIntervalSince(last) < Self.doubleTapInterval
        }()
        lastShiftTapTimestamp = now

        if isDoubleTap {
            shiftState = .locked
        } else {
            switch shiftState {
            case .off:    shiftState = .on
            case .on:     shiftState = .off
            case .locked: shiftState = .off
            }
        }
        triggerHapticFeedback()
    }

    /// Set caps-lock unconditionally. Wired to long-press on the shift
    /// key — matches the platform-standard expectation that holding
    /// shift toggles the lock without needing a precise double-tap.
    /// Marks the gesture as long-press-handled so the tap fired when the
    /// finger lifts doesn't toggle the state right back off.
    func lockShift() {
        guard keyboardMode == .english else { return }
        shiftState = (shiftState == .locked) ? .off : .locked
        lastShiftTapTimestamp = nil
        didHandleShiftLongPressInCurrentGesture = true
        triggerHapticFeedback()
    }

    /// Apply shift to a letter symbol. Auto-releases .on to .off after consuming one letter.
    private func shiftedSymbolIfNeeded(_ symbol: String) -> String {
        guard keyboardMode == .english else { return symbol }
        switch shiftState {
        case .off:
            return symbol
        case .on:
            let result = symbol.uppercased()
            shiftState = .off
            return result
        case .locked:
            return symbol.uppercased()
        }
    }

    // MARK: - Input Methods

    func inputConsonant(_ consonant: Choseong) {
        let action = composer.inputChoseong(consonant)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    func inputVowel(_ vowel: Jungseong) {
        let action = composer.inputJungseong(vowel)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    /// Input a vowel primitive (천지인 ㅣ/ㅡ/ㆍ).
    /// All three feed the Hangul composer as `Jungseong` values; ㆍ is held
    /// as a transient pending vowel that combines with subsequent input
    /// (ㆍ + ㅣ = ㅓ, ㅣ + ㆍ = ㅏ, …). See HangulComposer.combineVowels.
    func inputVowelPrimitive(_ primitive: VowelPrimitiveType) {
        let vowel: Jungseong
        switch primitive {
        case .bar:  vowel = .ㅣ
        case .dash: vowel = .ㅡ
        case .dot:  vowel = .ㆍ
        }
        inputVowel(vowel)
    }

    private static let bracketPairs: [String: String] = [
        "(": ")", "[": "]", "{": "}", "<": ">",
        "「": "」", "『": "』", "《": "》", "【": "】", "〔": "〕"
    ]

    private static let closingBrackets: Set<String> = [")", "]", "}", ">", "」", "』", "》", "】", "〕"]

    func inputSymbol(_ symbol: String) {
        let resolved = shiftedSymbolIfNeeded(symbol)
        commitCurrent()
        if insertWithAutoBracket(resolved) {
            // Bracket pair inserted with cursor positioned
        } else {
            delegate?.insertText(resolved)
        }
        if resolved.count == 1, let char = resolved.first {
            abbreviationEngine.processCharacter(char)
        }
        triggerHapticFeedback()
    }

    func inputNumber(_ number: String) {
        commitCurrent()
        if insertWithAutoBracket(number) {
            // Bracket pair inserted
        } else {
            delegate?.insertText(number)
        }
        triggerHapticFeedback()
    }

    /// Insert opening bracket + closing bracket, then move cursor back between them.
    /// Returns true if auto-bracket was applied.
    private func insertWithAutoBracket(_ text: String) -> Bool {
        guard KeyboardSettings.shared.autoBracketEnabled,
              let closing = Self.bracketPairs[text] else { return false }
        delegate?.insertText(text + closing)
        // Move cursor back 1 position (between the brackets)
        if let vc = delegate as? KeyboardViewController {
            vc.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        }
        return true
    }

    func inputLongPressNumber(_ number: String) {
        didHandleLongPressNumberInCurrentGesture = true

        // Load popup candidates from secondary action
        if let activeRow = activeKey?.row, let activeCol = activeKey?.column {
            let content = KeyboardMetrics.keyContent(at: activeRow, column: activeCol, mode: keyboardMode)

            let keyId: String? = {
                switch content {
                case .consonant(let choseong):
                    return String(choseong.compatibilityCharacter)
                case .symbol(let s) where keyboardMode == .english && s.first?.isNumber == true:
                    return s
                default:
                    return nil
                }
            }()

            if let keyId, let action = KeyboardSettings.shared.secondaryAction(forKey: keyId) {
                let filtered = KeyboardSettings.shared.autoBracketEnabled
                    ? action.popupOutputs.filter { !Self.closingBrackets.contains($0) }
                    : action.popupOutputs
                longPressPopupCandidates = filtered
                longPressPopupSelectedIndex = 0
            }
        }

        longPressPopupText = number
        // Don't input yet - wait for drag selection or release
    }

    /// Whether the active key is on the right edge (column 5 or 6) — drag direction is reversed
    private var isRightEdgeKey: Bool {
        guard let col = activeKey?.column else { return false }
        return col >= 5
    }

    /// Called when user drags over popup candidates
    func updatePopupSelection(translationX: CGFloat) {
        guard !longPressPopupCandidates.isEmpty else { return }
        let cellWidth: CGFloat = 40
        // Right-edge keys: left drag = next candidate (negate translationX)
        let effectiveX = isRightEdgeKey ? -translationX : translationX
        let index = Int(effectiveX / cellWidth)
        let clamped = max(0, min(index, longPressPopupCandidates.count - 1))
        if clamped != longPressPopupSelectedIndex {
            longPressPopupSelectedIndex = clamped
            HapticManager.shared.playTap()
        }
    }

    /// Called when user releases after long-press drag
    func confirmPopupSelection() {
        if !longPressPopupCandidates.isEmpty {
            let selected = longPressPopupCandidates[longPressPopupSelectedIndex]
            inputNumber(selected)
        } else if let text = longPressPopupText {
            inputNumber(text)
        }
        dismissPopup()
    }

    func dismissPopup() {
        longPressPopupText = nil
        longPressPopupCandidates = []
        longPressPopupSelectedIndex = 0
        // Reset gesture visual state so hints restore immediately after popup ends
        activeKey = nil
        previewVowel = nil
        gestureDirections = []
        gestureStartPoint = nil
    }

    func deleteBackward() {
        if abbreviationEngine.processBackspace() {
            triggerHapticFeedback()
            return
        }
        let action = composer.deleteBackward()
        if action == .none {
            delegate?.deleteBackward()
        } else {
            handleComposerAction(action)
        }
        triggerHapticFeedback()
    }

    func inputSpace() {
        // Commit composing text first (feeds abbreviation engine via commitCurrent)
        commitCurrent()
        // Process delimiter - if abbreviation matches, delegate handles replacement
        // The engine's delegate callback will insert replacement + delimiter
        abbreviationEngine.processCharacter(" ")
        // If no abbreviation matched, insert space normally
        if !abbreviationEngine.canRestoreLastExpansion {
            delegate?.insertText(" ")
        }
        triggerHapticFeedback()
    }

    func inputReturn() {
        commitCurrent()
        abbreviationEngine.processCharacter("\n")
        if !abbreviationEngine.canRestoreLastExpansion {
            delegate?.insertText("\n")
        }
        triggerHapticFeedback()
    }

    func switchKeyboard() {
        stopBackspaceRepeat()
        commitCurrent()
        delegate?.switchToNextKeyboard()
    }

    /// Move cursor by character offset.
    /// Treats the currently composing character as committed (frozen at old cursor position),
    /// resets composer + abbreviation buffer, then asks delegate to adjust proxy cursor.
    func moveCursor(by offset: Int) {
        guard offset != 0 else { return }
        // Freeze any in-progress composition at its current screen position.
        // commitCurrent() clears internal state without touching the proxy.
        commitCurrent()
        // Cursor moves invalidate abbreviation context — reset trie matching state.
        abbreviationEngine.resetBuffer()
        delegate?.moveCursor(by: offset)
    }

    func toggleSpecialCharLayer() {
        isSpecialCharLayerVisible.toggle()
        if isSpecialCharLayerVisible {
            HapticManager.shared.playLayerSwitch()
        }
    }

    func confirmAbbreviation(_ expansion: ShortcutExpansion? = nil) {
        if let expansion = expansion {
            // Confirm specific candidate from multi-choice
            abbreviationEngine.confirmSpecificCandidate(expansion)
        } else {
            abbreviationEngine.confirmPendingCandidate()
        }
        isAbbreviationCandidateVisible = false
        abbreviationCandidate = nil
        abbreviationCandidates = []
    }

    func dismissAbbreviation() {
        abbreviationEngine.dismissPendingCandidate()
        isAbbreviationCandidateVisible = false
        abbreviationCandidate = nil
    }

    func beginBackspacePress() {
        guard !isBackspacePressing else { return }

        isBackspacePressing = true
        deleteBackward()  // Immediate delete on touch-down.
        startBackspaceRepeat()
    }

    func endBackspacePress() {
        stopBackspaceRepeat()
    }

    // MARK: - Gesture Handling

    func gestureStarted(row: Int, column: Int, at point: CGPoint) {
        didHandleLongPressNumberInCurrentGesture = false
        didHandleShiftLongPressInCurrentGesture = false
        activeKey = (row, column)
        gestureStartPoint = point
        gestureAnalyzer.settings = KeyboardSettings.shared.gestureSettings
        vowelResolver.swipeProfile = KeyboardSettings.shared.gestureSettings.swipeProfile
        // Set columnId before reset() so per-column correction applies from the first touch point.
        // reset() does not clear columnId, but we set it here to prevent leaking the previous key's value.
        if keyboardMode == .korean,
           let content = KeyboardMetrics.keyContent(at: row, column: column, mode: .korean),
           case .consonant(let consonant) = content {
            gestureAnalyzer.columnId = KeyboardMetrics.columnIndex(for: consonant)
        } else {
            gestureAnalyzer.columnId = 0
        }
        gestureAnalyzer.reset()
        gestureAnalyzer.addPoint(point)
        gestureDirections = []
        previewVowel = nil
    }

    func gestureMoved(to point: CGPoint) {
        gestureAnalyzer.addPoint(point)
        let directions = gestureAnalyzer.getDirections()
        gestureDirections = directions

        // Update preview vowel based on active key type so preview matches actual output.
        // Vowel primitive keys (ㅣ, ㅡ) use the same resolver as input commit;
        // consonant keys use the 8-direction VowelResolver pattern trie.
        if let key = activeKey,
           let content = KeyboardMetrics.keyContent(at: key.row, column: key.column, mode: keyboardMode) {
            switch content {
            case .vowelPrimitive(let primitive):
                previewVowel = resolveVowelFromPrimitiveDrag(primitive: primitive, directions: directions)
            case .consonant:
                previewVowel = vowelResolver.peekVowel(directions: directions)
            default:
                previewVowel = nil
            }
        } else {
            previewVowel = vowelResolver.peekVowel(directions: directions)
        }
    }

    func gestureEnded(row: Int, column: Int) {
        if didHandleLongPressNumberInCurrentGesture {
            didHandleLongPressNumberInCurrentGesture = false
            resetGestureState()
            return
        }
        if didHandleShiftLongPressInCurrentGesture {
            didHandleShiftLongPressInCurrentGesture = false
            resetGestureState()
            return
        }

        switch keyboardMode {
        case .symbolFromKorean, .symbolFromEnglish:
            handleSymbolModeTap(row: row, column: column)
        case .english:
            handleEnglishModeTap(row: row, column: column)
        case .korean:
            handleKoreanModeGesture(row: row, column: column)
        }

        resetGestureState()
    }

    private func handleSymbolModeTap(row: Int, column: Int) {
        guard let content = KeyboardMetrics.keyContent(at: row, column: column, mode: keyboardMode) else { return }

        switch content {
        case .symbol(let symbol):
            inputSymbol(symbol)
        case .backspace:
            deleteBackward()
        default:
            break
        }
    }

    private func handleEnglishModeTap(row: Int, column: Int) {
        guard let content = KeyboardMetrics.keyContent(at: row, column: column, mode: .english) else { return }

        switch content {
        case .symbol(let symbol):
            inputSymbol(symbol)
        case .backspace:
            deleteBackward()
        case .functional(let kind):
            switch kind {
            case .shift: toggleShift()
            default: break
            }
        default:
            break
        }
    }

    private func handleKoreanModeGesture(row: Int, column: Int) {
        let directions = gestureAnalyzer.finalizeGesture()

        guard let content = KeyboardMetrics.keyContent(at: row, column: column, mode: .korean) else { return }

        switch content {
        case .consonant(let consonant):
            if directions.isEmpty {
                // No gesture - treat as tap
                inputConsonant(consonant)
            } else {
                // Gesture completed - input consonant + vowel
                inputConsonant(consonant)

                let resolution = vowelResolver.resolve(directions: directions)
                if let vowel = resolution.vowel {
                    inputVowel(vowel)
                }
            }

        case .symbol(let symbol):
            inputSymbol(symbol)

        case .backspace:
            deleteBackward()

        case .vowelPrimitive(let primitive):
            if directions.isEmpty {
                inputVowelPrimitive(primitive)
            } else {
                if let vowel = resolveVowelFromPrimitiveDrag(primitive: primitive, directions: directions) {
                    inputVowel(vowel)
                } else {
                    inputVowelPrimitive(primitive)
                }
            }

        default:
            break
        }
    }

    // MARK: - Public State Reset (for external text field changes)

    func resetComposer() {
        // Reset composer state when text field changes externally
        // (e.g., when user sends a message and the app clears the field)
        stopBackspaceRepeat()
        lastComposingText = ""
        composer.reset()
    }

    /// Resets gesture tracking state only. Intentionally does NOT reset composer
    /// or lastComposingText to preserve in-progress Hangul composition.
    func resetGestureState() {
        stopBackspaceRepeat()
        didHandleLongPressNumberInCurrentGesture = false
        didHandleShiftLongPressInCurrentGesture = false
        dismissPopup()
        activeKey = nil
        gestureStartPoint = nil
        gestureDirections = []
        previewVowel = nil
        gestureAnalyzer.reset()
        // Reload abbreviation store in case user changed settings
        reloadAbbreviationEngine()
    }

    // MARK: - Private Helpers

    /// Map a drag direction on a vowel primitive key to a Jungseong.
    /// Diagonal directions are normalised to the nearest cardinal before lookup.
    /// First stroke produces the base vowel (PR G6); subsequent strokes fold
    /// into compound vowels (PR G14 — ㅘ ㅙ ㅚ ㅝ ㅞ ㅟ ㅔ ㅐ ㅖ ㅒ).
    /// Returns nil if the primitive has no mapping (e.g. .dot).
    func resolveVowelFromPrimitiveDrag(primitive: VowelPrimitiveType, directions: [GestureDirection]) -> Jungseong? {
        guard let first = directions.first else { return nil }

        // First stroke: base vowel
        let cardinal1 = normalizedCardinal(first)
        guard var current = baseVowelFor(primitive: primitive, direction: cardinal1) else {
            return nil
        }

        // Additional strokes: fold into compound vowels.
        // applySecondaryStroke == nil → keep prior vowel (ignore noise).
        for direction in directions.dropFirst() {
            let cardinal = normalizedCardinal(direction)
            if let combined = applySecondaryStroke(current, primitive: primitive, direction: cardinal) {
                current = combined
            }
        }
        return current
    }

    private func normalizedCardinal(_ direction: GestureDirection) -> GestureDirection {
        switch direction {
        case .upLeft, .upRight:     return .up
        case .downLeft, .downRight: return .down
        default:                    return direction
        }
    }

    private func baseVowelFor(primitive: VowelPrimitiveType, direction: GestureDirection) -> Jungseong? {
        switch primitive {
        case .bar:   // ㅣ key: ←ㅓ →ㅏ ↑ㅕ ↓ㅑ
            switch direction {
            case .left:  return .ㅓ
            case .right: return .ㅏ
            case .up:    return .ㅕ
            case .down:  return .ㅑ
            default:     return nil
            }
        case .dash:  // ㅡ key: ↑ㅗ ↓ㅜ ←ㅛ →ㅠ
            switch direction {
            case .up:    return .ㅗ
            case .down:  return .ㅜ
            case .left:  return .ㅛ
            case .right: return .ㅠ
            default:     return nil
            }
        case .dot:   // ㆍ key: no drag mapping
            return nil
        }
    }

    /// Fold an additional stroke into the running vowel.
    /// Returns nil if the stroke doesn't produce a known compound — caller
    /// then keeps the previous vowel intact.
    private func applySecondaryStroke(_ current: Jungseong, primitive: VowelPrimitiveType, direction: GestureDirection) -> Jungseong? {
        switch primitive {
        case .dash:
            switch (current, direction) {
            // ㅗ → ㅘ (→) / ㅚ (←,↓ 역방향)
            case (.ㅗ, .right): return .ㅘ
            case (.ㅗ, .left):  return .ㅚ
            case (.ㅗ, .down):  return .ㅚ
            // ㅘ → ㅙ (어느 방향이든 추가 stroke로 ㅣ 합성)
            case (.ㅘ, .left):  return .ㅙ
            case (.ㅘ, .right): return .ㅙ
            case (.ㅘ, .up):    return .ㅙ
            case (.ㅘ, .down):  return .ㅙ
            // ㅜ → ㅝ (←) / ㅟ (→,↑ 역방향)
            case (.ㅜ, .left):  return .ㅝ
            case (.ㅜ, .right): return .ㅟ
            case (.ㅜ, .up):    return .ㅟ
            // ㅝ → ㅞ (어느 방향이든 추가 stroke로 ㅣ 합성)
            case (.ㅝ, .left):  return .ㅞ
            case (.ㅝ, .right): return .ㅞ
            case (.ㅝ, .up):    return .ㅞ
            case (.ㅝ, .down):  return .ㅞ
            default: return nil
            }
        case .bar:
            switch (current, direction) {
            // ㅓ → ㅔ (→ 또는 수직 perpendicular stroke로 ㅣ 추가)
            case (.ㅓ, .right): return .ㅔ
            case (.ㅓ, .up):    return .ㅔ
            case (.ㅓ, .down):  return .ㅔ
            // ㅏ → ㅐ (← 또는 수직 perpendicular stroke로 ㅣ 추가)
            case (.ㅏ, .left):  return .ㅐ
            case (.ㅏ, .up):    return .ㅐ
            case (.ㅏ, .down):  return .ㅐ
            // ㅕ → ㅖ (수평 ←/→ 또는 ↓ 역방향)
            case (.ㅕ, .right): return .ㅖ
            case (.ㅕ, .left):  return .ㅖ
            case (.ㅕ, .down):  return .ㅖ
            // ㅑ → ㅒ (수평 ←/→ 또는 ↑ 역방향)
            case (.ㅑ, .right): return .ㅒ
            case (.ㅑ, .left):  return .ㅒ
            case (.ㅑ, .up):    return .ㅒ
            default: return nil
            }
        case .dot:
            return nil
        }
    }

    private func handleComposerAction(_ action: HangulComposer.ComposerAction) {
        switch action {
        case .none:
            break
        case .update:
            updateComposingText()
        case .commit, .commitAndUpdate, .commitAndCommit:
            let committed = composer.flushCommittedText()

            // 1. First, delete the composing text currently on screen
            for _ in lastComposingText {
                delegate?.deleteBackward()
            }
            lastComposingText = ""

            // 2. Insert the committed text
            if !committed.isEmpty {
                delegate?.insertText(committed)
                abbreviationEngine.processComposedText(committed)
            }

            // 3. Update with the new composing character (if any)
            updateComposingText()
        case .delete:
            // If there's composing text, delete it; otherwise pass through to delegate
            if !lastComposingText.isEmpty {
                // Clear the composing text from screen
                for _ in lastComposingText {
                    delegate?.deleteBackward()
                }
                lastComposingText = ""
            } else {
                delegate?.deleteBackward()
            }
            updateComposingText()
        }
    }

    private func updateComposingText() {
        // composingDisplay returns the full multi-character string for
        // dotPending states (e.g. "ㅇㆍㆍ"). Single-character states still
        // return one Character's worth of text.
        let composing = composer.composingDisplay
        let previous = lastComposingText
        lastComposingText = composing
        delegate?.updateComposingText(from: previous, to: composing)
    }

    private func commitCurrent() {
        // The composing character is already on screen, so just reset state
        // without inserting it again.
        // Feed the current composing text to abbreviation engine before resetting.
        if !lastComposingText.isEmpty {
            abbreviationEngine.processComposedText(lastComposingText)
        }
        lastComposingText = ""
        composer.reset()
    }

    private func commitAndInsert(_ text: String) {
        commitCurrent()
        delegate?.insertText(text)
    }

    private func triggerHapticFeedback() {
        delegate?.triggerHapticFeedback()
    }

    private func startBackspaceRepeat() {
        backspaceDeleteCount = 0
        backspaceInitialDelayTimer?.invalidate()
        backspaceInitialDelayTimer = makeTimer(interval: backspaceRepeatInitialDelay, repeats: false) { [weak self] _ in
            guard let self, self.isBackspacePressing else { return }

            // Phase 1: character-by-character delete
            let repeatInterval = KeyboardSettings.shared.backspaceRepeatInterval
            self.backspaceRepeatTimer?.invalidate()
            self.backspaceRepeatTimer = self.makeTimer(interval: repeatInterval, repeats: true) { [weak self] _ in
                guard let self, self.isBackspacePressing else { return }
                self.backspaceDeleteCount += 1
                self.deleteBackward()
            }

            // Phase 2: switch to word-level delete (if enabled)
            if KeyboardSettings.shared.wordDeleteEnabled {
                let accelDelay = KeyboardSettings.shared.wordDeleteDelay
                self.backspaceAccelTimer?.invalidate()
                self.backspaceAccelTimer = self.makeTimer(interval: accelDelay, repeats: false) { [weak self] _ in
                    guard let self, self.isBackspacePressing else { return }
                    self.backspaceRepeatTimer?.invalidate()
                    self.backspaceRepeatTimer = self.makeTimer(interval: KeyboardMetrics.wordDeleteRepeatInterval, repeats: true) { [weak self] _ in
                        guard let self, self.isBackspacePressing else { return }
                        self.deleteWord()
                    }
                }
            }
        }
    }

    /// Delete one word (characters until previous space or line break)
    private func deleteWord() {
        // The runtime delegate is always `KeyboardViewController`; this
        // cast only fails in a unit-test stub. Tests don't exercise word
        // delete, so silently no-op rather than guess at character counts.
        guard let vc = delegate as? KeyboardViewController else { return }
        let before = vc.textDocumentProxy.documentContextBeforeInput ?? ""
        if before.isEmpty { return }

        // Find the last word boundary (space, newline, or punctuation)
        let trimmed = before.hasSuffix(" ") ? String(before.dropLast()) : before
        if let lastSpace = trimmed.lastIndex(where: { $0 == " " || $0 == "\n" }) {
            let charsToDelete = trimmed.distance(from: lastSpace, to: trimmed.endIndex)
            let total = before.count - (before.count - charsToDelete - (before.hasSuffix(" ") ? 1 : 0))
            for _ in 0..<max(total, 1) { delegate?.deleteBackward() }
        } else {
            // No space found — delete entire remaining text
            for _ in 0..<before.count { delegate?.deleteBackward() }
        }
    }

    private func stopBackspaceRepeat() {
        isBackspacePressing = false
        backspaceDeleteCount = 0
        backspaceInitialDelayTimer?.invalidate()
        backspaceInitialDelayTimer = nil
        backspaceRepeatTimer?.invalidate()
        backspaceRepeatTimer = nil
        backspaceAccelTimer?.invalidate()
        backspaceAccelTimer = nil
    }

    private func makeTimer(interval: TimeInterval, repeats: Bool, handler: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: handler)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

protocol KeyboardViewModelDelegate: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
    func updateComposingText(from previous: String, to current: String)
    func switchToNextKeyboard()
    func triggerHapticFeedback()
    func moveCursor(by offset: Int)
}

// MARK: - AbbreviationEngineDelegate

extension KeyboardViewModel: AbbreviationEngineDelegate {
    func abbreviationEngine(_ engine: AbbreviationEngine, shouldReplace trigger: String, with replacement: String, delimiter: Character) {
        // Suggestion-mode candidates are confirmed *after* the user typed
        // the delimiter, which by then was already inserted into the proxy
        // (`inputSpace`/`inputReturn` only suppresses insertion when the
        // engine immediately replaces — `.onDelimiter` mode). Strip that
        // trailing delimiter first so the deletion arithmetic matches both
        // confirmation paths. `.onDelimiter` confirmations skipped the
        // insertText, so this branch is a no-op there.
        if let vc = delegate as? KeyboardViewController,
           let before = vc.textDocumentProxy.documentContextBeforeInput,
           before.hasSuffix(trigger + String(delimiter)) {
            delegate?.deleteBackward()
        }
        // Delete trigger text from screen.
        // Each character was individually committed by the Hangul composer,
        // so we delete one-by-one. However, the last character may have been
        // left as composing text (not re-inserted via insertText), so we
        // delete trigger.count times plus account for any residual composing state.
        // To be safe, delete enough times and verify via documentContextBeforeInput.
        var remaining = trigger.count
        while remaining > 0 {
            delegate?.deleteBackward()
            remaining -= 1
        }
        // Composer state can leave the last character of the trigger uncommitted
        // when the engine fires; in that case the first `trigger.count` deletes
        // remove `trigger.count - 1` real characters and one composing char that
        // was already going to be replaced. If the *entire* trigger is still
        // visible after the first pass, do a second `trigger.count` pass — but
        // never more than that, and never on a partial suffix. Deleting partial
        // suffixes risked eating user-typed characters that happened to share a
        // prefix with the trigger.
        if let vc = delegate as? KeyboardViewController,
           let before = vc.textDocumentProxy.documentContextBeforeInput,
           before.hasSuffix(trigger) {
            for _ in 0..<trigger.count {
                delegate?.deleteBackward()
            }
        }
        // Insert the replacement + delimiter
        delegate?.insertText(replacement + String(delimiter))
        HapticManager.shared.playAbbreviationConfirm()
    }

    func abbreviationEngine(_ engine: AbbreviationEngine, showCandidateFor expansion: ShortcutExpansion) {
        abbreviationCandidate = expansion
        abbreviationCandidates = [expansion]
        isAbbreviationCandidateVisible = true
    }

    func abbreviationEngine(_ engine: AbbreviationEngine, showCandidatesFor expansions: [ShortcutExpansion]) {
        abbreviationCandidates = expansions
        abbreviationCandidate = expansions.first
        isAbbreviationCandidateVisible = true
    }

    func abbreviationEngineDidDismissCandidate(_ engine: AbbreviationEngine) {
        isAbbreviationCandidateVisible = false
        abbreviationCandidate = nil
        abbreviationCandidates = []
    }

    func abbreviationEngine(_ engine: AbbreviationEngine, shouldRestore original: String, removing replacement: String) {
        // Delete the replacement text
        for _ in 0..<replacement.count {
            delegate?.deleteBackward()
        }
        // Re-insert the original trigger
        delegate?.insertText(original)
    }
}

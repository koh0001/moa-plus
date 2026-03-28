import SwiftUI
import Combine

// ViewModel to handle keyboard logic
class KeyboardViewModel: ObservableObject {
    @Published var activeKey: (row: Int, column: Int)?
    @Published var previewVowel: Jungseong?
    @Published var gestureDirections: [GestureDirection] = []
    @Published var gestureStartPoint: CGPoint?
    @Published var isSymbolMode: Bool = false
    @Published var isSpecialCharLayerVisible: Bool = false
    @Published var isAbbreviationCandidateVisible: Bool = false
    @Published var abbreviationCandidate: ShortcutExpansion?
    @Published var abbreviationCandidates: [ShortcutExpansion] = []

    /// Long-press popup state (rendered at KeyboardView level to avoid z-order clipping)
    @Published var longPressPopupText: String?
    @Published var longPressPopupCandidates: [String] = []
    @Published var longPressPopupSelectedIndex: Int = 0

    private let composer = HangulComposer()
    private let gestureAnalyzer = GestureAnalyzer()
    private let vowelResolver = VowelResolver()
    private let abbreviationEngine = AbbreviationEngine()

    /// Reload abbreviation engine when settings change
    private func reloadAbbreviationEngine() {
        abbreviationEngine.delegate = self
        abbreviationEngine.loadExpansions(KeyboardSettings.shared.shortcutExpansionStore)
    }

    /// Tracks the last composing text to enable incremental updates
    private var lastComposingText: String = ""

    private let backspaceRepeatInitialDelay: TimeInterval
    private let backspaceRepeatInterval: TimeInterval
    private var isBackspacePressing = false
    private var backspaceInitialDelayTimer: Timer?
    private var backspaceRepeatTimer: Timer?
    private var backspaceAccelTimer: Timer?
    private var backspaceDeleteCount: Int = 0
    private var didHandleLongPressNumberInCurrentGesture = false

    weak var delegate: KeyboardViewModelDelegate?

    init(backspaceRepeatInitialDelay: TimeInterval = 0.4, backspaceRepeatInterval: TimeInterval = 0.08) {
        self.backspaceRepeatInitialDelay = backspaceRepeatInitialDelay
        self.backspaceRepeatInterval = backspaceRepeatInterval
        HapticManager.shared.updateSettings(KeyboardSettings.shared.themeSettings)
        reloadAbbreviationEngine()
    }

    deinit {
        stopBackspaceRepeat()
    }

    var composingText: String {
        composer.displayText
    }

    // MARK: - Mode Toggle

    func toggleMode() {
        stopBackspaceRepeat()
        commitCurrent()
        isSymbolMode.toggle()
        triggerHapticFeedback()
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

    private static let bracketPairs: [String: String] = [
        "(": ")", "[": "]", "{": "}", "<": ">",
        "「": "」", "『": "』", "《": "》", "【": "】", "〔": "〕"
    ]

    func inputSymbol(_ symbol: String) {
        commitCurrent()
        if insertWithAutoBracket(symbol) {
            // Bracket pair inserted with cursor positioned
        } else {
            delegate?.insertText(symbol)
        }
        if symbol.count == 1, let char = symbol.first {
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
        if let activeRow = activeKey?.row, let activeCol = activeKey?.column,
           let content = KeyboardMetrics.keyContent(at: activeRow, column: activeCol, isSymbolMode: false),
           case .consonant(let choseong) = content {
            let keyId = String(choseong.compatibilityCharacter)
            if let action = KeyboardSettings.shared.secondaryAction(forKey: keyId) {
                longPressPopupCandidates = action.popupOutputs
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
        activeKey = (row, column)
        gestureStartPoint = point
        gestureAnalyzer.settings = KeyboardSettings.shared.gestureSettings
        vowelResolver.swipeProfile = KeyboardSettings.shared.gestureSettings.swipeProfile
        gestureAnalyzer.reset()
        gestureAnalyzer.addPoint(point)
        gestureDirections = []
        previewVowel = nil
    }

    func gestureMoved(to point: CGPoint) {
        gestureAnalyzer.addPoint(point)
        let directions = gestureAnalyzer.getDirections()
        gestureDirections = directions

        // Update preview vowel (only meaningful for consonant keys)
        previewVowel = vowelResolver.peekVowel(directions: directions)
    }

    func gestureEnded(row: Int, column: Int) {
        if didHandleLongPressNumberInCurrentGesture {
            didHandleLongPressNumberInCurrentGesture = false
            resetGestureState()
            return
        }

        // In symbol mode, gesture handling is simpler - just tap
        if isSymbolMode {
            handleSymbolModeTap(row: row, column: column)
        } else {
            handleKoreanModeGesture(row: row, column: column)
        }

        resetGestureState()
    }

    private func handleSymbolModeTap(row: Int, column: Int) {
        guard let content = KeyboardMetrics.keyContent(at: row, column: column, isSymbolMode: true) else { return }

        switch content {
        case .symbol(let symbol):
            inputSymbol(symbol)
        case .backspace:
            deleteBackward()
        default:
            break
        }
    }

    private func handleKoreanModeGesture(row: Int, column: Int) {
        let directions = gestureAnalyzer.finalizeGesture()

        guard let content = KeyboardMetrics.keyContent(at: row, column: column, isSymbolMode: false) else { return }

        switch content {
        case .consonant(let consonant):
            gestureAnalyzer.columnId = KeyboardMetrics.columnIndex(for: consonant)
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
        let composing = composer.currentComposingCharacter.map { String($0) } ?? ""
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
                    self.backspaceRepeatTimer = self.makeTimer(interval: 0.12, repeats: true) { [weak self] _ in
                        guard let self, self.isBackspacePressing else { return }
                        self.deleteWord()
                    }
                }
            }
        }
    }

    /// Delete one word (characters until previous space or line break)
    private func deleteWord() {
        guard let vc = delegate as? KeyboardViewController else {
            // Fallback: just delete a few characters
            for _ in 0..<5 { delegate?.deleteBackward() }
            return
        }
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
}

// MARK: - AbbreviationEngineDelegate

extension KeyboardViewModel: AbbreviationEngineDelegate {
    func abbreviationEngine(_ engine: AbbreviationEngine, shouldReplace trigger: String, with replacement: String, delimiter: Character) {
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
        // Verify: if trigger text is still partially on screen, delete more
        if let vc = delegate as? KeyboardViewController {
            let before = vc.textDocumentProxy.documentContextBeforeInput ?? ""
            // Check if any trigger suffix remains
            for suffix in (1...trigger.count).reversed() {
                let triggerSuffix = String(trigger.prefix(suffix))
                if before.hasSuffix(triggerSuffix) {
                    for _ in 0..<suffix {
                        delegate?.deleteBackward()
                    }
                    break
                }
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

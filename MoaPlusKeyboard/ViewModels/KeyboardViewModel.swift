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

    /// Preview mode flag — when true, the slot B vowel key gesture routes to
    /// `onPreviewVowel` instead of feeding the composer/delegate. Used by the
    /// settings preview (LayoutCustomizationView) so the user can try the
    /// vowel key without affecting any text field. All other input methods
    /// (consonants, backspace, function keys) silently no-op in preview mode.
    var previewMode: Bool = false
    var onPreviewVowel: ((Jungseong) -> Void)? = nil
    /// Same as `onPreviewVowel` but also forwards the gesture start point in
    /// the named "keyboardPreview" coordinate space so callers can position
    /// UI relative to where the user touched (e.g. show a result bubble on
    /// the opposite half of the keyboard).
    var onPreviewVowelDetailed: ((Jungseong, CGPoint) -> Void)? = nil

    /// Phase markers for `onPreviewConsonantGesture` so callers (the gesture
    /// test screen) can distinguish in-flight previews from the final result
    /// without reverse-engineering the directions array. Carries the raw
    /// touch trail (`points`) and the production column id (`columnId`) so
    /// the abstract sector canvas can mirror what the user is doing on the
    /// real keyboard above without running its own gesture pipeline.
    enum PreviewGesturePhase {
        case began(startPoint: CGPoint, columnId: Int)
        case moved(currentPoint: CGPoint, points: [CGPoint], columnId: Int)
        case ended(points: [CGPoint], columnId: Int)
    }

    /// Fires from the consonant-key gesture pipeline while `previewMode` is
    /// on. Lets the gesture test screen visualise the same analyzer +
    /// resolver output the production keyboard uses, without affecting any
    /// host text field. `vowel` is the live/peek vowel during `.began`/`.moved`
    /// and the resolved final vowel on `.ended`.
    var onPreviewConsonantGesture: ((PreviewGesturePhase, [GestureDirection], Jungseong?) -> Void)? = nil

    /// Raw touch trail captured during a preview-mode consonant gesture so
    /// callers receive the full point list with each `.moved` / `.ended`
    /// phase. Reset on every `.began`.
    private var previewGesturePoints: [CGPoint] = []
    /// Last column id fed to the gesture analyzer during a preview-mode
    /// gesture. Forwarded in every preview phase so the abstract canvas
    /// can mirror the column-specific sector geometry of whichever key
    /// the user is touching on the real keyboard.
    private var previewGestureColumnId: Int = 0

    /// When `true`, the gesture overlay is always shown in Korean mode regardless
    /// of the global `showGesturePreview` setting. Set by `KeyboardPreviewView`
    /// when embedded in the gesture test screen so the direction trail is always
    /// visible while testing column-angle differences.
    var forceShowGesturePreview: Bool = false

    /// Captured at slot-B-vowel gesture start so it can be forwarded in the
    /// `onPreviewVowelDetailed` callback when the gesture ends.
    private var slotBVowelStartPoint: CGPoint = .zero

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
        // Restore last letter mode before first render so there is no flicker.
        let settings = KeyboardSettings.shared
        if settings.rememberLastKeyboardMode, settings.lastKeyboardLetterMode == "english" {
            keyboardMode = .english
        }
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
        if previewMode { return }
        stopBackspaceRepeat()
        commitCurrent()
        keyboardMode = keyboardMode.toggleSymbol()
        triggerHapticFeedback()
    }

    func toggleLetterMode() {
        if previewMode { return }
        stopBackspaceRepeat()
        commitCurrent()
        keyboardMode = keyboardMode.toggleLetter()
        // Abbreviation engine applies in both Korean and English; reset the
        // buffer so half-typed triggers don't leak across modes.
        abbreviationEngine.resetBuffer()
        shiftState = .off  // reset shift when switching language mode
        persistLetterModeIfEnabled()
        triggerHapticFeedback()
    }

    /// Persist the current letter mode to UserDefaults if the user opted in.
    /// Called after any operation that switches between Korean and English.
    private func persistLetterModeIfEnabled() {
        let settings = KeyboardSettings.shared
        guard settings.rememberLastKeyboardMode else { return }
        let raw = (keyboardMode.letterMode == .english) ? "english" : "korean"
        if settings.lastKeyboardLetterMode != raw {
            settings.lastKeyboardLetterMode = raw
        }
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

    // MARK: - Slot B Vowel Key (multi-stroke)
    //
    // Mirrors the consonant-key gesture pipeline (gestureStarted/Moved/Ended)
    // but produces a bare vowel — no consonant prefix. Routes points through
    // the same GestureAnalyzer + VowelResolver so the resolved Jungseong
    // covers ALL patterns (basic ㅏ/ㅓ/ㅗ/ㅜ/ㅡ/ㅣ, y-vowels ㅑ/ㅕ/ㅛ/ㅠ,
    // diphthongs ㅘ/ㅙ/ㅚ/ㅝ/ㅞ/ㅟ, ㅐ/ㅒ/ㅔ/ㅖ, ㅢ).
    // Tap (no drag) → ㆍ.

    func slotBVowelGestureStarted(at point: CGPoint) {
        gestureAnalyzer.settings = KeyboardSettings.shared.gestureSettings
        vowelResolver.swipeProfile = KeyboardSettings.shared.gestureSettings.swipeProfile
        // Slot B is not associated with any consonant column override.
        // slot B 는 자음 드래그 패턴(ㅢ 등 대각선 포함)을 쓰므로 카디널 강제 OFF.
        gestureAnalyzer.columnId = 0
        gestureAnalyzer.forceCardinalOnly = false
        gestureAnalyzer.reset()
        gestureAnalyzer.addPoint(point)
        slotBVowelStartPoint = point
        // Feed gestureState so GestureOverlayView activates for slot B too.
        // Sentinel (-1, -1) marks "slot B vowel key" (not a grid cell). The
        // overlay only checks startPoint + directions, so the row/col value
        // is for internal book-keeping; the existing popup gating uses
        // popupState.text and is unaffected.
        gestureStartPoint = point
        gestureDirections = []
        previewVowel = nil
        activeKey = (row: -1, column: -1)
    }

    func slotBVowelGestureMoved(to point: CGPoint) {
        gestureAnalyzer.addPoint(point)
        let directions = gestureAnalyzer.getDirections()
        gestureDirections = directions
        // Slot B is a bare-vowel key (no consonant prefix); the resolver's
        // pattern trie still gives the best matching Jungseong for preview.
        previewVowel = vowelResolver.peekVowel(directions: directions)
    }

    func slotBVowelGestureEnded() {
        let directions = gestureAnalyzer.finalizeGesture()
        gestureAnalyzer.reset()
        // Clear gestureState so the overlay disappears.
        activeKey = nil
        gestureStartPoint = nil
        gestureDirections = []
        previewVowel = nil
        if directions.isEmpty {
            // Tap with no drag → ㆍ (pending), matches prior behaviour.
            if previewMode {
                emitPreviewVowel(.ㆍ)
            } else {
                inputVowel(.ㆍ)
            }
            return
        }
        let resolution = vowelResolver.resolve(directions: directions)
        if let vowel = resolution.vowel {
            if previewMode {
                emitPreviewVowel(vowel)
            } else {
                inputVowel(vowel)
            }
        }
    }

    /// Fan-out for preview-mode vowel emission. Calls both the legacy
    /// `onPreviewVowel` and the detailed variant that forwards the gesture
    /// start point so callers (LayoutCustomizationView) can position UI
    /// relative to the user's touch.
    private func emitPreviewVowel(_ vowel: Jungseong) {
        onPreviewVowel?(vowel)
        onPreviewVowelDetailed?(vowel, slotBVowelStartPoint)
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

    func inputSymbol(_ symbol: String, bypassAutoBracket: Bool = false) {
        if previewMode { return }
        let resolved = shiftedSymbolIfNeeded(symbol)
        commitCurrent()
        if !bypassAutoBracket && insertWithAutoBracket(resolved) {
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
        if previewMode { return }
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
            let content = KeyboardMetrics.keyContent(at: activeRow, column: activeCol, mode: keyboardMode, layout: KeyboardSettings.shared.layoutCustomization)

            let keyId: String? = {
                switch content {
                case .consonant(let choseong):
                    return String(choseong.compatibilityCharacter)
                case .symbol(let s) where keyboardMode == .english && s.first?.isNumber == true:
                    return s
                case .symbol(let s) where keyboardMode.isSymbol:
                    return s
                default:
                    return nil
                }
            }()

            // Symbol-mode keys aren't in the user-editable secondaryKeyActions
            // store — fall back to the static iOS-standard alt table so the
            // popup pipeline still gets candidates.
            let action: SecondaryKeyAction? = {
                guard let keyId else { return nil }
                if let stored = KeyboardSettings.shared.secondaryAction(forKey: keyId) {
                    return stored
                }
                if keyboardMode.isSymbol {
                    return KeyboardMetrics.symbolModeSecondaryAction(for: keyId)
                }
                return nil
            }()

            if let action {
                // Auto-bracket filter applies only to letter-mode contexts
                // where the user expects the keyboard to auto-pair brackets.
                // Symbol mode is the explicit "give me this character"
                // surface — filtering closing brackets there hides the
                // long-press alts (e.g. ")" → "] } >").
                let shouldFilter = KeyboardSettings.shared.autoBracketEnabled && !keyboardMode.isSymbol
                let filtered = shouldFilter
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
        if previewMode { return }
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
        if previewMode { return }
        // Commit composing text first (feeds abbreviation engine via commitCurrent)
        commitCurrent()
        // An abbreviation that just expanded already inserted its own trailing
        // space (`replacement + " "`). Snapshot that BEFORE processCharacter
        // clears the flag: otherwise this space would be read as the user's
        // *first* space and the double-space→period shortcut would turn it into
        // ". " (e.g. "하트 " + space → "하트. "). commitCurrent() only clears the
        // flag when there was composing text to flush, so typing anything after
        // the expansion restores normal period behavior.
        let didJustExpandAbbreviation = abbreviationEngine.canRestoreLastExpansion
        // Process delimiter - if abbreviation matches, delegate handles replacement
        // The engine's delegate callback will insert replacement + delimiter
        abbreviationEngine.processCharacter(" ")
        // If no abbreviation matched, either apply the double-space → period
        // shortcut or insert a plain space.
        if !abbreviationEngine.canRestoreLastExpansion {
            if didJustExpandAbbreviation || !applyPeriodShortcut() {
                delegate?.insertText(" ")
            }
        }
        triggerHapticFeedback()
    }

    /// Double-space → period. When the user presses space and the text already
    /// ends with `<letter-or-digit><space>`, replace that trailing space with
    /// ". " — mirrors the iOS system keyboard shortcut. Returns true when the
    /// shortcut fired so the caller skips the plain space insertion.
    private func applyPeriodShortcut() -> Bool {
        guard KeyboardSettings.shared.periodOnDoubleSpaceEnabled else { return false }
        guard let before = delegate?.textBeforeCursor(), before.hasSuffix(" ") else { return false }
        // The character before the trailing space must be a letter or digit:
        // skips line starts, runs of spaces, and existing punctuation (so
        // "안녕. " + space doesn't become "안녕.. ").
        guard let preceding = before.dropLast().last,
              preceding.isLetter || preceding.isNumber else { return false }
        delegate?.deleteBackward()      // remove the existing trailing space
        delegate?.insertText(". ")
        return true
    }

    func inputReturn() {
        if previewMode { return }
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

    /// The user moved the caret by tapping directly in the host text field
    /// (not via our space-drag / `moveCursor`). iOS has already repositioned
    /// the caret, and the in-progress composing glyph is already rendered as
    /// plain text at its OLD position. Freeze composer state so the next
    /// keystroke starts a fresh composition at the new caret.
    ///
    /// Must NOT touch the proxy (no delete/insert/cursor move): the glyph is
    /// already committed visually, and `updateComposingText`'s delete+insert
    /// simulation is relative to the *current* caret — editing here would
    /// corrupt text at the new position (the "안욥하세욥" bug). `commitCurrent`
    /// is proxy-free and idempotent, so wiring this to `selectionDidChange`
    /// (which also fires for our own programmatic moves) stays safe.
    func handleExternalCursorMove() {
        commitCurrent()
        abbreviationEngine.resetBuffer()
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
        if previewMode { return }
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
           let content = KeyboardMetrics.keyContent(at: row, column: column, mode: .korean, layout: KeyboardSettings.shared.layoutCustomization) {
            switch content {
            case .consonant(let consonant):
                gestureAnalyzer.columnId = KeyboardMetrics.columnIndex(for: consonant)
                gestureAnalyzer.forceCardinalOnly = false
            case .vowelPrimitive:
                // ㅣ/ㅡ 키는 4방향 파생모음만 쓰므로 카디널 스냅으로 인식해
                // 기운 긋기(↖↗↙↘)가 의도한 ←→↑↓ 로 가게 한다.
                gestureAnalyzer.columnId = 0
                gestureAnalyzer.forceCardinalOnly = true
            default:
                gestureAnalyzer.columnId = 0
                gestureAnalyzer.forceCardinalOnly = false
            }
        } else {
            gestureAnalyzer.columnId = 0
            gestureAnalyzer.forceCardinalOnly = false
        }
        gestureAnalyzer.reset()
        gestureAnalyzer.addPoint(point)
        gestureDirections = []
        previewVowel = nil
        // Gesture observation fires whenever the callback is set, independent
        // of `previewMode`. The gesture test screen wires this callback while
        // running in production input mode so the sector canvas can mirror
        // the user's stroke even though the keyboard is also inserting text.
        if onPreviewConsonantGesture != nil {
            previewGesturePoints = [point]
            previewGestureColumnId = gestureAnalyzer.columnId
            onPreviewConsonantGesture?(
                .began(startPoint: point, columnId: previewGestureColumnId),
                [],
                nil
            )
        }
    }

    func gestureMoved(to point: CGPoint) {
        gestureAnalyzer.addPoint(point)
        let directions = gestureAnalyzer.getDirections()
        gestureDirections = directions

        // Update preview vowel based on active key type so preview matches actual output.
        // Vowel primitive keys (ㅣ, ㅡ) use the same resolver as input commit;
        // consonant keys use the 8-direction VowelResolver pattern trie.
        if let key = activeKey,
           let content = KeyboardMetrics.keyContent(at: key.row, column: key.column, mode: keyboardMode, layout: KeyboardSettings.shared.layoutCustomization) {
            switch content {
            case .vowelPrimitive(let primitive):
                previewVowel = resolveVowelFromPrimitiveDrag(primitive: primitive, directions: directions)
            case .consonant:
                // 자음 키도 대각선 진입(↗↖=ㅣ, ↙↘=ㅡ) 후 파생 모음을 실시간으로
                // 미리 보여준다. 실제 입력(handleKoreanModeGesture)과 동일하게
                // resolveConsonantDiagonalVowel 을 먼저 시도하고, 아니면 trie peek.
                previewVowel = resolveConsonantDiagonalVowel(directions)
                    ?? vowelResolver.peekVowel(directions: directions)
            default:
                previewVowel = nil
            }
        } else {
            previewVowel = vowelResolver.peekVowel(directions: directions)
        }
        if onPreviewConsonantGesture != nil {
            previewGesturePoints.append(point)
            onPreviewConsonantGesture?(
                .moved(currentPoint: point,
                       points: previewGesturePoints,
                       columnId: previewGestureColumnId),
                directions,
                previewVowel
            )
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

        // In preview mode, only the slot B vowel key produces output (via its
        // own dedicated gesture pipeline). All consonant / symbol / backspace
        // taps from KeyGridView are dropped so the preview cannot mutate any
        // composer state or insert into a host text field.
        if previewMode {
            // Still consume any gesture-analyzer state so the next press starts clean.
            let directions = gestureAnalyzer.finalizeGesture()
            // Surface the final resolved vowel so the gesture test screen
            // shows what the production keyboard would have committed.
            if onPreviewConsonantGesture != nil {
                let resolved = resolvedPreviewVowel(row: row, column: column, directions: directions)
                onPreviewConsonantGesture?(
                    .ended(points: previewGesturePoints,
                           columnId: previewGestureColumnId),
                    directions,
                    resolved
                )
            }
            previewGesturePoints.removeAll()
            resetGestureState()
            return
        }

        // Production-input + observation path: when the callback is set but
        // previewMode is off (live keyboard inside GestureTestView), peek the
        // analyzer state and emit `.ended` BEFORE handing off to the normal
        // input handlers. We must not finalize/reset the analyzer here — the
        // mode-specific handlers below call `finalizeGesture()` themselves.
        if onPreviewConsonantGesture != nil {
            // finalizeGesture() 로 정리된 directions 를 써서 시각화 "최종 결과"가
            // 실제 입력 경로(handleKoreanModeGesture)와 정확히 일치하게 한다.
            // finalizeGesture 는 상태를 바꾸지 않으므로 아래 핸들러가 다시 호출해도 무방.
            let directions = gestureAnalyzer.finalizeGesture()
            let resolved = resolvedPreviewVowel(row: row, column: column, directions: directions)
            onPreviewConsonantGesture?(
                .ended(points: previewGesturePoints,
                       columnId: previewGestureColumnId),
                directions,
                resolved
            )
            previewGesturePoints.removeAll()
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
        guard let content = KeyboardMetrics.keyContent(at: row, column: column, mode: keyboardMode, layout: KeyboardSettings.shared.layoutCustomization) else { return }

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

        guard let content = KeyboardMetrics.keyContent(at: row, column: column, mode: .korean, layout: KeyboardSettings.shared.layoutCustomization) else { return }

        switch content {
        case .consonant(let consonant):
            if directions.isEmpty {
                // No gesture - treat as tap
                inputConsonant(consonant)
            } else {
                // Gesture completed - input consonant + vowel
                inputConsonant(consonant)

                let vowel = resolveConsonantDiagonalVowel(directions)
                    ?? vowelResolver.resolve(directions: directions).vowel
                if let vowel {
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
    /// 긋기 테스트 캔버스 미리보기용 vowel — 키 타입에 맞게 계산.
    /// vowelPrimitive(ㅣ/ㅡ) 키는 실제 입력과 같은 resolveVowelFromPrimitiveDrag,
    /// 자음 키는 8방향 VowelResolver. 통일 안 하면 캔버스가 ㅡ키 ← 를 ㅛ 가 아닌
    /// ㅓ(자음 매핑)로 잘못 표시한다(실제 입력은 ㅛ 인데 미리보기만 ㅓ).
    private func resolvedPreviewVowel(row: Int, column: Int, directions: [GestureDirection]) -> Jungseong? {
        if let content = KeyboardMetrics.keyContent(at: row, column: column, mode: keyboardMode, layout: KeyboardSettings.shared.layoutCustomization),
           case .vowelPrimitive(let primitive) = content {
            return resolveVowelFromPrimitiveDrag(primitive: primitive, directions: directions)
        }
        return resolveConsonantDiagonalVowel(directions)
            ?? vowelResolver.resolve(directions: directions).vowel
    }

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

    /// 자음 키에서 첫 획이 대각선이면 ㅣ/ㅡ 진입으로 보고, 후속 방향을 전용
    /// ㅣ/ㅡ 키와 동일한 천지인 파생 규칙으로 해석한다(↗↖=ㅣ, ↙↘=ㅡ).
    /// ㅡ 진입 후 ㅣ방향(↗/↖) 후속은 ㅢ. 첫 획이 카디널이거나 후속 없는 단독
    /// 대각선이면 nil → 호출부가 기존 `VowelResolver`(ㅣ/ㅡ 단독)로 폴백한다.
    func resolveConsonantDiagonalVowel(_ directions: [GestureDirection]) -> Jungseong? {
        guard let first = directions.first, first.isDiagonal else { return nil }
        let primitive: VowelPrimitiveType = (first == .upRight || first == .upLeft) ? .bar : .dash
        let rest = Array(directions.dropFirst())
        guard !rest.isEmpty else { return nil }   // 단독 대각선(ㅣ/ㅡ)은 기존 경로에 맡김
        // ㅡ + ㅣ방향(대각선 후속) = ㅢ (전용키 로직엔 없어 여기서 보강)
        if primitive == .dash, rest.contains(where: { $0 == .upLeft || $0 == .upRight }) {
            return .ㅢ
        }
        return resolveVowelFromPrimitiveDrag(primitive: primitive, directions: rest)
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
            // 천지인 멀티스트로크: ㅗ→ㅚ→ㅛ (↑↓↑), ㅜ→ㅟ→ㅠ (↓↑↓)
            case (.ㅚ, .up):    return .ㅛ
            case (.ㅟ, .down):  return .ㅠ
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
            // 천지인 멀티스트로크: ㅓ→ㅔ→ㅕ (←→←), ㅏ→ㅐ→ㅑ (→←→)
            case (.ㅔ, .left):  return .ㅕ
            case (.ㅐ, .right): return .ㅑ
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
    /// Text immediately before the caret, used for context-aware input
    /// automation (double-space → period). Returns nil when the host
    /// context is unavailable.
    func textBeforeCursor() -> String?
}

extension KeyboardViewModelDelegate {
    func textBeforeCursor() -> String? { nil }
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

    func abbreviationEngine(_ engine: AbbreviationEngine, shouldRestore original: String, removing replacement: String, delimiter: Character) {
        // The expansion inserted `replacement + delimiter` on screen. Restore
        // must remove the delimiter too — deleting only `replacement` leaves
        // the delimiter behind and appends the trigger after it ("♥ㅎㅌ" bug).
        let footprint = replacement.count + String(delimiter).count
        for _ in 0..<footprint {
            delegate?.deleteBackward()
        }
        // Re-insert the original trigger
        delegate?.insertText(original)
    }
}

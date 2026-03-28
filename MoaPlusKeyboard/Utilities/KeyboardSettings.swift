import Foundation
import Combine

/// Central settings store shared between keyboard extension and container app via App Group
final class KeyboardSettings: ObservableObject {
    static let shared = KeyboardSettings()

    /// App Group identifier for shared defaults
    static let appGroupId = "group.com.moaki.keyboard"

    /// UserDefaults keys
    private enum Keys {
        static let gestureSettings = "gestureSettings"
        static let themeSettings = "themeSettings"
        static let secondaryKeyActions = "secondaryKeyActions"
        static let shortcutExpansions = "shortcutExpansions"
        static let showGesturePreview = "showGesturePreview"
        static let showSecondaryHints = "showSecondaryHints"
        static let hintSize = "hintSize"
        static let sideKeyWidthRatio = "sideKeyWidthRatio"
        static let longPressDelay = "longPressDelay"
        static let clickSoundEnabled = "clickSoundEnabled"
        static let showDetailedHints = "showDetailedHints"
        static let autoBracketEnabled = "autoBracketEnabled"
        static let wordDeleteEnabled = "wordDeleteEnabled"
        static let backspaceSpeed = "backspaceSpeed"
        static let wordDeleteDelay = "wordDeleteDelay"
    }

    /// Shared UserDefaults (App Group) with fallback to standard
    private let defaults: UserDefaults

    /// Guards against redundant saves while loadAll() is assigning values
    private var isLoading = false

    // MARK: - Gesture Settings

    @Published var gestureSettings: GestureSettings = .default {
        didSet { guard !isLoading else { return }; save(gestureSettings, forKey: Keys.gestureSettings) }
    }

    // MARK: - Theme Settings

    @Published var themeSettings: ThemeSettings = .default {
        didSet { guard !isLoading else { return }; save(themeSettings, forKey: Keys.themeSettings) }
    }

    // MARK: - Secondary Key Actions (Long-press mappings)

    @Published var secondaryKeyActions: [SecondaryKeyAction] = SecondaryKeyAction.defaults {
        didSet { guard !isLoading else { return }; save(secondaryKeyActions, forKey: Keys.secondaryKeyActions) }
    }

    // MARK: - Shortcut Expansions

    @Published var shortcutExpansionStore: ShortcutExpansionStore = ShortcutExpansionStore() {
        didSet { guard !isLoading else { return }; save(shortcutExpansionStore, forKey: Keys.shortcutExpansions) }
    }

    // MARK: - Display Settings

    @Published var showGesturePreview: Bool = false {
        didSet { guard !isLoading else { return }; defaults.set(showGesturePreview, forKey: Keys.showGesturePreview) }
    }

    @Published var showSecondaryHints: Bool = true {
        didSet { guard !isLoading else { return }; defaults.set(showSecondaryHints, forKey: Keys.showSecondaryHints) }
    }

    /// Hint size: 0 = small, 1 = normal, 2 = large
    @Published var hintSize: Int = 1 {
        didSet { guard !isLoading else { return }; defaults.set(hintSize, forKey: Keys.hintSize) }
    }

    /// Auto-close brackets: (), {}, []
    @Published var autoBracketEnabled: Bool = true {
        didSet { guard !isLoading else { return }; defaults.set(autoBracketEnabled, forKey: Keys.autoBracketEnabled) }
    }

    /// Show all popup candidates on key (detailed hint mode)
    @Published var showDetailedHints: Bool = false {
        didSet { guard !isLoading else { return }; defaults.set(showDetailedHints, forKey: Keys.showDetailedHints) }
    }

    /// Click sound - stored independently (not inside ThemeSettings) for reliable decoding
    @Published var clickSoundEnabled: Bool = false {
        didSet { guard !isLoading else { return }; defaults.set(clickSoundEnabled, forKey: Keys.clickSoundEnabled) }
    }

    // MARK: - Layout Settings

    /// Side key width ratio (0.2 ~ 0.5, default 0.35)
    @Published var sideKeyWidthRatio: Double = 0.35 {
        didSet { guard !isLoading else { return }; defaults.set(sideKeyWidthRatio, forKey: Keys.sideKeyWidthRatio) }
    }

    /// Long-press delay in seconds (0.2 ~ 1.0, default 0.5)
    @Published var longPressDelay: Double = 0.5 {
        didSet { guard !isLoading else { return }; defaults.set(longPressDelay, forKey: Keys.longPressDelay) }
    }

    // MARK: - Backspace Settings

    /// Word-level delete on long backspace press
    @Published var wordDeleteEnabled: Bool = true {
        didSet { guard !isLoading else { return }; defaults.set(wordDeleteEnabled, forKey: Keys.wordDeleteEnabled) }
    }

    /// Backspace repeat speed: 0=slow(0.12s), 1=normal(0.08s), 2=fast(0.05s)
    @Published var backspaceSpeed: Int = 1 {
        didSet { guard !isLoading else { return }; defaults.set(backspaceSpeed, forKey: Keys.backspaceSpeed) }
    }

    /// Seconds before switching to word delete (0.8~3.0)
    @Published var wordDeleteDelay: Double = 1.5 {
        didSet { guard !isLoading else { return }; defaults.set(wordDeleteDelay, forKey: Keys.wordDeleteDelay) }
    }

    /// Computed repeat interval from speed setting
    var backspaceRepeatInterval: TimeInterval {
        switch backspaceSpeed {
        case 0:  return 0.12
        case 2:  return 0.05
        default: return 0.08
        }
    }

    // MARK: - Initialization

    private init() {
        // Try App Group defaults, fall back to standard
        if let groupDefaults = UserDefaults(suiteName: KeyboardSettings.appGroupId) {
            self.defaults = groupDefaults
        } else {
            self.defaults = .standard
        }
        loadAll()
    }

    // MARK: - Persistence

    private func loadAll() {
        isLoading = true
        defer { isLoading = false }
        gestureSettings = load(GestureSettings.self, forKey: Keys.gestureSettings) ?? .default
        themeSettings = load(ThemeSettings.self, forKey: Keys.themeSettings) ?? .default
        secondaryKeyActions = load([SecondaryKeyAction].self, forKey: Keys.secondaryKeyActions) ?? SecondaryKeyAction.defaults
        shortcutExpansionStore = load(ShortcutExpansionStore.self, forKey: Keys.shortcutExpansions) ?? ShortcutExpansionStore()
        showGesturePreview = defaults.bool(forKey: Keys.showGesturePreview)
        showSecondaryHints = defaults.object(forKey: Keys.showSecondaryHints) as? Bool ?? true
        hintSize = defaults.object(forKey: Keys.hintSize) as? Int ?? 1
        sideKeyWidthRatio = defaults.object(forKey: Keys.sideKeyWidthRatio) as? Double ?? 0.35
        longPressDelay = defaults.object(forKey: Keys.longPressDelay) as? Double ?? 0.5
        clickSoundEnabled = defaults.object(forKey: Keys.clickSoundEnabled) as? Bool ?? false
        showDetailedHints = defaults.object(forKey: Keys.showDetailedHints) as? Bool ?? false
        autoBracketEnabled = defaults.object(forKey: Keys.autoBracketEnabled) as? Bool ?? true
        wordDeleteEnabled = defaults.object(forKey: Keys.wordDeleteEnabled) as? Bool ?? true
        backspaceSpeed = defaults.object(forKey: Keys.backspaceSpeed) as? Int ?? 1
        wordDeleteDelay = defaults.object(forKey: Keys.wordDeleteDelay) as? Double ?? 1.5
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Convenience

    /// Reset all settings to defaults
    func resetAll() {
        gestureSettings = .default
        themeSettings = .default
        secondaryKeyActions = SecondaryKeyAction.defaults
        shortcutExpansionStore = ShortcutExpansionStore()
        showGesturePreview = false
        showSecondaryHints = true
        hintSize = 1
    }

    /// Reset gesture settings only
    func resetGestureSettings() {
        gestureSettings = .default
    }

    /// Get secondary action for a specific key
    func secondaryAction(forKey keyId: String) -> SecondaryKeyAction? {
        return SecondaryKeyAction.action(forKey: keyId, from: secondaryKeyActions)
    }
}

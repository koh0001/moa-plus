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

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
        static let cursorMoveBySpaceDragEnabled = "cursorMoveBySpaceDragEnabled"
        static let abbreviationEnabled = "abbreviationEnabled"
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

    /// Master switch for abbreviation expansion. When `false`, registered
    /// shortcut expansions remain on disk but are not triggered, so the
    /// user can opt out without losing their data.
    @Published var abbreviationEnabled: Bool = true {
        didSet { guard !isLoading else { return }; writePrimitive(abbreviationEnabled, forKey: Keys.abbreviationEnabled) }
    }

    // MARK: - Display Settings

    @Published var showGesturePreview: Bool = false {
        didSet { guard !isLoading else { return }; writePrimitive(showGesturePreview, forKey: Keys.showGesturePreview) }
    }

    @Published var showSecondaryHints: Bool = true {
        didSet { guard !isLoading else { return }; writePrimitive(showSecondaryHints, forKey: Keys.showSecondaryHints) }
    }

    /// Hint size: 0 = small, 1 = normal, 2 = large
    @Published var hintSize: Int = 1 {
        didSet { guard !isLoading else { return }; writePrimitive(hintSize, forKey: Keys.hintSize) }
    }

    /// Auto-close brackets: (), {}, []
    @Published var autoBracketEnabled: Bool = true {
        didSet { guard !isLoading else { return }; writePrimitive(autoBracketEnabled, forKey: Keys.autoBracketEnabled) }
    }

    /// Show all popup candidates on key (detailed hint mode)
    @Published var showDetailedHints: Bool = false {
        didSet { guard !isLoading else { return }; writePrimitive(showDetailedHints, forKey: Keys.showDetailedHints) }
    }

    /// Click sound - stored independently (not inside ThemeSettings) for reliable decoding
    @Published var clickSoundEnabled: Bool = false {
        didSet { guard !isLoading else { return }; writePrimitive(clickSoundEnabled, forKey: Keys.clickSoundEnabled) }
    }

    // MARK: - Layout Settings

    /// Side key width ratio (0.2 ~ 1.0, default 0.7 for square keys)
    @Published var sideKeyWidthRatio: Double = 0.7 {
        didSet { guard !isLoading else { return }; writePrimitive(sideKeyWidthRatio, forKey: Keys.sideKeyWidthRatio) }
    }

    /// Long-press delay in seconds (0.2 ~ 1.0, default 0.5)
    @Published var longPressDelay: Double = 0.5 {
        didSet { guard !isLoading else { return }; writePrimitive(longPressDelay, forKey: Keys.longPressDelay) }
    }

    // MARK: - Backspace Settings

    /// Word-level delete on long backspace press
    @Published var wordDeleteEnabled: Bool = true {
        didSet { guard !isLoading else { return }; writePrimitive(wordDeleteEnabled, forKey: Keys.wordDeleteEnabled) }
    }

    /// Backspace repeat speed: 0=slow(0.12s), 1=normal(0.08s), 2=fast(0.05s)
    @Published var backspaceSpeed: Int = 1 {
        didSet { guard !isLoading else { return }; writePrimitive(backspaceSpeed, forKey: Keys.backspaceSpeed) }
    }

    /// Seconds before switching to word delete (0.8~3.0)
    @Published var wordDeleteDelay: Double = 1.5 {
        didSet { guard !isLoading else { return }; writePrimitive(wordDeleteDelay, forKey: Keys.wordDeleteDelay) }
    }

    /// Space-bar drag moves the cursor (default ON)
    @Published var cursorMoveBySpaceDragEnabled: Bool = true {
        didSet { guard !isLoading else { return }; writePrimitive(cursorMoveBySpaceDragEnabled, forKey: Keys.cursorMoveBySpaceDragEnabled) }
    }

    /// Computed repeat interval from speed setting
    var backspaceRepeatInterval: TimeInterval {
        switch backspaceSpeed {
        case 0:  return 0.12
        case 2:  return 0.05
        default: return 0.08
        }
    }

    // MARK: - App Group health

    /// `true` when the shared App Group UserDefaults loaded successfully.
    /// `false` means provisioning is broken and the host app & keyboard
    /// extension are reading/writing **separate** containers — every
    /// setting change in the host app is invisible to the keyboard.
    /// The host app surfaces this to the user via
    /// `KeyboardSettings.warnIfAppGroupBroken(presenting:)`.
    private(set) var isUsingAppGroup: Bool = true

    // MARK: - Cross-process change notification (darwin)

    /// Darwin notification name posted whenever any persisted setting
    /// changes. Both host app and keyboard extension subscribe to it so
    /// edits in one process are picked up immediately by the other —
    /// without waiting for the keyboard's `viewWillAppear` to fire.
    private static let changeNotificationName =
        "kr.koh0001.moa-plus.KeyboardSettings.changed" as CFString

    private var lastReloadAt: TimeInterval = 0
    private var lastSelfPostAt: TimeInterval = 0
    private var observerToken: UnsafeMutableRawPointer?

    // MARK: - Initialization

    private init() {
        // Prefer the shared App Group container. If it can't be created,
        // we use `.standard` so the keyboard at least has settings to
        // read — but the host app and extension will diverge until the
        // user surfaces the issue and reinstalls.
        if let groupDefaults = UserDefaults(suiteName: KeyboardSettings.appGroupId) {
            self.defaults = groupDefaults
            self.isUsingAppGroup = true
        } else {
            self.defaults = .standard
            self.isUsingAppGroup = false
            NSLog("⚠️ MoaPlus KeyboardSettings: App Group '%@' unavailable — settings will not sync between host app and keyboard. Reinstall required.", KeyboardSettings.appGroupId)
        }
        loadAll()
        registerCrossProcessObserver()
    }

    deinit {
        if let observerToken {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observerToken,
                CFNotificationName(KeyboardSettings.changeNotificationName),
                nil
            )
        }
    }

    private func registerCrossProcessObserver() {
        let token = Unmanaged.passUnretained(self).toOpaque()
        observerToken = token
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            token,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let settings = Unmanaged<KeyboardSettings>.fromOpaque(observer).takeUnretainedValue()
                settings.handleCrossProcessChange()
            },
            KeyboardSettings.changeNotificationName,
            nil,
            .deliverImmediately
        )
    }

    private func handleCrossProcessChange() {
        let now = Date().timeIntervalSinceReferenceDate
        // Darwin notifications are delivered to *all* observers including
        // the poster. Drop the echo of our own recent post — we already
        // hold the latest values, so reloading just rebuilds SwiftUI for
        // nothing and is what caused the in-process memory leak.
        guard now - lastSelfPostAt > 0.05 else { return }
        // Coalesce bursts from the other process (settings screens often
        // fire several saves within a frame). Re-loading more than ~10x
        // per second is wasted work and floods @Published subscribers.
        guard now - lastReloadAt >= 0.1 else { return }
        lastReloadAt = now
        DispatchQueue.main.async { [weak self] in
            self?.loadAll()
        }
    }

    /// Broadcast a change notification so the *other* process re-reads
    /// settings. Called from every `didSet` writer (via the central
    /// `save`/`writePrimitive` paths).
    private func postCrossProcessChange() {
        guard !isLoading else { return }
        lastSelfPostAt = Date().timeIntervalSinceReferenceDate
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(KeyboardSettings.changeNotificationName),
            nil,
            nil,
            true
        )
    }

    // MARK: - Persistence

    func loadAll() {
        isLoading = true
        defer { isLoading = false }
        gestureSettings = load(GestureSettings.self, forKey: Keys.gestureSettings) ?? .default
        themeSettings = load(ThemeSettings.self, forKey: Keys.themeSettings) ?? .default
        secondaryKeyActions = load([SecondaryKeyAction].self, forKey: Keys.secondaryKeyActions) ?? SecondaryKeyAction.defaults
        shortcutExpansionStore = load(ShortcutExpansionStore.self, forKey: Keys.shortcutExpansions) ?? ShortcutExpansionStore()
        abbreviationEnabled = defaults.object(forKey: Keys.abbreviationEnabled) as? Bool ?? true
        showGesturePreview = defaults.bool(forKey: Keys.showGesturePreview)
        showSecondaryHints = defaults.object(forKey: Keys.showSecondaryHints) as? Bool ?? true
        hintSize = defaults.object(forKey: Keys.hintSize) as? Int ?? 1
        sideKeyWidthRatio = defaults.object(forKey: Keys.sideKeyWidthRatio) as? Double ?? 0.7
        longPressDelay = defaults.object(forKey: Keys.longPressDelay) as? Double ?? 0.5
        clickSoundEnabled = defaults.object(forKey: Keys.clickSoundEnabled) as? Bool ?? false
        showDetailedHints = defaults.object(forKey: Keys.showDetailedHints) as? Bool ?? false
        autoBracketEnabled = defaults.object(forKey: Keys.autoBracketEnabled) as? Bool ?? true
        wordDeleteEnabled = defaults.object(forKey: Keys.wordDeleteEnabled) as? Bool ?? true
        backspaceSpeed = defaults.object(forKey: Keys.backspaceSpeed) as? Int ?? 1
        wordDeleteDelay = defaults.object(forKey: Keys.wordDeleteDelay) as? Double ?? 1.5
        cursorMoveBySpaceDragEnabled = defaults.object(forKey: Keys.cursorMoveBySpaceDragEnabled) as? Bool ?? true
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
        postCrossProcessChange()
    }

    /// Write a primitive UserDefaults value and broadcast the change so
    /// the other process re-reads. All `didSet` paths funnel through here
    /// (or `save()` for Codable values) so we never miss a notification —
    /// previously we relied on a UserDefaults.didChangeNotification observer,
    /// which created an echo loop with darwin notifications and caused
    /// SwiftUI view churn that leaked memory in the keyboard extension.
    private func writePrimitive(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        postCrossProcessChange()
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Convenience

    /// Reset all settings to defaults. Keeps every `@Published` field in
    /// sync with the per-property defaults declared above; if a new field
    /// is added, it must be reset here as well.
    func resetAll() {
        gestureSettings = .default
        themeSettings = .default
        secondaryKeyActions = SecondaryKeyAction.defaults
        shortcutExpansionStore = ShortcutExpansionStore()
        abbreviationEnabled = true
        showGesturePreview = false
        showSecondaryHints = true
        hintSize = 1
        autoBracketEnabled = true
        showDetailedHints = false
        clickSoundEnabled = false
        sideKeyWidthRatio = 0.7
        longPressDelay = 0.5
        wordDeleteEnabled = true
        backspaceSpeed = 1
        wordDeleteDelay = 1.5
        cursorMoveBySpaceDragEnabled = true
    }

    /// Reset gesture settings only
    func resetGestureSettings() {
        gestureSettings = .default
    }

    // MARK: - App Group sanity check (host app)

    /// Returns a localized message describing the App Group setup error,
    /// or `nil` when everything is healthy. Call from the host app at
    /// launch and surface the message via `UIAlertController` if non-nil.
    static func appGroupSetupErrorMessage() -> String? {
        guard !KeyboardSettings.shared.isUsingAppGroup else { return nil }
        return """
        설정이 저장되지 않을 수 있습니다.

        키보드 확장과 앱이 설정을 공유하는 App Group(\(appGroupId))을 \
        시스템에서 사용할 수 없습니다. 키보드 보정·약어·테마 등이 키보드에 \
        반영되지 않습니다. 앱을 재설치하거나 새 빌드를 다시 설치해 주세요.
        """
    }

    /// Get secondary action for a specific key
    func secondaryAction(forKey keyId: String) -> SecondaryKeyAction? {
        return SecondaryKeyAction.action(forKey: keyId, from: secondaryKeyActions)
    }
}

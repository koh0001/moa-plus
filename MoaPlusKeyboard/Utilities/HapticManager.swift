import UIKit

/// Centralized haptic feedback manager
final class HapticManager {
    static let shared = HapticManager()

    private var settings: ThemeSettings {
        KeyboardSettings.shared.themeSettings
    }

    private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private lazy var selectionFeedback = UISelectionFeedbackGenerator()
    private lazy var notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for lower latency
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
    }

    // MARK: - Event-based Haptics

    /// Key tap feedback
    func playTap() {
        guard settings.hapticEnabled && settings.hapticOnTap else { return }
        impact()
    }

    /// Long-press popup entry feedback
    func playLongPress() {
        guard settings.hapticEnabled && settings.hapticOnLongPress else { return }
        mediumImpact.impactOccurred()
    }

    /// Layer switch feedback (Korean ↔ Symbol, Special char layer)
    func playLayerSwitch() {
        guard settings.hapticEnabled && settings.hapticOnLayerSwitch else { return }
        selectionFeedback.selectionChanged()
    }

    /// Abbreviation expansion confirmed feedback
    func playAbbreviationConfirm() {
        guard settings.hapticEnabled && settings.hapticOnAbbreviationConfirm else { return }
        notificationFeedback.notificationOccurred(.success)
    }

    // MARK: - Private

    private func impact() {
        switch settings.hapticStrength {
        case .light:
            lightImpact.impactOccurred()
        case .normal:
            mediumImpact.impactOccurred()
        }
    }
}

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

    /// 설정 화면 "이벤트별 햅틱" 의 이벤트.
    enum Event: CaseIterable {
        case tap
        case longPress
        case layerSwitch
        case abbreviationConfirm
    }

    /// 이 이벤트가 지금 설정으로 울려야 하나. 전체 스위치(`hapticEnabled`) + 이벤트별 토글.
    /// 이벤트끼리는 서로 묶이지 않는다 — 레이어 전환 키는 탭 햅틱 **대신** 레이어 전환 햅틱을
    /// 내므로(이슈 #41) "탭" 을 꺼도 레이어 전환은 울리고, "레이어 전환" 을 끄면 그 키는 조용하다.
    /// 가드: `HapticEventToggleTests`.
    static func isEnabled(_ event: Event, in settings: ThemeSettings) -> Bool {
        guard settings.hapticEnabled else { return false }
        switch event {
        case .tap:                 return settings.hapticOnTap
        case .longPress:           return settings.hapticOnLongPress
        case .layerSwitch:         return settings.hapticOnLayerSwitch
        case .abbreviationConfirm: return settings.hapticOnAbbreviationConfirm
        }
    }

    // MARK: - Event-based Haptics

    /// Key tap feedback
    func playTap() {
        guard Self.isEnabled(.tap, in: settings) else { return }
        impact()
    }

    /// 롱키 팝업이 실제로 열린 순간 (`KeyboardViewModel.inputLongPressNumber` → 델리게이트).
    func playLongPress() {
        guard Self.isEnabled(.longPress, in: settings) else { return }
        mediumImpact.impactOccurred()
    }

    /// 레이어 전환 키(한/영 · 123/한글 · #+=/123)를 누른 순간 — 탭 햅틱 대신.
    func playLayerSwitch() {
        guard Self.isEnabled(.layerSwitch, in: settings) else { return }
        selectionFeedback.selectionChanged()
    }

    /// Abbreviation expansion confirmed feedback
    func playAbbreviationConfirm() {
        guard Self.isEnabled(.abbreviationConfirm, in: settings) else { return }
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

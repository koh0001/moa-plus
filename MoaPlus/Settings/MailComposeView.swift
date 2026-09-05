import SwiftUI
import MessageUI
import UIKit

/// In-app mail composer. Pre-fills subject + body with device/app info so
/// bug reports arrive with the diagnostic context already filled in. Falls
/// back gracefully when no Mail account is configured — callers check
/// `MFMailComposeViewController.canSendMail()` before presenting.
struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    var onFinish: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (() -> Void)?
        init(onFinish: (() -> Void)?) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true) { [onFinish] in onFinish?() }
        }
    }
}

enum FeedbackContext {
    /// Build a prefilled bug-report body containing app version, iOS version,
    /// device model, and Full Access status — the fields most often missing
    /// from raw user reports.
    static func defaultBody() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let iosVersion = UIDevice.current.systemVersion
        let model = deviceModelIdentifier()
        // 전체 접근이 꺼진 키보드는 App Group 에 기록을 못 남기므로 "기록 없음" 도 단서다.
        let fullAccess: String = {
            switch KeyboardSettings.shared.fullAccessStatus {
            case .granted: return "ON"
            case .denied:  return "OFF"
            case .unknown: return "기록 없음(미사용 또는 꺼짐)"
            }
        }()
        return """


        ─────────────────
        앱: 모아+ v\(version) (\(build))
        iOS: \(iosVersion)
        기기: \(model)
        전체 접근: \(fullAccess)
        ─────────────────
        """
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

import Foundation
import CoreGraphics

/// 실측용 제스처 상세 로그 — 입력 기록 보드의 "개발자에게 보내기" 리포트에
/// 동봉된다. 텍스트 결과만으로는 "왜 ㅘ 가 ㅛ 로 갔는지"(획별 크기·트림 전후)
/// 를 알 수 없다는 실기기 피드백에서 나온 채널.
///
/// `KeyboardSettings.gestureDebugLogEnabled` 가 켜졌을 때만 기록되는 옵트인이다
/// — 입력한 자모가 그대로 남으므로 기본 OFF 를 유지할 것. App Group 에 저장해
/// 익스텐션이 쓰고 메인 앱(입력 기록 보드)이 읽는다.
enum GestureDebugLog {
    private static let storageKey = "gestureDebugLogLines"
    private static let maxLines = 200

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: KeyboardSettings.appGroupId)
    }

    /// 한 제스처의 계측을 한 줄로 기록한다.
    /// 형식: `HH:mm:ss [키] raw ↑102(91°) ↓98(268°) → fin ↑102 ↓98 ⇒ 와 (키폭 50)`
    static func append(keyLabel: String,
                       raw: [GestureAnalyzer.StrokeInfo],
                       finalized: [GestureAnalyzer.StrokeInfo],
                       keyWidth: CGFloat,
                       result: String) {
        guard let defaults else { return }

        func describe(_ strokes: [GestureAnalyzer.StrokeInfo]) -> String {
            strokes.isEmpty
                ? "(없음)"
                : strokes.map { String(format: "%@%.0f(%.0f°)", $0.direction.symbol, $0.magnitude, $0.angleDegrees) }
                    .joined(separator: " ")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "\(formatter.string(from: Date())) [\(keyLabel)] raw \(describe(raw)) → fin \(describe(finalized)) ⇒ \(result) (키폭 \(Int(keyWidth)))"

        var lines = defaults.stringArray(forKey: storageKey) ?? []
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        defaults.set(lines, forKey: storageKey)
    }

    static func recentLines(_ count: Int = 80) -> [String] {
        guard let lines = defaults?.stringArray(forKey: storageKey) else { return [] }
        return Array(lines.suffix(count))
    }

    static var count: Int {
        defaults?.stringArray(forKey: storageKey)?.count ?? 0
    }

    static func clear() {
        defaults?.removeObject(forKey: storageKey)
    }
}

import Foundation
import CoreGraphics

/// 실측용 제스처 상세 로그 — 입력 기록 보드의 "개발자에게 보내기" 리포트에
/// 동봉된다. 텍스트 결과만으로는 "왜 ㅘ 가 ㅛ 로 갔는지"(획별 크기·트림 전후)
/// 를 알 수 없다는 실기기 피드백에서 나온 채널.
///
/// `KeyboardSettings.gestureDebugLogEnabled` (기본 ON) 일 때 기록된다.
/// 기록은 기기 로컬(App Group 순환 버퍼)에만 남고, 기기 밖으로 나가는 경로는
/// 입력 기록 보드의 "개발자에게 보내기"를 사용자가 직접 누르는 것뿐이다.
/// App Group 에 저장해 익스텐션이 쓰고 메인 앱(입력 기록 보드)이 읽는다.
enum GestureDebugLog {
    private static let storageKey = "gestureDebugLogLines"
    private static let maxLines = 200

    /// 상시 기록이므로 입력 경로에서 매 제스처마다 UserDefaults 배열을 다시
    /// 읽지 않도록 프로세스 수명 동안 캐시한다 (쓰기는 그대로 통과).
    private static var cachedLines: [String]?

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

        var lines = cachedLines ?? defaults.stringArray(forKey: storageKey) ?? []
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        cachedLines = lines
        defaults.set(lines, forKey: storageKey)
    }

    /// 메인 앱에서 읽을 때는 익스텐션 프로세스가 그 사이 더 쓴 내용을 봐야
    /// 하므로 캐시가 아니라 디스크를 읽는다 (읽기는 입력 경로가 아니라 느긋해도 됨).
    static func recentLines(_ count: Int = 80) -> [String] {
        guard let lines = defaults?.stringArray(forKey: storageKey) else { return [] }
        return Array(lines.suffix(count))
    }

    static var count: Int {
        defaults?.stringArray(forKey: storageKey)?.count ?? 0
    }

    static func clear() {
        cachedLines = nil
        defaults?.removeObject(forKey: storageKey)
    }
}

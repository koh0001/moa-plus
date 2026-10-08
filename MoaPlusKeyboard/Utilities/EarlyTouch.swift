import SwiftUI
import UIKit

// MARK: - 하단 절반 키 반응 지연 우회 (iOS 27 메일 제보)
//
// 실측(iPhone 16 Pro / iOS 27.0.1, 2026-09-30):
// - 터치 **도착**(UITouch.timestamp → UIKit touchesBegan)은 어느 위치든 ~20ms.
// - SwiftUI `DragGesture` 의 첫 `onChanged` 까지의 **인식**은 키보드 위쪽 절반 ~81ms,
//   아래쪽 절반(y ≳ 130/260pt)은 **751ms 고정**. 거리 비례가 아니라 경계 계단형 +
//   고정값 = 시스템 제스처 판정의 타임아웃을 SwiftUI 인식기가 기다리는 것.
// 탭·긋기는 손을 떼거나 움직이는 순간 판정이 풀려 멀쩡하고, **가만히 누르는** 동작
// (롱프레스 팝업, 백스페이스 꾹, 누르는 순간의 햅틱)만 0.75초 밀린다.
//
// 그래서 "누름 시작" 만 UIKit 층에서 받는다. 호스팅 뷰의 `EarlyTouchRecognizer` 가
// ~20ms 에 터치를 받아, 각 키가 등록해 둔 창 좌표 프레임으로 키를 찾아 `onPress` 를
// 부른다. 키 뷰는 SwiftUI 첫 `onChanged` 가 하던 일을 여기서 먼저 하고, SwiftUI 경로는
// 이미 눌린 상태(`isHighlighted`/`isPressed`)를 보고 시작 처리를 건너뛴다 — 시작이 두 번
// 되면 백스페이스가 두 번 지워지거나 진동이 두 번 울린다.
//
// ⚠️ 이 인식기는 입력을 가로채지 않는다: 터치를 취소·지연하지 않고, 누구도 막지 않으며,
// 스스로 인식(.began)하지 않는다. 판정은 여전히 SwiftUI `DragGesture` 가 한다.
// 가드: `EarlyTouchTests`.

/// 키 하나의 조기 터치 수신처. 키 뷰가 `@State` 로 소유하고 매 렌더마다 콜백을 갱신한다.
final class EarlyTouchTarget: NSObject {
    /// 창 좌표계(`.global`) 프레임 — 인식기가 터치 위치로 키를 찾는 기준.
    var windowFrame: CGRect = .null
    /// `keyboardPreview` 좌표계 프레임 — 키 뷰의 SwiftUI 좌표로 바꿀 때 쓴다.
    var previewFrame: CGRect = .null

    var onPress: ((CGPoint) -> Void)?
    var onMove: ((CGSize) -> Void)?
    /// 손을 뗐는데 SwiftUI 가 끝내 이 터치를 처리하지 않았는지 묻는다.
    var isStillPressed: (() -> Bool)?
    var onUnhandledRelease: (() -> Void)?

    /// 누를 때마다 증가. 뗀 뒤 지연 판정이 **다음** 누름을 건드리지 않게 한다
    /// (같은 키 빠른 연타).
    private(set) var generation = 0

    /// SwiftUI 가 뗌을 처리할 여유. 탭은 뗌과 같은 이벤트 처리에서 끝나므로 넉넉하다.
    static let unhandledReleaseDelay: TimeInterval = 0.3

    func press(atWindowPoint point: CGPoint) {
        generation += 1
        onPress?(previewPoint(fromWindowPoint: point))
    }

    func move(translation: CGSize) {
        onMove?(translation)
    }

    func release(scheduler: (TimeInterval, @escaping () -> Void) -> Void = EarlyTouchTarget.mainAfter) {
        let pressGeneration = generation
        scheduler(Self.unhandledReleaseDelay) { [weak self] in
            guard let self, self.generation == pressGeneration,
                  self.isStillPressed?() == true else { return }
            self.onUnhandledRelease?()
        }
    }

    func previewPoint(fromWindowPoint point: CGPoint) -> CGPoint {
        guard !windowFrame.isNull, !previewFrame.isNull else { return point }
        return CGPoint(x: point.x - windowFrame.minX + previewFrame.minX,
                       y: point.y - windowFrame.minY + previewFrame.minY)
    }

    static func mainAfter(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

/// 화면에 떠 있는 키들의 조기 터치 수신처 목록. 키 뷰의 등장/퇴장으로 관리한다.
enum EarlyTouchRegistry {
    private static let targets = NSHashTable<EarlyTouchTarget>.weakObjects()

    static func add(_ target: EarlyTouchTarget) { targets.add(target) }
    static func remove(_ target: EarlyTouchTarget) { targets.remove(target) }

    /// 창 좌표 `point` 를 담는 키. 겹치면(팝업 등) 가장 작은 프레임이 이긴다.
    static func target(atWindowPoint point: CGPoint) -> EarlyTouchTarget? {
        lookup(atWindowPoint: point).target
    }

    /// 키 찾기 결과 + 놓친 이유를 가를 단서 (`EarlyTouchDiagnostics`).
    struct Lookup {
        let target: EarlyTouchTarget?
        /// `point` 를 담은 키 수. 화면의 키 프레임은 서로 겹치지 않으므로 2 이상이면 화면에서
        /// 사라진 키가 남아 있을 수 있다 — 어느 쪽이 조기 시작을 받을지 정해져 있지 않다.
        let containing: Int
        let registered: Int
        /// 못 찾았을 때 가장 가까운 키 프레임에서 터치까지의 어긋남(pt). 배치된 키가 없으면 nil.
        let nearestOffset: CGVector?
    }

    static func lookup(atWindowPoint point: CGPoint) -> Lookup {
        let all = targets.allObjects
        let laidOut = all.filter { !$0.windowFrame.isNull }
        let containing = laidOut.filter { $0.windowFrame.contains(point) }
        let best = containing.min { $0.windowFrame.width * $0.windowFrame.height
                                  < $1.windowFrame.width * $1.windowFrame.height }
        let nearest: CGVector? = best != nil ? .zero
            : laidOut.map { offset(from: $0.windowFrame, to: point) }
                .min { $0.dx * $0.dx + $0.dy * $0.dy < $1.dx * $1.dx + $1.dy * $1.dy }
        return Lookup(target: best, containing: containing.count, registered: all.count, nearestOffset: nearest)
    }

    private static func offset(from r: CGRect, to p: CGPoint) -> CGVector {
        CGVector(dx: p.x - min(max(p.x, r.minX), r.maxX), dy: p.y - min(max(p.y, r.minY), r.maxY))
    }
}

// MARK: - 진단 (개발자 리포트, 이슈 #35)

/// 조기 시작이 실제로 먼저 누름을 시작했는지 — 개발자 리포트의 "조기 터치" 줄.
///
/// 조기 경로가 키를 찾으면 누름 시작은 SwiftUI(위쪽 ~80ms, 아래쪽 ~750ms)보다 항상 먼저다.
/// 그러니 **SwiftUI 가 먼저 시작한 그리드 누름 = 조기 경로가 놓친 누름**이다. 그 누름을 인식기가
/// 본 최근 터치와 짝지어(같은 y) 놓친 이유를 가른다:
/// - 터치 못 받음: 짝이 없다 — 인식기가 그 터치를 받지 못했다(인식기 상태·창 게이트)
/// - 키 못 찾음: 받았지만 키가 없었다 — 등록 누락(등록 0개) 또는 좌표 어긋남(먼 곳 어긋남 값)
/// - 다른 키: 다른 키에 조기 시작을 줬다 — 낡은 키 잔존 또는 좌표 어긋남(키 하나 이하)
/// - 같은 키: 맞는 키를 찾았는데도 SwiftUI 가 먼저 — 조기 시작이 먹히지 않았다
/// 증상 자체는 아래쪽 롱키 팝업이 **터치부터** 몇 ms 에 떴는지로 잰다(정상 = 롱프레스 딜레이).
/// 메모리 집계를 2초에 한 번(지연 사건은 즉시) App Group 에 쓴다. 아래쪽 SwiftUI 먼저가 있었던
/// 기록은 따로 남겨, 다음 깨끗한 실행이 덮어쓰지 못하게 한다.
enum EarlyTouchDiagnostics {
    struct Late: Equatable {
        var at: Date
        /// 터치부터 SwiftUI 시작까지. 짝 터치가 없으면 nil.
        var ms: Double?
        var y: CGFloat
        var height: CGFloat
    }

    struct FarMiss: Equatable {
        var y: CGFloat
        var height: CGFloat
        var offset: CGVector?
        var registered: Int
    }

    struct Counts: Equatable {
        var lowerTouches = 0
        var found = 0
        /// 키 사이 틈(가장 가까운 키가 `gapDistance` 이내) — 정상.
        var gap = 0
        /// 가장 가까운 키도 멀거나 배치된 키가 없음 — 등록 누락·좌표 어긋남 의심.
        var farMiss = 0
        var overlapped = 0
        var maxArrivalMs = 0.0
        var swiftUIFirst = 0
        var swiftUIFirstLower = 0
        var lowerNotSeen = 0
        var lowerMissed = 0
        var lowerOtherKey = 0
        var lowerSameKey = 0
        var lastLower: Late?
        var popupMaxMs = 0.0
        var popupLastMs: Double?
        var alreadyPressed = 0
        var lastFarMiss: FarMiss?
    }

    /// 아래쪽 판정 비율(키보드 높이 대비). 2행(ㅁ~ㅎ)이 높이의 ~41% 에서 시작한다.
    static let lowerRatio: CGFloat = 0.4
    static let gapDistance: CGFloat = 6
    /// SwiftUI 시작점과 같은 터치로 볼 y 차이. 같은 터치면 거의 같다.
    static let matchTolerance: CGFloat = 12
    static let writeInterval: TimeInterval = 2

    /// 익스텐션(`KeyboardViewController`)만 켠다 — 메인 앱의 키보드 미리보기가 같은 App Group
    /// 값을 앱 쪽 집계로 덮어쓰지 않게.
    private(set) static var isRecording = false
    /// SwiftUI 좌표의 아래쪽 판정 기준 높이. 컨트롤러가 레이아웃마다 갱신한다.
    static var keyboardHeight: CGFloat = 0

    static var now: () -> Date = Date.init
    /// `UITouch.timestamp` 와 같은 시계(시스템 업타임, 초).
    static var uptime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    static var write: (String) -> Void = defaultWrite
    static var writeDelayed: (String) -> Void = defaultWriteDelayed
    /// 지연 사건 기록을 누름 처리 뒤로 미룬다 — 늦게 온 누름을 더 늦추지 않게.
    static var schedule: (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }

    static let defaultWrite: (String) -> Void = { KeyboardSettings.shared.recordEarlyTouchDiagnostic($0) }
    static let defaultWriteDelayed: (String) -> Void = {
        KeyboardSettings.shared.recordEarlyTouchDelayedDiagnostic($0)
    }

    private(set) static var counts = Counts()
    private(set) static var since = Date()
    private static var lastWrite: Date?

    private struct TouchRecord {
        let uptime: TimeInterval
        /// 호스팅 뷰 좌표 — `keyboardPreview` 와 y 원점이 같다.
        let y: CGFloat
        let foundPreviewFrame: CGRect?
    }
    private static var recent: [TouchRecord] = []
    private static let recentLimit = 8

    /// 익스텐션이 키보드 뷰를 만들 때 부른다. 집계 시작 시각은 프로세스당 한 번 잡는다.
    static func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        since = now()
    }

    /// 인식기의 touchesBegan. 짝짓기용으로 모든 터치를 기억하고, 집계는 아래쪽 터치만 —
    /// 위쪽은 조기 경로가 없어도 지연이 없다.
    static func touchBegan(at location: CGPoint, height: CGFloat, timestamp: TimeInterval,
                           lookup: EarlyTouchRegistry.Lookup) {
        guard isRecording, height > 0 else { return }
        recent.append(TouchRecord(uptime: timestamp, y: location.y,
                                  foundPreviewFrame: lookup.target?.previewFrame))
        if recent.count > recentLimit { recent.removeFirst(recent.count - recentLimit) }

        guard location.y / height >= lowerRatio else { return }
        counts.lowerTouches += 1
        counts.maxArrivalMs = max(counts.maxArrivalMs, (uptime() - timestamp) * 1000)
        if lookup.target != nil {
            counts.found += 1
            if lookup.containing > 1 { counts.overlapped += 1 }
        } else if let o = lookup.nearestOffset, (o.dx * o.dx + o.dy * o.dy).squareRoot() <= gapDistance {
            counts.gap += 1
        } else {
            counts.farMiss += 1
            counts.lastFarMiss = FarMiss(y: location.y, height: height,
                                         offset: lookup.nearestOffset, registered: lookup.registered)
        }
    }

    /// 그리드 키의 SwiftUI 첫 `onChanged` 가 누름을 시작했다 = 조기 경로가 놓쳤다.
    /// - Parameter point: 누른 지점(`keyboardPreview` 좌표).
    static func swiftUIStartedFirst(at point: CGPoint) {
        guard isRecording else { return }
        counts.swiftUIFirst += 1
        guard keyboardHeight > 0, point.y / keyboardHeight >= lowerRatio else { return }
        counts.swiftUIFirstLower += 1
        let match = matchingTouch(y: point.y, within: 1.5)
        if let match {
            if let frame = match.foundPreviewFrame {
                if frame.contains(point) { counts.lowerSameKey += 1 } else { counts.lowerOtherKey += 1 }
            } else {
                counts.lowerMissed += 1
            }
        } else {
            counts.lowerNotSeen += 1
        }
        counts.lastLower = Late(at: now(), ms: match.map { (uptime() - $0.uptime) * 1000 },
                                y: point.y, height: keyboardHeight)
        schedule { flush(force: true) }
    }

    /// 아래쪽 키의 롱키 팝업이 떴다 — 터치부터 걸린 시간이 증상 그 자체다.
    /// - Parameter previewY: 누름 시작점 y(`keyboardPreview` 좌표).
    static func longPressPopupShown(previewY: CGFloat) {
        guard isRecording, keyboardHeight > 0, previewY / keyboardHeight >= lowerRatio,
              let match = matchingTouch(y: previewY, within: 3) else { return }
        let ms = (uptime() - match.uptime) * 1000
        counts.popupMaxMs = max(counts.popupMaxMs, ms)
        counts.popupLastMs = ms
        schedule { flush(force: true) }
    }

    /// 조기 시작이 왔는데 키가 이미 눌린 상태였다. 같은 키를 앞 누름의 SwiftUI 뗌 처리 전에 다시
    /// 누른 경우(ㅎㅎ 연타)에도 생긴다 — 눌림 고착만 뜻하지는 않는다.
    static func earlyPressWhileAlreadyPressed() {
        guard isRecording else { return }
        counts.alreadyPressed += 1
        schedule { flush(force: true) }
    }

    static func flush(force: Bool = false) {
        guard isRecording, counts != Counts() else { return }
        let t = now()
        if !force, let last = lastWrite, t.timeIntervalSince(last) < writeInterval { return }
        lastWrite = t
        let text = line()
        write(text)
        if counts.swiftUIFirstLower > 0 { writeDelayed(text) }
    }

    static func line() -> String {
        let c = counts
        func ms(_ v: Double) -> String { String(format: "%.0fms", v) }
        var parts = [
            "\(formatter.string(from: since)) 부터",
            "아래쪽 터치 \(c.lowerTouches) (도착 최대 \(ms(c.maxArrivalMs)), 키 찾음 \(c.found), 틈 \(c.gap), "
                + "먼 곳 \(c.farMiss), 겹침 \(c.overlapped))",
            "SwiftUI 먼저 \(c.swiftUIFirst) (아래쪽 \(c.swiftUIFirstLower): 터치 못 받음 \(c.lowerNotSeen), "
                + "키 못 찾음 \(c.lowerMissed), 다른 키 \(c.lowerOtherKey), 같은 키 \(c.lowerSameKey))",
            "아래쪽 롱키 팝업 최대 \(ms(c.popupMaxMs)) 마지막 \(c.popupLastMs.map(ms) ?? "-")",
            "이미 눌림 \(c.alreadyPressed)",
        ]
        if let l = c.lastLower {
            parts.append(String(format: "마지막 SwiftUI 먼저 %@ 터치부터 %@ y %.0f/%.0fpt",
                                formatter.string(from: l.at), l.ms.map(ms) ?? "?", l.y, l.height))
        }
        if let m = c.lastFarMiss {
            let offset = m.offset.map { String(format: "(%.0f, %.0f)pt", $0.dx, $0.dy) } ?? "배치된 키 없음"
            parts.append(String(format: "마지막 먼 곳 y %.0f/%.0fpt 어긋남 %@ 등록 %d개",
                                m.y, m.height, offset, m.registered))
        }
        return parts.joined(separator: " · ")
    }

    private static func matchingTouch(y: CGFloat, within seconds: TimeInterval) -> TouchRecord? {
        let t = uptime()
        return recent.last { t - $0.uptime <= seconds && abs($0.y - y) <= matchTolerance }
    }

    /// 테스트용 — 집계와 바꿔 끼운 훅을 모두 되돌린다.
    static func resetForTesting(recording: Bool) {
        isRecording = recording
        now = Date.init
        uptime = { ProcessInfo.processInfo.systemUptime }
        write = defaultWrite
        writeDelayed = defaultWriteDelayed
        schedule = { DispatchQueue.main.async(execute: $0) }
        keyboardHeight = 0
        counts = Counts()
        since = now()
        lastWrite = nil
        recent = []
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm:ss"
        return f
    }()
}

/// 호스팅 뷰에 붙이는 조기 터치 인식기. 인식(.began)하지 않고 터치만 관찰한다.
final class EarlyTouchRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var tracked: [ObjectIdentifier: (target: EarlyTouchTarget, start: CGPoint)] = [:]

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            TouchLatencyProbe.touchBegan(touch, in: view)
            let point = touch.location(in: nil)
            let lookup = EarlyTouchRegistry.lookup(atWindowPoint: point)
            if let view {
                EarlyTouchDiagnostics.touchBegan(at: touch.location(in: view), height: view.bounds.height,
                                                 timestamp: touch.timestamp, lookup: lookup)
            }
            guard let target = lookup.target else { continue }
            tracked[ObjectIdentifier(touch)] = (target, point)
            target.press(atWindowPoint: point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            guard let entry = tracked[ObjectIdentifier(touch)] else { continue }
            let p = touch.location(in: nil)
            entry.target.move(translation: CGSize(width: p.x - entry.start.x, height: p.y - entry.start.y))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            tracked.removeValue(forKey: ObjectIdentifier(touch))?.target.release()
        }
        if tracked.isEmpty {
            state = .failed
            EarlyTouchDiagnostics.flush()
        }
    }

    override func reset() {
        super.reset()
        // `.failed` 로 끝난 뒤 불린다. 남은 추적(이론상 없음)도 정리해 새 터치와 섞이지 않게 한다.
        for entry in tracked.values { entry.target.release() }
        tracked.removeAll()
    }
}

// MARK: - SwiftUI 연결

private struct EarlyPressModifier: ViewModifier {
    let onPress: (CGPoint) -> Void
    let onMove: (CGSize) -> Void
    let isStillPressed: () -> Bool
    let onUnhandledRelease: () -> Void
    @State private var target = EarlyTouchTarget()

    func body(content: Content) -> some View {
        // 콜백은 매 렌더 최신 값으로 — 키 내용이 바뀌어도(한/영·페이지 전환) 이전 키의
        // 클로저가 남지 않게 한다. 클래스 필드 대입이라 뷰 갱신을 일으키지 않는다.
        let _ = target.onPress = onPress
        let _ = target.onMove = onMove
        let _ = target.isStillPressed = isStillPressed
        let _ = target.onUnhandledRelease = onUnhandledRelease
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { target.windowFrame = $0 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("keyboardPreview")) } action: { target.previewFrame = $0 }
            .onAppear { EarlyTouchRegistry.add(target) }
            .onDisappear { EarlyTouchRegistry.remove(target) }
    }
}

extension View {
    /// SwiftUI 제스처보다 먼저(~20ms) "누름 시작" 을 받는다. 자세한 이유는 `EarlyTouch.swift` 머리말.
    /// - Parameters:
    ///   - onPress: 누른 지점(`keyboardPreview` 좌표). SwiftUI 첫 `onChanged` 의 시작 처리를 여기서 한다.
    ///   - onMove: 누른 지점부터의 이동량(창 좌표).
    ///   - isStillPressed: 뗀 뒤 0.3초에 아직 눌린 상태인지 = SwiftUI 가 처리하지 않았는지.
    ///   - onUnhandledRelease: 그 경우의 뒷정리(입력 확정 없이).
    func earlyPress(onPress: @escaping (CGPoint) -> Void,
                    onMove: @escaping (CGSize) -> Void = { _ in },
                    isStillPressed: @escaping () -> Bool,
                    onUnhandledRelease: @escaping () -> Void) -> some View {
        modifier(EarlyPressModifier(onPress: onPress, onMove: onMove,
                                    isStillPressed: isStillPressed,
                                    onUnhandledRelease: onUnhandledRelease))
    }
}

// MARK: - 계측 (개발자 리포트)

/// 누름 시작부터의 경과를 `GestureDebugLog` 에 남긴다. 실기기 판정용:
/// 하단 행도 "조기 시작"·"롱프레스 팝업"·"백스페이스" 가 위쪽 행과 같은 시각이어야 한다.
enum TouchLatencyProbe {
    /// 기본 꺼짐 — 켜면 누를 때마다 App Group 에 2~3줄을 쓴다. 지연 재조사 때만 true 로
    /// 빌드해 실기기에 올리고 개발자 리포트를 받는다(2026-09-30 판정에 쓴 계측).
    static var isEnabled = false

    /// `UITouch.timestamp` 와 같은 시계(시스템 업타임, 초).
    private static var touchTimestamp: TimeInterval?
    private static var arrivalMs: Double = 0
    private static var y: CGFloat = 0
    private static var height: CGFloat = 0
    private static var recognitionLogged = true

    static func touchBegan(_ touch: UITouch, in view: UIView?) {
        guard isEnabled else { return }
        touchTimestamp = touch.timestamp
        arrivalMs = (ProcessInfo.processInfo.systemUptime - touch.timestamp) * 1000
        y = touch.location(in: view).y
        height = view?.bounds.height ?? 0
        recognitionLogged = false
    }

    private static func elapsedMs() -> Double? {
        guard let t = touchTimestamp else { return nil }
        return (ProcessInfo.processInfo.systemUptime - t) * 1000
    }

    /// SwiftUI 첫 `onChanged` 에서 부른다. 터치당 한 번만 기록한다.
    static func recordRecognition(label: String) {
        guard !recognitionLogged, let total = elapsedMs() else { return }
        recognitionLogged = true
        GestureDebugLog.appendLine(String(
            format: "[터치지연] %@ y=%.0f/%.0f 도착 %.0fms SwiftUI %.0fms",
            label, y, height, arrivalMs, total))
    }

    /// 조기 시작·롱프레스 팝업·백스페이스 시작 등 사건 시각.
    static func event(_ name: String) {
        guard let total = elapsedMs() else { return }
        GestureDebugLog.appendLine(String(format: "[터치지연] %@ y=%.0f %.0fms", name, y, total))
    }
}

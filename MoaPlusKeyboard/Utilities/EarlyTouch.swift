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
        targets.allObjects
            .filter { !$0.windowFrame.isNull && $0.windowFrame.contains(point) }
            .min { $0.windowFrame.width * $0.windowFrame.height
                 < $1.windowFrame.width * $1.windowFrame.height }
    }
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
            guard let target = EarlyTouchRegistry.target(atWindowPoint: point) else { continue }
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
        if tracked.isEmpty { state = .failed }
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

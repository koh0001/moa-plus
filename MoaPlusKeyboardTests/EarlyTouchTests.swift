import XCTest
import CoreGraphics
@testable import MoaPlusKeyboard

/// 하단 절반 키 반응 지연 우회(`EarlyTouch.swift`)의 계약.
///
/// 실제 지연(SwiftUI 인식 751ms)은 시뮬레이터가 서드파티 키보드를 못 띄워 실기기에서만
/// 재현된다. 여기서는 키 뷰가 기대는 수신처의 규칙 — 뗀 뒤 정리는 "SwiftUI 가 처리하지
/// 않은 이번 누름" 에만, 한 번만 — 을 가드한다.
final class EarlyTouchTests: XCTestCase {

    /// 지연 실행을 모아 두었다가 테스트가 원할 때 돌린다.
    private final class ManualScheduler {
        var pending: [() -> Void] = []
        func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) { pending.append(work) }
        func runAll() { let w = pending; pending = []; w.forEach { $0() } }
    }

    private func makeTarget(pressed: @escaping () -> Bool,
                            onRelease: @escaping () -> Void) -> EarlyTouchTarget {
        let t = EarlyTouchTarget()
        t.windowFrame = CGRect(x: 100, y: 500, width: 40, height: 50)
        t.previewFrame = CGRect(x: 100, y: 120, width: 40, height: 50)
        t.isStillPressed = pressed
        t.onUnhandledRelease = onRelease
        return t
    }

    func test_press_convertsWindowPointToPreviewSpace() {
        var got: CGPoint?
        let t = makeTarget(pressed: { false }, onRelease: {})
        t.onPress = { got = $0 }
        t.press(atWindowPoint: CGPoint(x: 110, y: 530))
        XCTAssertEqual(got, CGPoint(x: 110, y: 150))
    }

    /// 보통의 탭: SwiftUI `onEnded` 가 눌림을 내렸으므로 정리하지 않는다.
    func test_release_handledBySwiftUI_doesNothing() {
        var pressed = true, cleaned = 0
        let t = makeTarget(pressed: { pressed }, onRelease: { cleaned += 1 })
        let sched = ManualScheduler()
        t.press(atWindowPoint: CGPoint(x: 110, y: 530))
        t.release(scheduler: sched.schedule)
        pressed = false            // SwiftUI onEnded
        sched.runAll()
        XCTAssertEqual(cleaned, 0)
    }

    /// 시스템이 터치를 가져가 SwiftUI 가 끝내 안 온 경우: 한 번 정리한다.
    func test_release_unhandled_cleansUpOnce() {
        var pressed = true, cleaned = 0
        let t = makeTarget(pressed: { pressed }, onRelease: { cleaned += 1; pressed = false })
        let sched = ManualScheduler()
        t.press(atWindowPoint: CGPoint(x: 110, y: 530))
        t.release(scheduler: sched.schedule)
        sched.runAll()
        XCTAssertEqual(cleaned, 1)
    }

    /// 같은 키 빠른 연타: 첫 누름의 지연 정리가 두 번째 누름(진행 중)을 걷으면 안 된다.
    func test_release_staleGeneration_doesNotCancelNextPress() {
        var pressed = true, cleaned = 0
        let t = makeTarget(pressed: { pressed }, onRelease: { cleaned += 1 })
        let sched = ManualScheduler()
        t.press(atWindowPoint: CGPoint(x: 110, y: 530))
        t.release(scheduler: sched.schedule)
        pressed = false                 // 첫 탭은 SwiftUI 가 처리
        t.press(atWindowPoint: CGPoint(x: 110, y: 530))
        pressed = true                  // 두 번째 누름 진행 중
        sched.runAll()
        XCTAssertEqual(cleaned, 0)
    }

    func test_registry_picksSmallestContainingFrame_andForgetsRemoved() {
        let key = EarlyTouchTarget()
        key.windowFrame = CGRect(x: 0, y: 0, width: 40, height: 50)
        let big = EarlyTouchTarget()
        big.windowFrame = CGRect(x: 0, y: 0, width: 400, height: 300)
        EarlyTouchRegistry.add(key)
        EarlyTouchRegistry.add(big)
        defer { EarlyTouchRegistry.remove(key); EarlyTouchRegistry.remove(big) }

        XCTAssertTrue(EarlyTouchRegistry.target(atWindowPoint: CGPoint(x: 10, y: 10)) === key)
        XCTAssertTrue(EarlyTouchRegistry.target(atWindowPoint: CGPoint(x: 200, y: 200)) === big)
        EarlyTouchRegistry.remove(key)
        XCTAssertTrue(EarlyTouchRegistry.target(atWindowPoint: CGPoint(x: 10, y: 10)) === big)
    }

    func test_registry_ignoresUnlaidOutTargets() {
        let t = EarlyTouchTarget()   // windowFrame == .null
        EarlyTouchRegistry.add(t)
        defer { EarlyTouchRegistry.remove(t) }
        XCTAssertNil(EarlyTouchRegistry.target(atWindowPoint: .zero))
    }
}

import XCTest
@testable import MoaPlusKeyboard

/// Covers the space-bar hold-to-repeat cursor mover. Synchronous checks for
/// start/stop/redirect state; one async check that it actually ticks.
final class SpaceCursorRepeaterTests: XCTestCase {

    /// Speed setting maps to a monotonic interval ramp: faster level ⇒ smaller
    /// start and floor intervals. Restores the setting to avoid App Group leak.
    func testCursorRepeatInterval_fasterSpeedYieldsShorterIntervals() {
        let settings = KeyboardSettings.shared
        let original = settings.cursorRepeatSpeed
        defer { settings.cursorRepeatSpeed = original }

        settings.cursorRepeatSpeed = 0
        let slow = settings.cursorRepeatInterval
        settings.cursorRepeatSpeed = 1
        let normal = settings.cursorRepeatInterval
        settings.cursorRepeatSpeed = 2
        let fast = settings.cursorRepeatInterval

        XCTAssertGreaterThan(slow.initial, normal.initial)
        XCTAssertGreaterThan(normal.initial, fast.initial)
        XCTAssertGreaterThan(slow.min, normal.min)
        XCTAssertGreaterThan(normal.min, fast.min)
        // Ramp is well-formed: start ≥ floor for every level.
        for ramp in [slow, normal, fast] {
            XCTAssertGreaterThanOrEqual(ramp.initial, ramp.min)
        }
    }

    func testStartZeroDirection_isNoOp() {
        let repeater = SpaceCursorRepeater()
        repeater.start(direction: 0)
        XCTAssertFalse(repeater.isRunning, "direction 0 must not start the timer")
    }

    func testStartAndStop_togglesRunning() {
        let repeater = SpaceCursorRepeater()
        repeater.start(direction: 1)
        XCTAssertTrue(repeater.isRunning, "start(direction:) must arm the timer")
        repeater.stop()
        XCTAssertFalse(repeater.isRunning, "stop() must disarm the timer")
    }

    func testFires_inHeldDirection_thenSilentAfterStop() {
        let repeater = SpaceCursorRepeater()
        var steps: [Int] = []
        repeater.onStep = { steps.append($0) }

        repeater.start(direction: -1)

        let ticked = expectation(description: "repeater ticked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            repeater.stop()
            ticked.fulfill()
        }
        wait(for: [ticked], timeout: 3.0)

        XCTAssertFalse(steps.isEmpty, "repeater should fire while held")
        XCTAssertTrue(steps.allSatisfy { $0 == -1 }, "all ticks in the held (-1) direction")

        // No further ticks after stop().
        let countAtStop = steps.count
        let settled = expectation(description: "no ticks after stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settled.fulfill() }
        wait(for: [settled], timeout: 3.0)
        XCTAssertEqual(steps.count, countAtStop, "no ticks may fire after stop()")
    }

    func testRedirect_changesDirection() {
        let repeater = SpaceCursorRepeater()
        var steps: [Int] = []
        repeater.onStep = { steps.append($0) }

        repeater.start(direction: 1)
        repeater.start(direction: -1)   // redirect before any assertion on ticks

        let done = expectation(description: "ticked after redirect")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            repeater.stop()
            done.fulfill()
        }
        wait(for: [done], timeout: 3.0)

        XCTAssertTrue(steps.contains(-1), "must tick in the redirected direction")
        XCTAssertFalse(steps.contains(1), "must not tick in the abandoned direction")
    }
}

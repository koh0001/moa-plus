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

    // MARK: - 진단 (이슈 #35: 아래쪽 롱키가 가끔 1초 늦음)
    //
    // 레지스트리는 프로세스 전역이라 테스트 호스트 앱의 키가 섞일 수 있다 — 먼 좌표를 쓴다.

    func test_lookup_countsOverlap_andMatchesTargetLookup() {
        let a = EarlyTouchTarget(), b = EarlyTouchTarget()
        a.windowFrame = CGRect(x: 10_000, y: 10_000, width: 40, height: 50)
        b.windowFrame = a.windowFrame
        EarlyTouchRegistry.add(a)
        EarlyTouchRegistry.add(b)
        defer { EarlyTouchRegistry.remove(a); EarlyTouchRegistry.remove(b) }

        let point = CGPoint(x: 10_010, y: 10_010)
        let hit = EarlyTouchRegistry.lookup(atWindowPoint: point)
        XCTAssertNotNil(hit.target)
        XCTAssertEqual(hit.containing, 2, "같은 자리에 키 둘 = 낡은 키 잔존 신호")
        XCTAssertTrue(EarlyTouchRegistry.target(atWindowPoint: point) === hit.target,
                      "조기 시작이 고르는 키와 진단이 보는 키가 같다")
    }

    func test_lookup_miss_reportsNearestOffset() {
        let key = EarlyTouchTarget()
        key.windowFrame = CGRect(x: 10_000, y: 10_000, width: 40, height: 50)
        EarlyTouchRegistry.add(key)
        defer { EarlyTouchRegistry.remove(key) }

        let miss = EarlyTouchRegistry.lookup(atWindowPoint: CGPoint(x: 10_020, y: 10_080))
        XCTAssertNil(miss.target)
        XCTAssertGreaterThanOrEqual(miss.registered, 1)
        XCTAssertEqual(miss.nearestOffset?.dx ?? -1, 0, accuracy: 0.01)
        XCTAssertEqual(miss.nearestOffset?.dy ?? -1, 30, accuracy: 0.01, "키 아래 가장자리에서 30pt")
    }

    private var written: [String] = []
    private var writtenDelayed: [String] = []
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var upNow: TimeInterval = 1_000

    private func startRecording() {
        EarlyTouchDiagnostics.resetForTesting(recording: false)
        written = []
        writtenDelayed = []
        EarlyTouchDiagnostics.now = { [unowned self] in self.clock }
        EarlyTouchDiagnostics.uptime = { [unowned self] in self.upNow }
        EarlyTouchDiagnostics.write = { [unowned self] in self.written.append($0) }
        EarlyTouchDiagnostics.writeDelayed = { [unowned self] in self.writtenDelayed.append($0) }
        EarlyTouchDiagnostics.schedule = { $0() }
        EarlyTouchDiagnostics.keyboardHeight = 236
        EarlyTouchDiagnostics.startRecording()
    }

    override func tearDown() {
        EarlyTouchDiagnostics.resetForTesting(recording: false)
        super.tearDown()
    }

    private func lookup(found frame: CGRect? = nil, containing: Int = 1,
                        nearest: CGVector? = nil) -> EarlyTouchRegistry.Lookup {
        if let frame {
            let t = EarlyTouchTarget()
            t.previewFrame = frame
            keepAlive.append(t)
            return .init(target: t, containing: containing, registered: 40, nearestOffset: .zero)
        }
        return .init(target: nil, containing: 0, registered: 40, nearestOffset: nearest)
    }
    private var keepAlive: [EarlyTouchTarget] = []

    /// 아래쪽 터치(y 120/236 = 51%). 도착은 터치 20ms 뒤.
    private func lowerTouch(y: CGFloat = 120, _ lookup: EarlyTouchRegistry.Lookup) {
        EarlyTouchDiagnostics.touchBegan(at: CGPoint(x: 100, y: y), height: 236,
                                         timestamp: upNow - 0.02, lookup: lookup)
    }

    func test_touchBegan_countsLowerOnly_andSeparatesGapFromFarMiss() {
        startRecording()
        EarlyTouchDiagnostics.touchBegan(at: CGPoint(x: 100, y: 40), height: 236,
                                         timestamp: upNow, lookup: lookup())   // 위쪽 — 안 셈
        lowerTouch(lookup(found: CGRect(x: 80, y: 100, width: 50, height: 40), containing: 2))
        lowerTouch(lookup(nearest: CGVector(dx: 0, dy: 3)))     // 키 사이 틈
        lowerTouch(lookup(nearest: CGVector(dx: 0, dy: -24)))   // 먼 곳

        let c = EarlyTouchDiagnostics.counts
        XCTAssertEqual(c.lowerTouches, 3)
        XCTAssertEqual(c.found, 1)
        XCTAssertEqual(c.overlapped, 1)
        XCTAssertEqual(c.gap, 1)
        XCTAssertEqual(c.farMiss, 1)
        XCTAssertEqual(c.maxArrivalMs, 20, accuracy: 0.5)
        let line = EarlyTouchDiagnostics.line()
        XCTAssertTrue(line.contains("아래쪽 터치 3 (도착 최대 20ms, 키 찾음 1, 틈 1, 먼 곳 1, 겹침 1)"), line)
        XCTAssertTrue(line.contains("마지막 먼 곳 y 120/236pt 어긋남 (0, -24)pt 등록 40개"), line)
    }

    /// SwiftUI 가 먼저 시작한 아래쪽 누름을 인식기가 본 터치와 짝지어 놓친 이유를 가른다.
    func test_swiftUIFirst_classifiesWhyEarlyPathMissed() {
        startRecording()
        let key = CGRect(x: 80, y: 100, width: 50, height: 40)

        // 1. 인식기가 받은 터치가 없다
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 120))
        // 2. 받았지만 키를 못 찾았다
        lowerTouch(y: 125, lookup(nearest: CGVector(dx: 0, dy: 30)))
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 125))
        // 3. 다른 키에 조기 시작을 줬다 (찾은 키 프레임이 누른 곳을 담지 않음)
        lowerTouch(y: 150, lookup(found: key))
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 150))
        // 4. 맞는 키를 찾았는데도 SwiftUI 가 먼저
        upNow += 0.75
        lowerTouch(y: 110, lookup(found: key))
        upNow += 0.75
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 110))

        let c = EarlyTouchDiagnostics.counts
        XCTAssertEqual(c.swiftUIFirstLower, 4)
        XCTAssertEqual(c.lowerNotSeen, 1)
        XCTAssertEqual(c.lowerMissed, 1)
        XCTAssertEqual(c.lowerOtherKey, 1)
        XCTAssertEqual(c.lowerSameKey, 1)
        XCTAssertEqual(c.lastLower?.ms ?? -1, 770, accuracy: 0.5, "터치(도착 20ms 전)부터 SwiftUI 시작까지")
        XCTAssertTrue(EarlyTouchDiagnostics.line().contains(
            "SwiftUI 먼저 4 (아래쪽 4: 터치 못 받음 1, 키 못 찾음 1, 다른 키 1, 같은 키 1)"))
    }

    func test_swiftUIFirst_upperPress_isCountedButNotClassified() {
        startRecording()
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 60))   // 25%
        XCTAssertEqual(EarlyTouchDiagnostics.counts.swiftUIFirst, 1)
        XCTAssertEqual(EarlyTouchDiagnostics.counts.swiftUIFirstLower, 0)
    }

    /// 증상 그 자체 — 아래쪽 롱키 팝업이 터치부터 몇 ms 에 떴나.
    func test_longPressPopup_measuresFromTouch() {
        startRecording()
        lowerTouch(lookup(found: CGRect(x: 80, y: 100, width: 50, height: 40)))
        upNow += 1.23
        EarlyTouchDiagnostics.longPressPopupShown(previewY: 120)
        upNow += 1
        lowerTouch(lookup(found: CGRect(x: 80, y: 100, width: 50, height: 40)))
        upNow += 0.48
        EarlyTouchDiagnostics.longPressPopupShown(previewY: 120)

        let c = EarlyTouchDiagnostics.counts
        XCTAssertEqual(c.popupMaxMs, 1250, accuracy: 0.5)
        XCTAssertEqual(c.popupLastMs ?? -1, 500, accuracy: 0.5)
        XCTAssertTrue(EarlyTouchDiagnostics.line().contains("아래쪽 롱키 팝업 최대 1250ms 마지막 500ms"))
    }

    func test_flush_throttles_skipsEmpty_andKeepsDelayedRecordSeparately() {
        startRecording()
        EarlyTouchDiagnostics.flush(force: true)
        XCTAssertTrue(written.isEmpty, "아무것도 안 셌으면 이전 기록을 0 으로 덮지 않는다")

        lowerTouch(lookup(found: CGRect(x: 80, y: 100, width: 50, height: 40)))
        EarlyTouchDiagnostics.flush()
        EarlyTouchDiagnostics.flush()
        XCTAssertEqual(written.count, 1, "2초 안의 두 번째 기록은 건너뛴다")
        XCTAssertTrue(writtenDelayed.isEmpty, "지연이 없었으면 지연 기록은 그대로 둔다")

        clock = clock.addingTimeInterval(0.5)
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 120))   // 지연 사건은 즉시
        XCTAssertEqual(written.count, 2)
        XCTAssertEqual(writtenDelayed.count, 1)
    }

    func test_alreadyPressed_isCountedAndWritten() {
        startRecording()
        EarlyTouchDiagnostics.earlyPressWhileAlreadyPressed()
        XCTAssertEqual(EarlyTouchDiagnostics.counts.alreadyPressed, 1)
        XCTAssertEqual(written.count, 1)
    }

    func test_startRecording_stampsSinceOnce() {
        startRecording()
        let first = EarlyTouchDiagnostics.since
        XCTAssertEqual(first, clock)
        clock = clock.addingTimeInterval(60)
        EarlyTouchDiagnostics.startRecording()   // 다음 컨트롤러 — 같은 프로세스
        XCTAssertEqual(EarlyTouchDiagnostics.since, first)
    }

    /// 메인 앱의 키보드 미리보기는 기록하지 않는다 — 익스텐션 값을 덮어쓰면 안 된다.
    func test_diagnostics_doesNothingWhenNotRecording() {
        startRecording()
        EarlyTouchDiagnostics.resetForTesting(recording: false)
        EarlyTouchDiagnostics.write = { [unowned self] in self.written.append($0) }
        EarlyTouchDiagnostics.schedule = { $0() }
        EarlyTouchDiagnostics.keyboardHeight = 236
        lowerTouch(lookup())
        EarlyTouchDiagnostics.swiftUIStartedFirst(at: CGPoint(x: 100, y: 200))
        EarlyTouchDiagnostics.longPressPopupShown(previewY: 200)
        EarlyTouchDiagnostics.earlyPressWhileAlreadyPressed()
        EarlyTouchDiagnostics.flush(force: true)
        XCTAssertEqual(EarlyTouchDiagnostics.counts, .init())
        XCTAssertTrue(written.isEmpty)
    }
}

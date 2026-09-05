import XCTest
@testable import MoaPlusKeyboard

/// 전체 접근 허용 상태 기록 — 앱스토어 리뷰 "햅틱 설정했는데 안 된다" 대응.
///
/// iOS 는 키보드 익스텐션의 `UIImpactFeedbackGenerator` 를 전체 접근이 꺼져 있으면
/// 조용히 무시한다. 익스텐션만 `hasFullAccess` 를 읽을 수 있으므로 뜰 때마다
/// App Group 에 남기고, 메인 앱이 그 값으로 "지금 꺼져 있음" 을 보여준다.
/// 설정이 아니라 기록이라 `@Published` / `loadAll()` 사이클 밖에 둔다
/// (키보드 실측·자동 대문자 진단과 같은 패턴).
final class KeyboardSettingsFullAccessTests: XCTestCase {

    private static let suite = "group.com.moaki.keyboard"
    private static let key = "fullAccessDiagnostic"

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: Self.suite)?.removeObject(forKey: Self.key)
    }

    override func tearDown() {
        UserDefaults(suiteName: Self.suite)?.removeObject(forKey: Self.key)
        super.tearDown()
    }

    func test_neverRecorded_isUnknown() {
        XCTAssertEqual(KeyboardSettings.shared.fullAccessStatus, .unknown,
                       "키보드를 한 번도 띄우지 않았으면 판정 불가 — 경고를 띄우면 안 된다")
    }

    func test_recordGranted() {
        KeyboardSettings.shared.recordFullAccess(true)
        XCTAssertEqual(KeyboardSettings.shared.fullAccessStatus, .granted)
    }

    func test_recordDenied() {
        KeyboardSettings.shared.recordFullAccess(false)
        XCTAssertEqual(KeyboardSettings.shared.fullAccessStatus, .denied)
    }

    func test_latestRecordWins() {
        KeyboardSettings.shared.recordFullAccess(false)
        KeyboardSettings.shared.recordFullAccess(true)
        XCTAssertEqual(KeyboardSettings.shared.fullAccessStatus, .granted,
                       "사용자가 iOS 설정에서 켜고 다시 키보드를 띄우면 경고가 사라져야 한다")
    }
}

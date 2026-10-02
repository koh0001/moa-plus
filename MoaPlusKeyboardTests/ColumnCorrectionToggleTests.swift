import XCTest
import CoreGraphics
@testable import MoaPlusKeyboard

/// 세로 라인별 보정 전체 스위치 (앱스토어 리뷰 2026-09-16 "회전 보정을 끄는 방법은 없을까요?").
///
/// 기존에는 열별 `isEnabled = false` 가 "기본 보정으로 복귀" 라 보정을 끌 수단이 없었다.
/// `GestureAnalyzer` 는 열 보정을 전부 `GestureSettings` 의 조회 함수로만 읽으므로
/// 여기서 중립값이 나오면 판정 전체가 가운데 열과 같아진다.
final class ColumnCorrectionToggleTests: XCTestCase {

    private let keyWidth: CGFloat = 60

    func testDefault_isOn_andEdgeColumnsAreCorrected() {
        let gs = GestureSettings()
        XCTAssertTrue(gs.columnCorrectionEnabled, "기본값을 바꾸면 업데이트만으로 기존 사용자 판정이 달라진다")
        XCTAssertEqual(gs.effectiveRotationOffset(forColumn: 1), 3.0)
        XCTAssertEqual(gs.effectiveRotationOffset(forColumn: 5), -3.0)
    }

    func testOff_everyColumnMatchesCenterColumn() {
        var gs = GestureSettings()
        gs.columnCorrectionEnabled = false
        let center = GestureSettings()  // 3열은 원래 보정 없음
        for col in 1...5 {
            XCTAssertEqual(gs.effectiveRotationOffset(forColumn: col), 0, "\(col)열 회전")
            XCTAssertEqual(gs.verticalIWidthDelta(forColumn: col), 0, "\(col)열 ㅣ 확장")
            XCTAssertEqual(gs.horizontalEuWidthDelta(forColumn: col), 0, "\(col)열 ㅡ 확장")
            XCTAssertEqual(gs.effectiveSwipeThreshold(forColumn: col, keyWidth: keyWidth),
                           center.effectiveSwipeThreshold(forColumn: 3, keyWidth: keyWidth), "\(col)열 거리")
            XCTAssertEqual(gs.effectiveDirectionChangeThreshold(forColumn: col),
                           center.effectiveDirectionChangeThreshold(forColumn: 3), "\(col)열 방향 전환")
        }
    }

    /// 꺼도 사용자가 조정해 둔 열별 값은 지우지 않는다 — 다시 켜면 그대로 돌아와야 한다.
    func testOff_keepsUserTunedValuesForReenable() {
        var gs = GestureSettings()
        gs.columnOverrides[0].rotationOffsetDeg = 7
        gs.columnCorrectionEnabled = false
        XCTAssertEqual(gs.effectiveRotationOffset(forColumn: 1), 0)
        gs.columnCorrectionEnabled = true
        XCTAssertEqual(gs.effectiveRotationOffset(forColumn: 1), 7)
    }

    func testCodable_roundTripsAndOldJSONDefaultsToOn() throws {
        var gs = GestureSettings()
        gs.columnCorrectionEnabled = false
        let data = try JSONEncoder().encode(gs)
        XCTAssertFalse(try JSONDecoder().decode(GestureSettings.self, from: data).columnCorrectionEnabled,
                       "끈 설정이 저장·로드 후 다시 켜진다")

        // 이 필드가 생기기 전에 저장된 설정 — 키가 없으면 켜짐(현재 동작)으로 읽혀야 한다.
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        dict.removeValue(forKey: "columnCorrectionEnabled")
        let old = try JSONSerialization.data(withJSONObject: dict)
        XCTAssertTrue(try JSONDecoder().decode(GestureSettings.self, from: old).columnCorrectionEnabled)
    }
}

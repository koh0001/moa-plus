import XCTest
@testable import MoaPlusKeyboard

/// 한손 모드 (앱스토어 리뷰 2026-09-24). 레이아웃 자체는 `KeyboardView` 가 좁힌 폭으로
/// 본체를 그대로 그리는 방식이라, 여기서는 적용 조건·폭 계산·가장 좁은 기능행을 고정한다.
/// 렌더 확인은 `KeyboardSnapshotTests.test_snapshot_oneHanded*`.
final class OneHandedLayoutTests: XCTestCase {

    func testDefault_isFullWidth() {
        XCTAssertEqual(KeyboardPlacement.allCases.first, .full)
        XCTAssertNil(KeyboardPlacement.full.effectiveSide(isPad: false, isLandscape: false),
                     "기본값이 한손이면 업데이트만으로 모든 사용자 키보드가 좁아진다")
    }

    func testAppliesOnlyToPhonePortrait() {
        XCTAssertEqual(KeyboardPlacement.left.effectiveSide(isPad: false, isLandscape: false), .left)
        XCTAssertEqual(KeyboardPlacement.right.effectiveSide(isPad: false, isLandscape: false), .right)
        XCTAssertNil(KeyboardPlacement.left.effectiveSide(isPad: true, isLandscape: false), "아이패드")
        XCTAssertNil(KeyboardPlacement.right.effectiveSide(isPad: false, isLandscape: true), "가로")
    }

    func testWidth_clampsStoredRatio() {
        XCTAssertEqual(KeyboardPlacement.keyboardWidth(totalWidth: 400, ratio: 0.8), 320)
        XCTAssertEqual(KeyboardPlacement.keyboardWidth(totalWidth: 400, ratio: 0.1), 280, "하한 0.70")
        XCTAssertEqual(KeyboardPlacement.keyboardWidth(totalWidth: 400, ratio: 2.0), 360, "상한 0.90")
    }

    /// 가장 좁은 조합(375pt × 0.70, 지구본 표시)에서도 기능행이 폭에 딱 맞고
    /// 스페이스바가 한/영 키보다 넓게 남아야 한다. 하한 비율을 내릴 때 이 테스트로 확인할 것.
    func testNarrowestFunctionRow_fitsWithUsableSpaceBar() {
        let width = KeyboardPlacement.keyboardWidth(
            totalWidth: 375, ratio: KeyboardPlacement.widthRatioRange.lowerBound)
        for mode in [KeyboardMode.korean, .english, .symbolFromKorean] {
            let row = FunctionRowView(
                totalWidth: width, mode: mode,
                onToggleSymbolPressed: {}, onToggleLetterPressed: {},
                onSpacePressed: {}, onPunctuation: { _ in }, onReturnPressed: {},
                showGlobeKey: true, layoutCustomization: LayoutCustomization())
            XCTAssertEqual(row.occupiedWidth, row.availableWidth, accuracy: 0.5, "\(mode): ⏎ 잘림")
            XCTAssertGreaterThan(row.spaceWidth, row.letterToggleWidth, "\(mode): 스페이스바가 너무 좁다")
        }
    }
}

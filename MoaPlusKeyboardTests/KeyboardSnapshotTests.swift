import XCTest
import SwiftUI
@testable import MoaPlusKeyboard

/// iPad 분리 레이아웃 시각 검증용 스냅샷 (사용자 iPad 부재).
/// host-less 테스트 번들이라 UIDevice가 idiom을 못 잡으므로 `KeyboardView.layoutOverride`로
/// 분리/단일을 강제 렌더한다. PNG는 XCTAttachment 로 .xcresult 에 저장(호스트에서 추출).
final class KeyboardSnapshotTests: XCTestCase {

    @MainActor
    private func snapshot(width: CGFloat, height: CGFloat,
                         override: (isPad: Bool, isLandscape: Bool),
                         name: String, showGlobe: Bool = false) throws {
        let vm = KeyboardViewModel()
        vm.canSwitchInputMode = showGlobe
        let view = KeyboardView(viewModel: vm,
                                gestureState: vm.gestureState,
                                popupState: vm.popupState,
                                layoutOverride: override)
            .frame(width: width, height: height)
            .background(Color(.systemGray6))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer returned nil")
        let att = XCTAttachment(image: image)
        att.lifetime = .keepAlways
        att.name = name
        add(att)
        XCTAssertGreaterThan(image.size.width, 0)
    }

    /// iPad Pro 13" 가로 분리: 폭 1366, 높이 420. 좌=숫자패드 / 우=모아키.
    @MainActor
    func test_snapshot_iPadLandscapeSplit() throws {
        try snapshot(width: 1366, height: 420,
                     override: (isPad: true, isLandscape: true),
                     name: "ipad_landscape_split.png")
    }

    /// iPad 세로 단일(분리 없음): 폭 1024, 높이 400.
    @MainActor
    func test_snapshot_iPadPortraitSingle() throws {
        try snapshot(width: 1024, height: 400,
                     override: (isPad: true, isLandscape: false),
                     name: "ipad_portrait_single.png")
    }

    // MARK: - 지구본 키 (v1.9)
    // 시뮬레이터에서 키보드 익스텐션을 띄워 확인하려면 시스템 키보드 전환 UI를
    // 거쳐야 해 자동화가 불안정하다. 대신 프로덕션 `KeyboardView` 를 아이폰
    // 실제 치수로 렌더해 지구본 키 유무/잘림을 눈으로 검증한다.

    @MainActor
    private func phoneSnapshot(showGlobe: Bool, heightScale: Double, name: String) throws {
        let settings = KeyboardSettings.shared
        let prevScale = settings.keyboardHeightScale
        defer { settings.keyboardHeightScale = prevScale }
        settings.keyboardHeightScale = heightScale

        let height = KeyboardMetrics.keyboardHeight(
            isPad: false, isLandscape: false, screenShort: 402, screenLong: 874,
            scale: heightScale)
        try snapshot(width: 402, height: height,
                     override: (isPad: false, isLandscape: false),
                     name: name, showGlobe: showGlobe)
    }

    /// 지구본 ON — 기능 행 맨 왼쪽에 지구본이 있고 ⏎ 가 잘리지 않아야 한다.
    @MainActor
    func test_snapshot_iPhoneGlobeOn() throws {
        try phoneSnapshot(showGlobe: true, heightScale: 1.0, name: "iphone_globe_on.png")
    }

    /// 지구본 OFF — v1.8.0 과 동일한 기능 행이어야 한다(회귀 비교용).
    @MainActor
    func test_snapshot_iPhoneGlobeOff() throws {
        try phoneSnapshot(showGlobe: false, heightScale: 1.0, name: "iphone_globe_off.png")
    }

    /// 한손 모드 — 375pt(SE·mini, iOS 18 지원으로 범위에 들어옴) + 지구본 표시 + 최소 폭 비율이
    /// 가장 좁은 조합이다. ⏎ 가 잘리지 않고 빈쪽에 띠가 있어야 한다.
    @MainActor
    private func oneHandedSnapshot(_ placement: KeyboardPlacement, name: String) throws {
        let settings = KeyboardSettings.shared
        let prev = (settings.keyboardPlacement, settings.oneHandedWidthRatio)
        defer { settings.keyboardPlacement = prev.0; settings.oneHandedWidthRatio = prev.1 }
        settings.keyboardPlacement = placement
        settings.oneHandedWidthRatio = KeyboardPlacement.widthRatioRange.lowerBound
        let height = KeyboardMetrics.keyboardHeight(
            isPad: false, isLandscape: false, screenShort: 375, screenLong: 667, scale: 1.0)
        try snapshot(width: 375, height: height,
                     override: (isPad: false, isLandscape: false),
                     name: name, showGlobe: true)
    }

    @MainActor
    func test_snapshot_oneHandedLeft() throws {
        try oneHandedSnapshot(.left, name: "iphone_onehanded_left.png")
    }

    @MainActor
    func test_snapshot_oneHandedRight() throws {
        try oneHandedSnapshot(.right, name: "iphone_onehanded_right.png")
    }

    /// 높이 배율 하한/상한에서의 실제 렌더. 키가 찌그러지거나 겹치지 않아야 한다.
    @MainActor
    func test_snapshot_iPhoneHeightScaleMin() throws {
        try phoneSnapshot(showGlobe: true,
                          heightScale: KeyboardMetrics.keyboardHeightScaleRange.lowerBound,
                          name: "iphone_height_min.png")
    }

    @MainActor
    func test_snapshot_iPhoneHeightScaleMax() throws {
        try phoneSnapshot(showGlobe: true,
                          heightScale: KeyboardMetrics.keyboardHeightScaleRange.upperBound,
                          name: "iphone_height_max.png")
    }
}

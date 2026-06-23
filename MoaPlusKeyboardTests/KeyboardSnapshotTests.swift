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
                         name: String) throws {
        let vm = KeyboardViewModel()
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
}

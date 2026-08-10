import XCTest
import UIKit
@testable import MoaPlusKeyboard

/// 배경 이미지가 익스텐션 메모리 한계를 넘기지 않는지 고정.
/// 키보드 익스텐션은 ~30-60MB 에서 강제 종료되고, 사용자에게는 "키보드가
/// 멈췄다"로 보인다. 12MP 사진 한 장이 ARGB 로 ~48MB 라 단독으로 한계를 넘는다.
final class BackgroundImageMemoryTests: XCTestCase {

    private func solidImage(width: CGFloat, height: CGFloat, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { ctx in
                UIColor.systemTeal.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    private func pixelSize(_ image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    /// 12MP 사진 시나리오. 긴 변이 상한으로 내려가고 종횡비가 유지돼야 한다.
    func test_downscale_shrinksOversizedPhotoAndKeepsAspectRatio() {
        let original = solidImage(width: 4032, height: 3024)
        let result = BackgroundImageManager.downscaled(original)
        let size = pixelSize(result)

        XCTAssertEqual(max(size.width, size.height),
                       BackgroundImageManager.maxBackgroundPixelSize, accuracy: 1)
        XCTAssertEqual(size.width / size.height, 4032.0 / 3024.0, accuracy: 0.01)
    }

    /// 이미 작은 이미지는 손대지 않아야 한다 — 불필요한 재인코딩은 화질만 깎는다.
    func test_downscale_leavesSmallImageUntouched() {
        let original = solidImage(width: 800, height: 600)
        let result = BackgroundImageManager.downscaled(original)
        XCTAssertEqual(pixelSize(result), CGSize(width: 800, height: 600))
    }

    /// `image.size` 는 포인트라 scale 을 접지 않으면 3x 이미지가 3배 크게
    /// 저장된다 — 정확히 익스텐션을 죽이는 크기 오차.
    func test_downscale_measuresInPixelsNotPoints() {
        let retina = solidImage(width: 1000, height: 1000, scale: 3)  // 3000x3000 px
        XCTAssertEqual(pixelSize(retina), CGSize(width: 3000, height: 3000), "사전 조건")

        let result = BackgroundImageManager.downscaled(retina)
        XCTAssertEqual(max(pixelSize(result).width, pixelSize(result).height),
                       BackgroundImageManager.maxBackgroundPixelSize, accuracy: 1)
    }

    /// 상한을 넘는 이미지의 비압축 메모리가 익스텐션 예산 안에 들어와야 한다.
    /// ARGB 4바이트 기준 1536x1536 = 9.4MB.
    func test_downscale_boundsDecodedMemoryFootprint() {
        let original = solidImage(width: 6000, height: 4000)
        let size = pixelSize(BackgroundImageManager.downscaled(original))
        let megabytes = (size.width * size.height * 4) / (1024 * 1024)
        XCTAssertLessThan(megabytes, 12, "디코딩 메모리가 익스텐션 예산을 위협함")
    }

    /// 저장 → 로드 왕복에서도 크기가 상한 이하로 유지돼야 한다. 로드 경로는
    /// 다운스케일 도입 이전에 저장된 원본 해상도 파일도 방어해야 하므로
    /// 별도로 검증한다.
    func test_saveThenLoad_returnsBoundedImage() throws {
        let manager = BackgroundImageManager.shared
        let id = "unit-test-oversized-\(UUID().uuidString)"
        defer { manager.deleteUserImage(withId: id) }

        guard manager.saveUserImage(solidImage(width: 4032, height: 3024), withId: id) else {
            throw XCTSkip("App Group 컨테이너를 사용할 수 없는 환경 — 저장 경로 검증 불가")
        }
        let loaded = try XCTUnwrap(manager.loadUserImage(withId: id))
        let size = pixelSize(loaded)
        XCTAssertLessThanOrEqual(max(size.width, size.height),
                                 BackgroundImageManager.maxBackgroundPixelSize + 1)
    }
}

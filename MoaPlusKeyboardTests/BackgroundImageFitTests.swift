import XCTest
import SwiftUI
import UIKit
@testable import MoaPlusKeyboard

/// 배경 사진 맞춤 방식 · 크기 (이슈 #39 — 앱스토어 리뷰 "키보드 배경 사진 크기 작게 안 됩니다").
///
/// 고정하는 것:
/// 1. **기존 사용자는 예전 그대로** — 새 키가 없는 저장값이 꽉 채우기 · 100% 로 읽히고, 다른
///    테마 값(버튼 색·배경 사진·투명도)을 잃지 않는다. 합성 `Decodable` 은 키 하나만 없어도
///    통째로 실패해 `loadAll()` 이 `.default` 로 떨어지므로, 이 테스트가 없으면 업데이트만으로
///    모든 사용자의 테마가 초기화되는 회귀를 놓친다.
/// 2. 크기 계산(`BackgroundImageLayout.displaySize`) — 꽉 채우기/전체 보이기/배율/범위 자르기.
/// 3. 실제 렌더 — 사진은 가운데, 사진이 덮지 않는 곳은 뒤 배경이 그대로 보인다.
final class BackgroundImageFitTests: XCTestCase {

    // MARK: - 기본값

    func test_defaults_keepTodaysFillAt100Percent() {
        XCTAssertEqual(ThemeSettings.default.backgroundImageContentMode, .fill)
        XCTAssertEqual(ThemeSettings.default.backgroundImageScale, 1.0)
        XCTAssertEqual(ThemeSettings().backgroundImageContentMode, .fill)
        XCTAssertEqual(ThemeSettings().backgroundImageScale, 1.0)
    }

    // MARK: - 디코딩 (기존 저장값)

    /// 이전 버전이 실제로 저장하던 모양 그대로의 JSON (새 키 두 개 없음, 기본값이 아닌 값들).
    private let legacyJSON = """
    {
      "appearanceMode": "dark",
      "buttonTheme": "navy",
      "backgroundImageId": "legacy-photo-id",
      "backgroundOpacity": 0.45,
      "hapticEnabled": false,
      "hapticStrength": "light",
      "clickSoundEnabled": true,
      "customKeyBackground": {"red": 0.1, "green": 0.2, "blue": 0.3, "opacity": 1},
      "customKeyText": {"red": 0.9, "green": 0.8, "blue": 0.7, "opacity": 1},
      "customFunctionKeyBackground": {"red": 0.4, "green": 0.5, "blue": 0.6, "opacity": 0.8},
      "keyBackgroundOpacity": 0.7,
      "functionKeyBackgroundOpacity": 0.6,
      "hapticOnTap": false,
      "hapticOnLongPress": false,
      "hapticOnLayerSwitch": false,
      "hapticOnAbbreviationConfirm": false
    }
    """

    func test_decode_legacyJSONWithoutNewKeys_isFillAt100AndKeepsEverythingElse() throws {
        let decoded = try JSONDecoder().decode(ThemeSettings.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(decoded.backgroundImageContentMode, .fill, "기존 사용자가 꽉 채우기가 아니게 됐다")
        XCTAssertEqual(decoded.backgroundImageScale, 1.0, "기존 사용자의 사진 크기가 바뀌었다")

        XCTAssertEqual(decoded.appearanceMode, .dark)
        XCTAssertEqual(decoded.buttonTheme, .navy)
        XCTAssertEqual(decoded.backgroundImageId, "legacy-photo-id", "배경 사진을 잃었다")
        XCTAssertEqual(decoded.backgroundOpacity, 0.45)
        XCTAssertFalse(decoded.hapticEnabled)
        XCTAssertEqual(decoded.hapticStrength, .light)
        XCTAssertTrue(decoded.clickSoundEnabled)
        XCTAssertEqual(decoded.customKeyBackground, CodableColor(red: 0.1, green: 0.2, blue: 0.3))
        XCTAssertEqual(decoded.customKeyText, CodableColor(red: 0.9, green: 0.8, blue: 0.7))
        XCTAssertEqual(decoded.customFunctionKeyBackground,
                       CodableColor(red: 0.4, green: 0.5, blue: 0.6, opacity: 0.8))
        XCTAssertEqual(decoded.keyBackgroundOpacity, 0.7)
        XCTAssertEqual(decoded.functionKeyBackgroundOpacity, 0.6)
        XCTAssertFalse(decoded.hapticOnTap)
        XCTAssertFalse(decoded.hapticOnLongPress)
        XCTAssertFalse(decoded.hapticOnLayerSwitch)
        XCTAssertFalse(decoded.hapticOnAbbreviationConfirm)
    }

    /// 현재 인코더로 만든 값에서 새 키만 지운 경우 — 위 고정 JSON 과 독립적으로 같은 성질을 본다.
    func test_decode_currentEncodingWithNewKeysStripped_equalsOriginalWithDefaults() throws {
        var original = ThemeSettings()
        original.buttonTheme = .beige
        original.backgroundImageId = "abc"
        original.backgroundOpacity = 0.15
        original.keyBackgroundOpacity = 0.5

        let data = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "backgroundImageContentMode")
        object.removeValue(forKey: "backgroundImageScale")
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ThemeSettings.self, from: stripped)
        XCTAssertEqual(decoded, original)
    }

    func test_decode_emptyObject_isDefault() throws {
        let decoded = try JSONDecoder().decode(ThemeSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, ThemeSettings.default)
    }

    /// 다른 버전이 쓴 모르는 맞춤 방식이 와도 테마 전체(배경 사진 포함)를 잃지 않는다.
    func test_decode_unknownContentMode_fallsBackToFillWithoutLosingTheme() throws {
        let json = """
        {"buttonTheme": "navy", "backgroundImageId": "keep-me",
         "backgroundImageContentMode": "stretch", "backgroundImageScale": 0.7}
        """
        let decoded = try JSONDecoder().decode(ThemeSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.backgroundImageContentMode, .fill)
        XCTAssertEqual(decoded.backgroundImageScale, 0.7)
        XCTAssertEqual(decoded.buttonTheme, .navy)
        XCTAssertEqual(decoded.backgroundImageId, "keep-me")
    }

    // MARK: - 인코딩 왕복

    func test_roundTrip_fitAndScale() throws {
        var theme = ThemeSettings()
        theme.backgroundImageContentMode = .fit
        theme.backgroundImageScale = 0.6
        theme.backgroundImageId = "photo"

        let decoded = try JSONDecoder().decode(ThemeSettings.self, from: JSONEncoder().encode(theme))
        XCTAssertEqual(decoded.backgroundImageContentMode, .fit)
        XCTAssertEqual(decoded.backgroundImageScale, 0.6)
        XCTAssertEqual(decoded, theme)
    }

    /// `CodingKeys` 를 손으로 나열했으므로, 필드가 빠지면 인코딩에서 조용히 사라진다.
    /// 저장되는 키 집합을 이전 버전 키 + 새 키 두 개로 못박는다.
    func test_encode_writesEveryStoredKey() throws {
        var theme = ThemeSettings()
        theme.backgroundImageId = "photo"  // nil 이면 키가 생략되므로 채운다
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(theme)) as? [String: Any])
        let legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(legacyJSON.utf8)) as? [String: Any])

        let expected = Set(legacyObject.keys).union(["backgroundImageContentMode", "backgroundImageScale"])
        XCTAssertEqual(Set(object.keys), expected)
        XCTAssertEqual(object["backgroundImageContentMode"] as? String, "fill")
    }

    // MARK: - KeyboardSettings 로드 경로

    /// 디스크(App Group)에 이전 버전 JSON 이 있을 때 `loadAll()` 이 테마를 초기화하지 않는다.
    func test_loadAll_legacyStoredTheme_keepsThemeAndUsesFill() throws {
        let s = KeyboardSettings.shared
        let saved = s.themeSettings
        defer { s.themeSettings = saved }  // didSet 이 디스크에도 되돌려 쓴다

        let store = UserDefaults(suiteName: KeyboardSettings.appGroupId) ?? .standard
        store.set(Data(legacyJSON.utf8), forKey: "themeSettings")
        s.loadAll()

        XCTAssertEqual(s.themeSettings.buttonTheme, .navy, "기존 저장값이 기본 테마로 초기화됐다")
        XCTAssertEqual(s.themeSettings.backgroundImageId, "legacy-photo-id")
        XCTAssertEqual(s.themeSettings.backgroundImageContentMode, .fill)
        XCTAssertEqual(s.themeSettings.backgroundImageScale, 1.0)
    }

    func test_settingsRoundTrip_persistsAcrossLoadAll() {
        let s = KeyboardSettings.shared
        let saved = s.themeSettings
        defer { s.themeSettings = saved }

        var theme = saved
        theme.backgroundImageContentMode = .fit
        theme.backgroundImageScale = 0.75
        s.themeSettings = theme
        s.loadAll()

        XCTAssertEqual(s.themeSettings.backgroundImageContentMode, .fit)
        XCTAssertEqual(s.themeSettings.backgroundImageScale, 0.75)
    }

    // MARK: - 크기 계산

    private let photo = CGSize(width: 375, height: 260)        // 자르기 화면이 고정하는 비율
    private let wideKeyboard = CGSize(width: 420, height: 260)  // 사진보다 가로로 긴 키보드
    private let tallKeyboard = CGSize(width: 375, height: 320)  // 높이 배율을 올린 키보드

    private func assertSize(_ a: CGSize, _ b: CGSize, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.width, b.width, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(a.height, b.height, accuracy: 0.001, file: file, line: line)
    }

    /// 꽉 채우기 100% = `aspectRatio(contentMode: .fill)` 과 같은 크기(기존 렌더링).
    func test_fill_at100_coversContainerLikeAspectFill() {
        for container in [wideKeyboard, tallKeyboard] {
            let size = BackgroundImageLayout.displaySize(
                imageSize: photo, containerSize: container, contentMode: .fill, scale: 1.0)
            let ratio = max(container.width / photo.width, container.height / photo.height)
            assertSize(size, CGSize(width: photo.width * ratio, height: photo.height * ratio))
            XCTAssertGreaterThanOrEqual(size.width + 0.001, container.width)
            XCTAssertGreaterThanOrEqual(size.height + 0.001, container.height)
        }
    }

    /// 전체 보이기 100% = 한 변은 꼭 맞고 다른 변은 안쪽 — 사진이 잘리지 않는다.
    func test_fit_at100_touchesOneEdgeAndFitsInside() {
        for container in [wideKeyboard, tallKeyboard] {
            let size = BackgroundImageLayout.displaySize(
                imageSize: photo, containerSize: container, contentMode: .fit, scale: 1.0)
            XCTAssertLessThanOrEqual(size.width, container.width + 0.001)
            XCTAssertLessThanOrEqual(size.height, container.height + 0.001)
            let touchesWidth = abs(size.width - container.width) < 0.001
            let touchesHeight = abs(size.height - container.height) < 0.001
            XCTAssertTrue(touchesWidth || touchesHeight, "전체 보이기가 키보드에 맞지 않는다: \(size)")
        }
    }

    func test_scale_multipliesBaseSizeAndKeepsAspectRatio() {
        for mode in BackgroundImageContentMode.allCases {
            let full = BackgroundImageLayout.displaySize(
                imageSize: photo, containerSize: wideKeyboard, contentMode: mode, scale: 1.0)
            let half = BackgroundImageLayout.displaySize(
                imageSize: photo, containerSize: wideKeyboard, contentMode: mode, scale: 0.5)
            assertSize(half, CGSize(width: full.width / 2, height: full.height / 2))
            XCTAssertEqual(half.width / half.height, photo.width / photo.height, accuracy: 0.0001)
        }
    }

    func test_scale_outOfRangeIsClamped() {
        let lowest = BackgroundImageLayout.displaySize(
            imageSize: photo, containerSize: wideKeyboard, contentMode: .fit,
            scale: ThemeSettings.backgroundImageScaleRange.lowerBound)
        let full = BackgroundImageLayout.displaySize(
            imageSize: photo, containerSize: wideKeyboard, contentMode: .fit, scale: 1.0)

        assertSize(BackgroundImageLayout.displaySize(
            imageSize: photo, containerSize: wideKeyboard, contentMode: .fit, scale: 0.1), lowest)
        assertSize(BackgroundImageLayout.displaySize(
            imageSize: photo, containerSize: wideKeyboard, contentMode: .fit, scale: 3.0), full)
        assertSize(BackgroundImageLayout.displaySize(
            imageSize: photo, containerSize: wideKeyboard, contentMode: .fit, scale: .nan), full)

        XCTAssertEqual(ThemeSettings.clampedBackgroundImageScale(0.1), 0.5)
        XCTAssertEqual(ThemeSettings.clampedBackgroundImageScale(1.4), 1.0)
        XCTAssertEqual(ThemeSettings.clampedBackgroundImageScale(0.8), 0.8)
        XCTAssertEqual(ThemeSettings.clampedBackgroundImageScale(.infinity), 1.0)
    }

    /// 슬라이더 범위는 줄이기만 하고, 기본값 1.0 을 포함하며, 단계로 나누어떨어진다.
    func test_scaleRange_containsDefaultAndDividesByStep() {
        let range = ThemeSettings.backgroundImageScaleRange
        XCTAssertEqual(range.upperBound, 1.0)
        XCTAssertTrue(range.contains(ThemeSettings.default.backgroundImageScale))
        let steps = (range.upperBound - range.lowerBound) / ThemeSettings.backgroundImageScaleStep
        XCTAssertEqual(steps, steps.rounded(), accuracy: 0.0001)
    }

    func test_zeroSizes_returnZero() {
        XCTAssertEqual(BackgroundImageLayout.displaySize(
            imageSize: .zero, containerSize: wideKeyboard, contentMode: .fill, scale: 1), .zero)
        XCTAssertEqual(BackgroundImageLayout.displaySize(
            imageSize: CGSize(width: 0, height: 100), containerSize: wideKeyboard, contentMode: .fit, scale: 1), .zero)
        XCTAssertEqual(BackgroundImageLayout.displaySize(
            imageSize: photo, containerSize: .zero, contentMode: .fit, scale: 1), .zero)
    }

    // MARK: - 렌더링

    private func solidImage(_ color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 프로덕션 배경 뷰를 파란 바탕 위에 불투명(1.0)으로 그려 픽셀 RGBA 를 돌려준다.
    @MainActor
    private func render(mode: BackgroundImageContentMode, scale: Double,
                        container: CGSize) throws -> (width: Int, height: Int, rgba: [UInt8]) {
        let view = ZStack {
            Color(red: 0, green: 0, blue: 1)
            KeyboardBackgroundImageView(
                image: solidImage(.red, size: photo),
                opacity: 1.0,
                contentMode: mode,
                scale: scale)
        }
        .frame(width: container.width, height: container.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let cgImage = try XCTUnwrap(renderer.cgImage, "ImageRenderer returned nil")
        let width = cgImage.width, height = cgImage.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &rgba, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (width, height, rgba)
    }

    private func isPhoto(_ px: (width: Int, height: Int, rgba: [UInt8]), x: Int, y: Int) -> Bool {
        let i = (y * px.width + x) * 4
        return px.rgba[i] > 200 && px.rgba[i + 2] < 60
    }

    private func isBackdrop(_ px: (width: Int, height: Int, rgba: [UInt8]), x: Int, y: Int) -> Bool {
        let i = (y * px.width + x) * 4
        return px.rgba[i] < 60 && px.rgba[i + 2] > 200
    }

    /// 꽉 채우기 100%(기본) — 기존처럼 사진이 키보드 전체를 덮는다.
    @MainActor
    func test_render_fillAt100_coversEveryCorner() throws {
        let px = try render(mode: .fill, scale: 1.0, container: wideKeyboard)
        XCTAssertEqual(px.width, Int(wideKeyboard.width))
        for (x, y) in [(2, 2), (px.width - 3, 2), (2, px.height - 3), (px.width - 3, px.height - 3),
                       (px.width / 2, px.height / 2)] {
            XCTAssertTrue(isPhoto(px, x: x, y: y), "꽉 채우기인데 (\(x),\(y)) 가 사진이 아니다")
        }
    }

    /// 50% — 사진은 가운데에 남고, 사진이 덮지 않는 곳은 뒤 배경이 그대로 보인다.
    @MainActor
    func test_render_shrunkPhoto_staysCenteredAndRevealsBackground() throws {
        for mode in BackgroundImageContentMode.allCases {
            let px = try render(mode: mode, scale: 0.5, container: wideKeyboard)
            let size = BackgroundImageLayout.displaySize(
                imageSize: photo, containerSize: wideKeyboard, contentMode: mode, scale: 0.5)
            let cx = px.width / 2, cy = px.height / 2

            XCTAssertTrue(isPhoto(px, x: cx, y: cy), "\(mode): 가운데가 사진이 아니다")
            // 사진 가장자리 바로 안쪽 / 바로 바깥 — 좌우·상하 대칭이면 가운데 정렬이다.
            let halfW = Int(size.width / 2), halfH = Int(size.height / 2)
            XCTAssertTrue(isPhoto(px, x: cx - halfW + 3, y: cy), "\(mode): 사진 왼쪽 끝")
            XCTAssertTrue(isPhoto(px, x: cx + halfW - 3, y: cy), "\(mode): 사진 오른쪽 끝")
            XCTAssertTrue(isBackdrop(px, x: cx - halfW - 3, y: cy), "\(mode): 사진 왼쪽 바깥")
            XCTAssertTrue(isBackdrop(px, x: cx + halfW + 3, y: cy), "\(mode): 사진 오른쪽 바깥")
            XCTAssertTrue(isBackdrop(px, x: cx, y: cy - halfH - 3), "\(mode): 사진 위쪽 바깥")
            XCTAssertTrue(isBackdrop(px, x: cx, y: cy + halfH + 3), "\(mode): 사진 아래쪽 바깥")
            XCTAssertTrue(isBackdrop(px, x: 2, y: 2), "\(mode): 모서리가 배경이 아니다")
        }
    }

    /// 전체 보이기 100% — 가로로 긴 키보드에서는 좌우에 배경이 남는다(사진이 잘리지 않음).
    @MainActor
    func test_render_fitAt100_showsBackgroundBesidePhoto() throws {
        let px = try render(mode: .fit, scale: 1.0, container: wideKeyboard)
        XCTAssertTrue(isBackdrop(px, x: 2, y: px.height / 2), "왼쪽 여백이 없다")
        XCTAssertTrue(isBackdrop(px, x: px.width - 3, y: px.height / 2), "오른쪽 여백이 없다")
        XCTAssertTrue(isPhoto(px, x: px.width / 2, y: 2), "위쪽 끝까지 사진이어야 한다")
        XCTAssertTrue(isPhoto(px, x: px.width / 2, y: px.height - 3), "아래쪽 끝까지 사진이어야 한다")
    }
}

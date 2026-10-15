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
/// 2. 크기 계산(`BackgroundImageLayout.displaySize` / `displayRect`) — 꽉 채우기/전체 보이기/배율/
///    범위 자르기 + 한손 모드 본체 기준 배치.
/// 3. 실제 렌더 — 사진은 가운데, 사진이 덮지 않는 곳은 뒤 배경이 그대로 보인다.
/// 4. **`KeyboardView` 배선** (리뷰 반영) — 3 은 `KeyboardBackgroundImageView` 만 그려서
///    `KeyboardView` 가 테마 값을 잘못 넘겨도 통과한다. `test_keyboardView_*` 는 실제 `KeyboardView`
///    를 `KeyboardSettings.shared.themeSettings` 로 그려 사진 자리를 픽셀로 잰다.
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

    /// 뷰를 1x 로 그려 픽셀 RGBA 를 돌려준다.
    @MainActor
    private func pixels<V: View>(of view: V) throws -> (width: Int, height: Int, rgba: [UInt8]) {
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
        return try pixels(of: view)
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

    // MARK: - 크기 % 표시

    /// 설정 화면의 % 는 그리는 크기와 같은 값이고, 비정상 저장값에서 크래시하지 않는다.
    func test_scalePercent_showsClampedValueAndNeverTraps() {
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(1.0), 100)
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(0.65), 65, "내림 오차(64) 가 나면 안 된다")
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(0.5), 50)
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(0.1), 50, "범위 밖 값은 실제로 그리는 50% 로")
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(3.0), 100)
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(.nan), 100, "NaN 은 Int(_:) 에서 크래시한다")
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(.infinity), 100)
        XCTAssertEqual(ThemeSettings.backgroundImageScalePercent(-.infinity), 100)
    }

    // MARK: - 배치 (displayRect)

    private let squarePhoto = CGSize(width: 200, height: 200)
    private let phoneKeyboard = CGSize(width: 402, height: 260)   // iPhone 17 세로 기본 높이

    private func assertRect(_ a: CGRect, _ b: CGRect, accuracy: CGFloat = 0.001,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.minX, b.minX, accuracy: accuracy, "minX \(a) vs \(b)", file: file, line: line)
        XCTAssertEqual(a.minY, b.minY, accuracy: accuracy, "minY \(a) vs \(b)", file: file, line: line)
        XCTAssertEqual(a.maxX, b.maxX, accuracy: accuracy, "maxX \(a) vs \(b)", file: file, line: line)
        XCTAssertEqual(a.maxY, b.maxY, accuracy: accuracy, "maxY \(a) vs \(b)", file: file, line: line)
    }

    /// focus 가 없으면(한손 모드 아님) 예전 그대로 — `displaySize` 를 컨테이너 가운데에.
    func test_displayRect_withoutFocus_isCenteredDisplaySize() {
        for mode in BackgroundImageContentMode.allCases {
            for scale in [1.0, 0.75, 0.5] {
                let size = BackgroundImageLayout.displaySize(
                    imageSize: squarePhoto, containerSize: phoneKeyboard, contentMode: mode, scale: scale)
                let expected = CGRect(x: (phoneKeyboard.width - size.width) / 2,
                                      y: (phoneKeyboard.height - size.height) / 2,
                                      width: size.width, height: size.height)
                assertRect(BackgroundImageLayout.displayRect(
                    imageSize: squarePhoto, containerSize: phoneKeyboard, contentMode: mode, scale: scale),
                           expected)
                // 컨테이너 전체를 focus 로 줘도 같다.
                assertRect(BackgroundImageLayout.displayRect(
                    imageSize: squarePhoto, containerSize: phoneKeyboard,
                    focus: CGRect(origin: .zero, size: phoneKeyboard), contentMode: mode, scale: scale),
                           expected)
            }
        }
    }

    /// 한손 모드(402pt, 0.82 → 본체 329pt). 손으로 계산한 값으로 못박는다.
    func test_displayRect_oneHanded_handComputed() {
        let left = CGRect(x: 0, y: 0, width: 329, height: 260)     // 본체가 왼쪽, 띠 73pt 가 오른쪽
        let right = CGRect(x: 73, y: 0, width: 329, height: 260)   // 띠가 왼쪽
        func rect(_ focus: CGRect, _ mode: BackgroundImageContentMode, _ scale: Double) -> CGRect {
            BackgroundImageLayout.displayRect(imageSize: squarePhoto, containerSize: phoneKeyboard,
                                              focus: focus, contentMode: mode, scale: scale)
        }
        // 꽉 채우기 100%(기본): 표면 전체(띠 포함) 기준 402×402, 전체 폭 가운데 — 예전 픽셀 그대로.
        assertRect(rect(left, .fill, 1.0), CGRect(x: 0, y: -71, width: 402, height: 402))
        assertRect(rect(right, .fill, 1.0), CGRect(x: 0, y: -71, width: 402, height: 402))
        // 꽉 채우기 50%: 크기는 표면 기준(201), 위치는 본체 가운데(164.5 / 237.5).
        assertRect(rect(left, .fill, 0.5), CGRect(x: 64, y: 29.5, width: 201, height: 201))
        assertRect(rect(right, .fill, 0.5), CGRect(x: 137, y: 29.5, width: 201, height: 201))
        // 꽉 채우기 90%(361.8): 본체(329)보다 넓다 — 본체 쪽으로 붙이되 표면 밖으로는 안 나간다.
        assertRect(rect(left, .fill, 0.9), CGRect(x: 0, y: -50.9, width: 361.8, height: 361.8))
        assertRect(rect(right, .fill, 0.9), CGRect(x: 402 - 361.8, y: -50.9, width: 361.8, height: 361.8))
        // 전체 보이기: 크기부터 본체 기준(329×260 → 260), 본체 가운데.
        assertRect(rect(left, .fit, 1.0), CGRect(x: 34.5, y: 0, width: 260, height: 260))
        assertRect(rect(right, .fit, 1.0), CGRect(x: 107.5, y: 0, width: 260, height: 260))
        assertRect(rect(left, .fit, 0.5), CGRect(x: 99.5, y: 65, width: 130, height: 130))
        assertRect(rect(right, .fit, 0.5), CGRect(x: 172.5, y: 65, width: 130, height: 130))
    }

    /// 사진 길이가 컨테이너 길이에 다가가면 허용 범위가 가운데로 줄어 끊김 없이 이어진다.
    func test_placedCenter_isContinuousAtContainerLength() {
        let preferred: CGFloat = 164.5
        XCTAssertEqual(BackgroundImageLayout.placedCenter(length: 402, containerLength: 402, preferred: preferred), 201)
        XCTAssertEqual(BackgroundImageLayout.placedCenter(length: 500, containerLength: 402, preferred: preferred), 201)
        XCTAssertEqual(BackgroundImageLayout.placedCenter(length: 401.9, containerLength: 402, preferred: preferred),
                       201, accuracy: 0.1)
        XCTAssertEqual(BackgroundImageLayout.placedCenter(length: 100, containerLength: 402, preferred: preferred), 164.5)
        XCTAssertEqual(BackgroundImageLayout.placedCenter(length: 100, containerLength: 402, preferred: 10), 50)
        XCTAssertEqual(BackgroundImageLayout.placedCenter(length: 100, containerLength: 402, preferred: 400), 352)
    }

    /// 비거나 컨테이너 밖인 focus 는 무시한다(컨테이너 전체 기준).
    func test_displayRect_degenerateFocus_fallsBackToContainer() {
        let plain = BackgroundImageLayout.displayRect(
            imageSize: squarePhoto, containerSize: phoneKeyboard, contentMode: .fit, scale: 0.5)
        for focus in [CGRect.zero, CGRect(x: 500, y: 0, width: 50, height: 260),
                      CGRect(x: 0, y: 300, width: 402, height: 10)] {
            assertRect(BackgroundImageLayout.displayRect(
                imageSize: squarePhoto, containerSize: phoneKeyboard, focus: focus,
                contentMode: .fit, scale: 0.5), plain)
        }
    }

    // MARK: - KeyboardView 배선 (리뷰 반영)
    //
    // 실제 `KeyboardView` 를 그린다. 키가 사진 위를 덮으므로 고정 좌표 샘플링은 레이아웃이 바뀔 때마다
    // 깨진다 — 대신 같은 설정으로 **사진 없이 / 사진 있게** 두 번 그려 달라진 픽셀의 상자를 잰다. 그 상자가
    // 화면에 그려진 사진 자리다(글자는 상자 안쪽에 구멍만 낼 뿐 상자 크기를 바꾸지 않는다).
    // 사진이 키 밑에서도 보이도록 키·기능키 배경 투명도를 0 으로 둔다(실제 사용자 설정 범위의 값).

    private typealias Pixels = (width: Int, height: Int, rgba: [UInt8])

    /// 테마·한손 모드를 바꿔 `body` 를 돌리고 원래대로 돌려놓는다(App Group 에도 되돌려 쓴다).
    @MainActor
    private func withKeyboardSettings(
        contentMode: BackgroundImageContentMode = .fill,
        scale: Double = 1.0,
        opacity: Double = 1.0,
        placement: KeyboardPlacement = .full,
        _ body: @MainActor () throws -> Void
    ) rethrows {
        let s = KeyboardSettings.shared
        let saved = (s.themeSettings, s.keyboardPlacement, s.oneHandedWidthRatio)
        defer {
            s.themeSettings = saved.0
            s.keyboardPlacement = saved.1
            s.oneHandedWidthRatio = saved.2
        }
        var theme = ThemeSettings.default
        theme.backgroundOpacity = opacity
        theme.keyBackgroundOpacity = 0
        theme.functionKeyBackgroundOpacity = 0
        theme.backgroundImageContentMode = contentMode
        theme.backgroundImageScale = scale
        s.themeSettings = theme
        s.keyboardPlacement = placement
        s.oneHandedWidthRatio = KeyboardPlacement.defaultWidthRatio
        try body()
    }

    /// 프로덕션 `KeyboardView`(아이폰 세로 강제)를 파란 바탕 위에 1x 로 그린다. 파란 바탕은
    /// `KeyboardView` 가 자기 밑바탕(`systemGray6`)을 그리지 않으면 드러난다.
    @MainActor
    private func renderKeyboardView(photo: UIImage?, size: CGSize) throws -> Pixels {
        let vm = KeyboardViewModel()
        let view = KeyboardView(viewModel: vm,
                                gestureState: vm.gestureState,
                                popupState: vm.popupState,
                                layoutOverride: (isPad: false, isLandscape: false),
                                backgroundImageOverride: photo)
            .frame(width: size.width, height: size.height)
            .background(Color(red: 0, green: 0, blue: 1))
        let px = try pixels(of: view)
        XCTAssertEqual(px.width, Int(size.width))
        XCTAssertEqual(px.height, Int(size.height))
        return px
    }

    /// 두 렌더에서 한 채널이라도 `threshold` 넘게 다른 픽셀들의 상자 (픽셀 좌표, 끝 포함). 없으면 nil.
    private func differingBox(_ a: Pixels, _ b: Pixels, threshold: Int = 40) -> CGRect? {
        precondition(a.width == b.width && a.height == b.height)
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for y in 0..<a.height {
            for x in 0..<a.width {
                let i = (y * a.width + x) * 4
                let differs = (0..<3).contains { abs(Int(a.rgba[i + $0]) - Int(b.rgba[i + $0])) > threshold }
                guard differs else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard minX <= maxX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// 두 렌더의 채널 차이 최댓값 — 투명도가 그대로 전달되는지 보는 데 쓴다.
    private func maxChannelDifference(_ a: Pixels, _ b: Pixels) -> Int {
        var best = 0
        for i in stride(from: 0, to: a.rgba.count, by: 4) {
            for c in 0..<3 { best = max(best, abs(Int(a.rgba[i + c]) - Int(b.rgba[i + c]))) }
        }
        return best
    }

    /// 사진이 화면에 그려진 상자. 기대 사각형은 화면 밖으로 나간 부분을 잘라 픽셀로 비교한다
    /// (가장자리 반 픽셀·안티앨리어싱 몫으로 ±2px).
    @MainActor
    private func photoBox(size: CGSize) throws -> CGRect? {
        let photo = solidImage(.red, size: squarePhoto)
        let without = try renderKeyboardView(photo: nil, size: size)
        let with = try renderKeyboardView(photo: photo, size: size)
        return differingBox(without, with)
    }

    private func assertBox(_ box: CGRect?, matches expected: CGRect, in size: CGSize, _ message: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        guard let box else { return XCTFail("\(message): 사진이 그려지지 않았다", file: file, line: line) }
        let visible = expected.intersection(CGRect(origin: .zero, size: size))
        assertRect(box, visible, accuracy: 2, file: file, line: line)
    }

    /// 꽉 채우기 100%(기본) — 실제 `KeyboardView` 에서 사진이 키보드 전체를 덮는다(예전 그대로).
    /// 아래 테스트들이 기대 사각형을 프레임 기준으로 계산하는 전제(배경 = 프레임 전체)도 이걸로 확인된다.
    @MainActor
    func test_keyboardView_defaultFill_coversWholeKeyboard() throws {
        try withKeyboardSettings {
            XCTAssertEqual(KeyboardSettings.shared.themeSettings.backgroundImageContentMode, .fill)
            XCTAssertEqual(KeyboardSettings.shared.themeSettings.backgroundImageScale, 1.0)
            let box = try photoBox(size: phoneKeyboard)
            assertBox(box, matches: CGRect(origin: .zero, size: phoneKeyboard), in: phoneKeyboard, "기본")
        }
    }

    /// 테마의 맞춤 방식·크기가 `KeyboardView` 를 거쳐 사진 자리로 나온다.
    @MainActor
    func test_keyboardView_fitAndScale_followTheme() throws {
        // 정사각 사진 · 402×260 — 맞춤 방식마다 상자가 크게 다르다.
        let cases: [(BackgroundImageContentMode, Double, CGRect)] = [
            (.fit, 1.0, CGRect(x: 71, y: 0, width: 260, height: 260)),
            (.fit, 0.5, CGRect(x: 136, y: 65, width: 130, height: 130)),
            (.fill, 0.5, CGRect(x: 100.5, y: 29.5, width: 201, height: 201)),
            (.fill, 0.75, CGRect(x: 50.25, y: -20.75, width: 301.5, height: 301.5)),
        ]
        for (mode, scale, expected) in cases {
            try withKeyboardSettings(contentMode: mode, scale: scale) {
                let box = try photoBox(size: phoneKeyboard)
                assertBox(box, matches: expected, in: phoneKeyboard, "\(mode) \(scale)")
                // 가운데 정렬(함수와 독립적인 성질).
                if let box {
                    XCTAssertEqual(box.midX, phoneKeyboard.width / 2, accuracy: 2, "\(mode) \(scale): 가운데가 아니다")
                }
            }
        }
    }

    /// 사진이 덮지 않는 곳은 `KeyboardView` 자신의 밑바탕(`systemGray6`)이다 — 바깥 파란 바탕이
    /// 드러나면 밑바탕이 빠진 것이다(메인 앱 미리보기에서 목록 셀 색이 비친다).
    @MainActor
    func test_keyboardView_uncoveredAreaShowsKeyboardUnderlay() throws {
        try withKeyboardSettings(contentMode: .fit, scale: 0.5) {
            let px = try renderKeyboardView(photo: solidImage(.red, size: squarePhoto), size: phoneKeyboard)
            for (x, y) in [(1, 1), (px.width - 2, 1), (1, px.height - 2), (px.width - 2, px.height - 2)] {
                let i = (y * px.width + x) * 4
                let (r, g, b) = (Int(px.rgba[i]), Int(px.rgba[i + 1]), Int(px.rgba[i + 2]))
                XCTAssertLessThan(abs(r - g), 20, "(\(x),\(y)) 가 회색 밑바탕이 아니다: \(r),\(g),\(b)")
                XCTAssertLessThan(b - r, 40, "(\(x),\(y)) 에 바깥 바탕이 비친다: \(r),\(g),\(b)")
            }
        }
    }

    /// 테마 투명도로 그린 `KeyboardView` 의 사진 있음/없음 채널 차이 최댓값.
    @MainActor
    private func photoDifference(opacity: Double) throws -> Int {
        var result = 0
        try withKeyboardSettings(contentMode: .fit, scale: 0.5, opacity: opacity) {
            let without = try renderKeyboardView(photo: nil, size: phoneKeyboard)
            let with = try renderKeyboardView(photo: solidImage(.red, size: squarePhoto), size: phoneKeyboard)
            result = maxChannelDifference(without, with)
        }
        return result
    }

    /// 배경 투명도도 테마에서 온다 — 0 이면 사진이 안 보이고, 0.5 면 1.0 보다 확실히 옅다.
    /// (합성 색 공간에 따라 정확히 절반은 아닐 수 있어 범위로 본다.)
    @MainActor
    func test_keyboardView_backgroundOpacity_followsTheme() throws {
        let opaque = try photoDifference(opacity: 1.0)
        let half = try photoDifference(opacity: 0.5)
        let none = try photoDifference(opacity: 0)
        XCTAssertGreaterThan(opaque, 150, "불투명 사진이 보이지 않는다")
        XCTAssertLessThanOrEqual(none, 2, "투명도 0 인데 사진이 보인다")
        XCTAssertGreaterThan(half, opaque * 15 / 100, "투명도 0.5 가 전달되지 않았다(사진이 안 보임)")
        XCTAssertLessThan(half, opaque * 85 / 100, "투명도 0.5 가 전달되지 않았다(불투명하게 그려짐)")
    }

    /// 한손 모드 기본(꽉 채우기 100%) — 예전처럼 띠 밑까지 사진이 덮는다.
    @MainActor
    func test_keyboardView_oneHanded_defaultFill_coversStripToo() throws {
        for side in [KeyboardPlacement.left, .right] {
            try withKeyboardSettings(placement: side) {
                let box = try photoBox(size: phoneKeyboard)
                assertBox(box, matches: CGRect(origin: .zero, size: phoneKeyboard), in: phoneKeyboard,
                          "한손 \(side) 기본")
            }
        }
    }

    /// 한손 모드에서 줄인 사진·전체 보이기는 띠가 아니라 **키보드 본체** 가운데에 놓인다 (리뷰 반영).
    @MainActor
    func test_keyboardView_oneHanded_photoCenteredUnderBody() throws {
        let bodyWidth = KeyboardPlacement.keyboardWidth(
            totalWidth: phoneKeyboard.width, ratio: KeyboardPlacement.defaultWidthRatio)
        XCTAssertEqual(bodyWidth, 329)
        let strip = phoneKeyboard.width - bodyWidth
        for side in [KeyboardPlacement.left, .right] {
            let body = CGRect(x: side == .right ? strip : 0, y: 0, width: bodyWidth, height: phoneKeyboard.height)
            for (mode, scale) in [(BackgroundImageContentMode.fit, 1.0), (.fit, 0.5), (.fill, 0.5)] {
                try withKeyboardSettings(contentMode: mode, scale: scale, placement: side) {
                    let box = try photoBox(size: phoneKeyboard)
                    let expected = BackgroundImageLayout.displayRect(
                        imageSize: squarePhoto, containerSize: phoneKeyboard, focus: body,
                        contentMode: mode, scale: scale)
                    assertBox(box, matches: expected, in: phoneKeyboard, "한손 \(side) \(mode) \(scale)")
                    guard let box else { return }
                    // 함수와 독립적인 성질: 본체 안, 본체 가운데.
                    XCTAssertEqual(box.midX, body.midX, accuracy: 2, "한손 \(side) \(mode) \(scale): 본체 가운데가 아니다")
                    XCTAssertGreaterThanOrEqual(box.minX, body.minX - 1, "한손 \(side) \(mode) \(scale): 띠 밑으로 샌다")
                    XCTAssertLessThanOrEqual(box.maxX, body.maxX + 1, "한손 \(side) \(mode) \(scale): 띠 밑으로 샌다")
                }
            }
        }
    }
}

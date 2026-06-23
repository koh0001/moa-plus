import XCTest
@testable import MoaPlusKeyboard

final class KeyboardSettingsLayoutTests: XCTestCase {
    func testDefaultLayoutCustomizationIsV13() {
        let s = KeyboardSettings.shared
        // Reset to defaults to isolate from other tests
        s.layoutCustomization = LayoutCustomization()
        XCTAssertEqual(s.layoutCustomization.slotA, .vowel)
        XCTAssertFalse(s.layoutCustomization.slotABackspaceSwap)
        XCTAssertEqual(s.layoutCustomization.slotB, .punctuation)
    }

    func testFirstLaunchFlagDefaultIsReadable() {
        // Just verify the property exists and is a Bool. Default depends on prior test state.
        let _: Bool = KeyboardSettings.shared.firstLaunchModalShown
    }

    func testRoundTripPersistsAcrossLoadAll() {
        let s = KeyboardSettings.shared
        var custom = LayoutCustomization()
        custom.slotA = .classic11
        custom.slotABackspaceSwap = true
        s.layoutCustomization = custom
        s.loadAll()
        XCTAssertEqual(s.layoutCustomization.slotA, .classic11)
        XCTAssertTrue(s.layoutCustomization.slotABackspaceSwap)
        // Cleanup
        s.layoutCustomization = LayoutCustomization()
    }

    // MARK: - numberPadSide (T6)

    func testNumberPadSide_defaultIsLeft() {
        XCTAssertEqual(LayoutCustomization().numberPadSide, .left)
    }

    func testNumberPadSide_roundTripsRight() throws {
        var lc = LayoutCustomization()
        lc.numberPadSide = .right
        let data = try JSONEncoder().encode(lc)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded.numberPadSide, .right)
    }

    func testNumberPadSide_absentKeyDecodesToLeft() throws {
        // 구버전 JSON(키 없음) → 기본 .left (전체 설정 리셋 방지)
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: json)
        XCTAssertEqual(decoded.numberPadSide, .left)
    }
}

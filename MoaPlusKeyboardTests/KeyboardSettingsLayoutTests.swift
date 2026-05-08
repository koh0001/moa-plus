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
}

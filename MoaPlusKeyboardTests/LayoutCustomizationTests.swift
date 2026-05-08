import XCTest
@testable import MoaPlusKeyboard

final class LayoutCustomizationTests: XCTestCase {
    func testDefaultMatches13Behavior() {
        let layout = LayoutCustomization()
        XCTAssertEqual(layout.slotA, .vowel)
        XCTAssertFalse(layout.slotABackspaceSwap)
        XCTAssertEqual(layout.slotB, .punctuation)
        XCTAssertEqual(layout.slotC, ["~", "^", ";", "*"])
    }

    func testCodableRoundTrip() throws {
        var original = LayoutCustomization()
        original.slotA = .classic11
        original.slotABackspaceSwap = true
        original.slotB = .vowelKey
        original.slotC = ["@", "#", "$", "%"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSlotCMustHaveFourElements() {
        let json = #"{"slotA":"vowel","slotB":"punctuation","slotC":["a","b"]}"#
        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded?.slotC.count, 4)
    }

    func testSwapDefaultIsFalse() {
        let json = #"{"slotA":"vowel","slotB":"punctuation","slotC":["~","^",";","*"]}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertFalse(decoded.slotABackspaceSwap, "swap 필드 없는 디스크 데이터는 false 로 시작")
    }
}

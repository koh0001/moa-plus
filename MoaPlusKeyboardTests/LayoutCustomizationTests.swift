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

    func testSwapDefaultIsFalse() throws {
        let json = #"{"slotA":"vowel","slotB":"punctuation","slotC":["~","^",";","*"]}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertFalse(decoded.slotABackspaceSwap, "swap 필드 없는 디스크 데이터는 false 로 시작")
    }

    func testDefaultSlotARightColumn() {
        let layout = LayoutCustomization()
        XCTAssertEqual(layout.slotARightColumn, ["!", "?", "."])
    }

    func testSlotARightColumnNormalizesTo3Elements() throws {
        let json = #"{"slotARightColumn":["a","b"]}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded.slotARightColumn.count, 3)
    }

    // MARK: - PunctuationSlots

    func testPunctuationSlotsDefaultKorean() {
        let slots = PunctuationSlots.defaultKorean
        XCTAssertEqual(slots.tap, ".")
        XCTAssertEqual(slots.left, "?")
        XCTAssertEqual(slots.right, "!")
        XCTAssertEqual(slots.up, ",")
        XCTAssertEqual(slots.down, ".")
    }

    func testPunctuationSlotsDefaultEnglish() {
        let slots = PunctuationSlots.defaultEnglish
        XCTAssertEqual(slots.tap, ".")
        XCTAssertEqual(slots.left, "?")
        XCTAssertEqual(slots.right, "!")
        XCTAssertEqual(slots.up, ",")
        XCTAssertEqual(slots.down, ".")
    }

    func testPunctuationSlotsCodableRoundTrip() throws {
        let original = PunctuationSlots(tap: "👍", left: "ㅎㅎ", right: "", up: "ok", down: ":)")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PunctuationSlots.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testPunctuationSlotsEmptySlotPreserved() throws {
        let original = PunctuationSlots(tap: ".", left: "", right: "!", up: "", down: ".")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PunctuationSlots.self, from: data)
        XCTAssertEqual(decoded.left, "")
        XCTAssertEqual(decoded.up, "")
    }

    // MARK: - Punctuation enable/slots fields

    func testDefaultPunctuationEnableFlags() {
        let layout = LayoutCustomization()
        XCTAssertTrue(layout.koreanPunctuationEnabled, "한글은 기존 동작 유지 — 기본 ON")
        XCTAssertFalse(layout.englishPunctuationEnabled, "영문은 신규 기능 — 기본 OFF로 regression 방지")
        XCTAssertFalse(layout.slotARightColumnTopAsPunctuation, "A1 # 자리 옵션 기본 OFF")
    }

    func testDefaultPunctuationSlots() {
        let layout = LayoutCustomization()
        XCTAssertEqual(layout.koreanPunctuationSlots, .defaultKorean)
        XCTAssertEqual(layout.englishPunctuationSlots, .defaultEnglish)
    }

    func testLegacyDataMigratesPunctuationFields() throws {
        // v1.4 사용자의 디스크 데이터에는 신규 필드가 없음 → 기본값으로 채워져야 함
        let legacyJSON = #"{"slotA":"vowel","slotB":"punctuation","slotC":["~","^",";","*"]}"#
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertTrue(decoded.koreanPunctuationEnabled)
        XCTAssertFalse(decoded.englishPunctuationEnabled)
        XCTAssertFalse(decoded.slotARightColumnTopAsPunctuation)
        XCTAssertEqual(decoded.koreanPunctuationSlots, .defaultKorean)
        XCTAssertEqual(decoded.englishPunctuationSlots, .defaultEnglish)
    }

    func testNewFieldsCodableRoundTrip() throws {
        var original = LayoutCustomization()
        original.englishPunctuationEnabled = true
        original.koreanPunctuationEnabled = false
        original.slotARightColumnTopAsPunctuation = true
        original.englishPunctuationSlots = PunctuationSlots(tap: "👍", left: "", right: "?", up: ",", down: ".")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - iPad 세로 분리 토글

    func testIPadPortraitSplitDefaultsFalse() {
        XCTAssertFalse(LayoutCustomization().iPadPortraitSplitEnabled, "세로 분리 신규 기능 — 기본 OFF")
    }

    func testIPadPortraitSplitRoundTrips() throws {
        var lc = LayoutCustomization()
        lc.iPadPortraitSplitEnabled = true
        let data = try JSONEncoder().encode(lc)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertTrue(decoded.iPadPortraitSplitEnabled)
    }

    func testLegacyDataDefaultsIPadPortraitSplitFalse() throws {
        let legacyJSON = #"{"slotA":"vowel","slotB":"punctuation","slotC":["~","^",";","*"]}"#
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: legacyJSON.data(using: .utf8)!)
        XCTAssertFalse(decoded.iPadPortraitSplitEnabled, "구버전 JSON → false 기본")
    }
}

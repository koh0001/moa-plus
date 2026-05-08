import XCTest
@testable import MoaPlusKeyboard

final class KeyboardMetricsLayoutTests: XCTestCase {
    func testA1NoSwap_BackspaceAtRow1() {
        let layout = LayoutCustomization()
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[1][6], .backspace)
        XCTAssertEqual(grid[3][6], .vowelPrimitive(.dot))
    }

    func testA1WithSwap_BackspaceAtRow3() {
        var layout = LayoutCustomization()
        layout.slotABackspaceSwap = true
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[1][6], .vowelPrimitive(.dot))
        XCTAssertEqual(grid[3][6], .backspace)
    }

    func testA1Layout_col0FromSlotC() {
        var layout = LayoutCustomization()
        layout.slotC = ["A", "B", "C", "D"]
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[0][0], .symbol("A"))
        XCTAssertEqual(grid[3][0], .symbol("D"))
    }

    func testA2Layout_col6IsPunctuationsAndWideBackspace() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[0][6], .symbol("!"))
        XCTAssertEqual(grid[1][6], .symbol("?"))
        XCTAssertEqual(grid[2][6], .symbol("."))
        XCTAssertEqual(grid[3].count, 6)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testA2_swapToggleIgnored() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        layout.slotABackspaceSwap = true   // 무시되어야 함
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testKeyWidth_backspaceWideMatchesRow0Width() {
        // Wide ⌫ should equal (col 5 + spacing + col 6) of upper rows so the
        // grid stays rectangular regardless of side-key-width slider position.
        let centerWidth: CGFloat = 40.0
        let sideWidth = centerWidth * KeyboardMetrics.symbolWidthRatio * 1.3
        let wide = KeyboardMetrics.keyWidth(forBackspaceWideAt: 5, centerKeyWidth: centerWidth)
        XCTAssertEqual(wide, centerWidth + sideWidth + KeyboardMetrics.keySpacing, accuracy: 0.01)
    }

    func testA3Layout_col6HasEmbeddedSlotBKeys() {
        var layout = LayoutCustomization()
        layout.slotA = .fullPackage
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[0][6], .symbol("#"))
        XCTAssertEqual(grid[1][6], .slotBVowelKey)
        XCTAssertEqual(grid[2][6], .slotBPunctuation)
        XCTAssertEqual(grid[3].count, 6)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testA3_longPressNumberCol6IsAllNil() {
        var layout = LayoutCustomization()
        layout.slotA = .fullPackage
        for row in 0..<4 {
            XCTAssertNil(KeyboardMetrics.longPressNumber(at: row, column: 6, layout: layout))
        }
    }

    func testLongPressNumber_A2Col6IsAllNil() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        for row in 0..<4 {
            XCTAssertNil(KeyboardMetrics.longPressNumber(at: row, column: 6, layout: layout))
        }
    }

    func testLongPressNumber_consonantPositionsUnchanged() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        XCTAssertEqual(KeyboardMetrics.longPressNumber(at: 1, column: 1, layout: layout), "6")
    }

    func testA2_customRightColumnReflected() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        layout.slotARightColumn = ["A", "B", "C"]
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[0][6], .symbol("A"))
        XCTAssertEqual(grid[1][6], .symbol("B"))
        XCTAssertEqual(grid[2][6], .symbol("C"))
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testA2_defaultRightColumnIsBangQuestionDot() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[0][6], .symbol("!"))
        XCTAssertEqual(grid[1][6], .symbol("?"))
        XCTAssertEqual(grid[2][6], .symbol("."))
    }
}

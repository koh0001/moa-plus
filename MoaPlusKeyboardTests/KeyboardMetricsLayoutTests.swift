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

    func testKeyWidth_backspaceWideIsTwoCellsPlusGap() {
        let centerWidth: CGFloat = 40.0
        let normal = KeyboardMetrics.keyWidth(for: 5, row: 3, centerKeyWidth: centerWidth, mode: .korean)
        let wide = KeyboardMetrics.keyWidth(forBackspaceWideAt: 5, centerKeyWidth: centerWidth)
        XCTAssertEqual(wide, normal * 2 + KeyboardMetrics.keySpacing, accuracy: 0.01)
    }
}

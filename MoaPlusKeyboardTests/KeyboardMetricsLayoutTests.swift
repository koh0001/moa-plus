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
}

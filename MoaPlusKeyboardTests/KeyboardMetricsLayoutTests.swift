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
        // Row 0 col 6 reuses slotARightColumn[0] (shared with classic11),
        // no longer a fixed "#" — see commit f48eac1 / CHANGELOG v1.5.
        XCTAssertEqual(grid[0][6], .symbol(layout.slotARightColumn[0]))
        XCTAssertEqual(grid[1][6], .slotBVowelKey)
        XCTAssertEqual(grid[2][6], .slotBPunctuation)
        XCTAssertEqual(grid[3].count, 6)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testA3Layout_col6Row0ReflectsCustomSlotARightColumn() {
        var layout = LayoutCustomization()
        layout.slotA = .fullPackage
        layout.slotARightColumn = ["@", "?", "."]
        let grid = KeyboardMetrics.koreanLayout(layout)
        XCTAssertEqual(grid[0][6], .symbol("@"),
                       "user edits to slotARightColumn[0] must show in A3 col6 row0")
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

    // MARK: - Symbol layout follows Korean backspace position

    func testSymbolLayout_A1NoSwap_BackspaceAtRow1Col6() {
        let layout = LayoutCustomization()  // A1, no swap
        let grid = KeyboardMetrics.symbolLayout(layout)
        XCTAssertEqual(grid[1][6], .backspace)
        XCTAssertNotEqual(grid[3][6], .backspace)
    }

    func testSymbolLayout_A1WithSwap_BackspaceAtRow3Col6() {
        var layout = LayoutCustomization()
        layout.slotABackspaceSwap = true
        let grid = KeyboardMetrics.symbolLayout(layout)
        XCTAssertEqual(grid[3][6], .backspace)
        XCTAssertNotEqual(grid[1][6], .backspace)
    }

    func testSymbolLayout_A2_WideBackspaceAtRow3() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        let grid = KeyboardMetrics.symbolLayout(layout)
        XCTAssertEqual(grid[3].count, 6)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testSymbolLayout_A3_WideBackspaceAtRow3() {
        var layout = LayoutCustomization()
        layout.slotA = .fullPackage
        let grid = KeyboardMetrics.symbolLayout(layout)
        XCTAssertEqual(grid[3].count, 6)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    func testActiveLayout_SymbolModeUsesLayoutCustomization() {
        var layout = LayoutCustomization()
        layout.slotA = .classic11
        let grid = KeyboardMetrics.activeLayout(for: .symbolFromKorean, layout: layout)
        XCTAssertEqual(grid[3].count, 6)
        XCTAssertEqual(grid[3][5], .backspaceWide)
    }

    // MARK: - English row 3 shift/backspace widths

    func testEnglishKeyWidth_shiftAndBackspaceAreWiderOnRow3() {
        let center: CGFloat = 40.0
        let shiftWidth = KeyboardMetrics.keyWidth(for: 0, row: 3, centerKeyWidth: center, mode: .english)
        let bkspWidth = KeyboardMetrics.keyWidth(for: 8, row: 3, centerKeyWidth: center, mode: .english)
        let letterWidth = KeyboardMetrics.keyWidth(for: 4, row: 3, centerKeyWidth: center, mode: .english)
        XCTAssertGreaterThan(shiftWidth, letterWidth)
        XCTAssertGreaterThan(bkspWidth, letterWidth)
        XCTAssertEqual(shiftWidth, center * 1.5, accuracy: 0.01)
        XCTAssertEqual(bkspWidth, center * 1.5, accuracy: 0.01)
    }

    func testEnglishKeyWidth_otherRowsUnchanged() {
        let center: CGFloat = 40.0
        // Row 0-2 letter keys are still uniform width.
        XCTAssertEqual(KeyboardMetrics.keyWidth(for: 0, row: 0, centerKeyWidth: center, mode: .english), center, accuracy: 0.01)
        XCTAssertEqual(KeyboardMetrics.keyWidth(for: 9, row: 1, centerKeyWidth: center, mode: .english), center, accuracy: 0.01)
        XCTAssertEqual(KeyboardMetrics.keyWidth(for: 4, row: 2, centerKeyWidth: center, mode: .english), center, accuracy: 0.01)
        // Row 3 inner letters are still 1×.
        XCTAssertEqual(KeyboardMetrics.keyWidth(for: 1, row: 3, centerKeyWidth: center, mode: .english), center, accuracy: 0.01)
        XCTAssertEqual(KeyboardMetrics.keyWidth(for: 7, row: 3, centerKeyWidth: center, mode: .english), center, accuracy: 0.01)
    }

    // MARK: - iPad dynamic height (T6)

    func testKeyboardHeight_iPhoneAlways260() {
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: false, isLandscape: false, screenShort: 390, screenLong: 844), 260, accuracy: 0.01)
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: false, isLandscape: true, screenShort: 390, screenLong: 844), 260, accuracy: 0.01)
    }

    func testKeyboardHeight_iPadPortraitMini_isLongTimes030() {
        // mini6 744×1133 portrait: 1133*0.30 = 339.9 (clamp 안 걸림)
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: true, isLandscape: false, screenShort: 744, screenLong: 1133), 1133 * 0.30, accuracy: 0.01)
    }

    func testKeyboardHeight_iPadLandscapeMini_isShortTimes044() {
        // mini6 landscape: 744*0.44 = 327.36 (clamp 안 걸림)
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: true, isLandscape: true, screenShort: 744, screenLong: 1133), 744 * 0.44, accuracy: 0.01)
    }

    func testKeyboardHeight_iPad13Portrait_clampedToMax400() {
        // 13" 1024×1366 portrait: 1366*0.30 = 409.8 → clamp 400
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: true, isLandscape: false, screenShort: 1024, screenLong: 1366), 400, accuracy: 0.01)
    }

    func testKeyboardHeight_iPad13Landscape_clampedToMax420() {
        // 13" landscape: 1024*0.44 = 450.56 → clamp 420
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: true, isLandscape: true, screenShort: 1024, screenLong: 1366), 420, accuracy: 0.01)
    }

    func testKeyboardHeight_iPadLandscapeLowerClamp320() {
        // 가상 소형: short 600 → 600*0.44 = 264 → clamp 하한 320
        XCTAssertEqual(KeyboardMetrics.keyboardHeight(isPad: true, isLandscape: true, screenShort: 600, screenLong: 900), 320, accuracy: 0.01)
    }

    // MARK: - iPad split decision (T6)

    func testIsLandscapeKeyboard_widthIsLongEdge_true() {
        // 키보드 폭 = 장축(1133) → 가로
        XCTAssertTrue(KeyboardMetrics.isLandscapeKeyboard(keyboardWidth: 1133, screenShort: 744, screenLong: 1133))
    }

    func testIsLandscapeKeyboard_widthIsShortEdge_false() {
        // 키보드 폭 = 단축(744) → 세로
        XCTAssertFalse(KeyboardMetrics.isLandscapeKeyboard(keyboardWidth: 744, screenShort: 744, screenLong: 1133))
    }

    func testUsesIPadSplit_onlyPadAndLandscape() {
        XCTAssertTrue(KeyboardMetrics.usesIPadSplit(isPad: true, isLandscape: true))
        XCTAssertFalse(KeyboardMetrics.usesIPadSplit(isPad: true, isLandscape: false))
        XCTAssertFalse(KeyboardMetrics.usesIPadSplit(isPad: false, isLandscape: true))
        XCTAssertFalse(KeyboardMetrics.usesIPadSplit(isPad: false, isLandscape: false))
    }
}

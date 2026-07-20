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

    // MARK: - Symbol pages

    /// Page 0 must expose the common punctuation the feedback asked for
    /// (마침표/쉼표/따옴표) while keeping the digit cluster.
    func testSymbolPage0_containsCommonPunctuationAndDigits() {
        let grid = KeyboardMetrics.symbolLayout(LayoutCustomization(), page: 0)
        let flat = grid.flatMap { $0 }
        for ch in [".", ",", "'", "\""] {
            XCTAssertTrue(flat.contains(.symbol(ch)), "page 0 must contain \(ch)")
        }
        for digit in ["0", "5", "9"] {
            XCTAssertTrue(flat.contains(.symbol(digit)), "page 0 must keep digit \(digit)")
        }
    }

    /// Default `symbolLayout(_:)` (no page arg) resolves to page 0.
    func testSymbolLayout_defaultsToPage0() {
        let implicit = KeyboardMetrics.symbolLayout(LayoutCustomization())
        let explicit = KeyboardMetrics.symbolLayout(LayoutCustomization(), page: 0)
        XCTAssertEqual(implicit, explicit)
    }

    /// Page 1 drops the digits and offers a different symbol set.
    func testSymbolPage1_hasNoDigitsAndDiffersFromPage0() {
        let page0 = KeyboardMetrics.symbolLayout(LayoutCustomization(), page: 0)
        let page1 = KeyboardMetrics.symbolLayout(LayoutCustomization(), page: 1)
        XCTAssertNotEqual(page0, page1)
        let flat1 = page1.flatMap { $0 }
        for digit in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] {
            XCTAssertFalse(flat1.contains(.symbol(digit)), "page 1 must not contain digit \(digit)")
        }
        // Bracket / currency symbols only reachable on page 1.
        for ch in ["[", "]", "{", "}", "₩"] {
            XCTAssertTrue(flat1.contains(.symbol(ch)), "page 1 must contain \(ch)")
        }
    }

    /// Essential characters must stay reachable across the two pages for
    /// *every* slotA preset — not just the default .vowel layout. Guards the
    /// classic11/fullPackage wide-⌫ branch, whose narrower grid dropped `/`
    /// off both pages in an earlier revision (regression from the pre-page
    /// keypad). Digits + the feedback-requested punctuation must all survive.
    func testSymbolPages_essentialCharsReachableForEveryPreset() {
        let essential = [".", ",", "'", "\"", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        for preset in [SlotAPreset.vowel, .classic11, .fullPackage] {
            var layout = LayoutCustomization()
            layout.slotA = preset
            let union = Set(
                (KeyboardMetrics.symbolLayout(layout, page: 0)
                    + KeyboardMetrics.symbolLayout(layout, page: 1))
                    .flatMap { $0 }
                    .compactMap { cell -> String? in
                        if case .symbol(let s) = cell { return s } else { return nil }
                    }
            )
            for ch in essential {
                XCTAssertTrue(union.contains(ch), "\(preset): symbol keypad must expose \(ch) on some page")
            }
        }
    }

    /// Both pages must share the exact same geometry (⌫ position / column
    /// counts) so only the printed characters change when flipping pages.
    func testSymbolPages_shareGeometryAcrossSlotA() {
        for preset in [SlotAPreset.vowel, .classic11, .fullPackage] {
            var layout = LayoutCustomization()
            layout.slotA = preset
            let p0 = KeyboardMetrics.symbolLayout(layout, page: 0)
            let p1 = KeyboardMetrics.symbolLayout(layout, page: 1)
            XCTAssertEqual(p0.count, p1.count, "\(preset): row count differs")
            for row in 0..<p0.count {
                XCTAssertEqual(p0[row].count, p1[row].count, "\(preset) row \(row): column count differs")
                for col in 0..<p0[row].count {
                    // Non-symbol control cells (⌫, wide ⌫) must sit at identical positions.
                    let a = p0[row][col], b = p1[row][col]
                    let aIsSymbol = { if case .symbol = a { return true } else { return false } }()
                    let bIsSymbol = { if case .symbol = b { return true } else { return false } }()
                    XCTAssertEqual(aIsSymbol, bIsSymbol,
                                   "\(preset) [\(row)][\(col)]: symbol/control kind must match across pages")
                    if !aIsSymbol {
                        XCTAssertEqual(a, b, "\(preset) [\(row)][\(col)]: control cell must be identical")
                    }
                }
            }
        }
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

    func testUsesIPadSplit_portraitFollowsToggle() {
        // 가로는 토글과 무관하게 항상 분리.
        XCTAssertTrue(KeyboardMetrics.usesIPadSplit(isPad: true, isLandscape: true, portraitSplitEnabled: false))
        XCTAssertTrue(KeyboardMetrics.usesIPadSplit(isPad: true, isLandscape: true, portraitSplitEnabled: true))
        // 세로는 토글에 따른다.
        XCTAssertFalse(KeyboardMetrics.usesIPadSplit(isPad: true, isLandscape: false, portraitSplitEnabled: false),
                       "세로 + 토글 off → 단일")
        XCTAssertTrue(KeyboardMetrics.usesIPadSplit(isPad: true, isLandscape: false, portraitSplitEnabled: true),
                      "세로 + 토글 on → 분리")
        // 아이폰은 토글과 무관하게 분리하지 않는다.
        XCTAssertFalse(KeyboardMetrics.usesIPadSplit(isPad: false, isLandscape: false, portraitSplitEnabled: true))
        XCTAssertFalse(KeyboardMetrics.usesIPadSplit(isPad: false, isLandscape: true, portraitSplitEnabled: true))
    }

    // MARK: - number pad model (T6)

    func testNumberPadKeys_shape() {
        XCTAssertEqual(KeyboardMetrics.numberPadKeys.count, 4)
        for row in KeyboardMetrics.numberPadKeys { XCTAssertEqual(row.count, 3) }
    }

    func testNumberPadKeys_contents() {
        XCTAssertEqual(KeyboardMetrics.numberPadKeys[0], ["1", "2", "3"])
        XCTAssertEqual(KeyboardMetrics.numberPadKeys[3], [".", "0", KeyboardMetrics.numberPadBackspaceLabel])
    }
}

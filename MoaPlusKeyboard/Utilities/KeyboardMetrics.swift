import Foundation
import CoreGraphics

/// Content type for each key in the keyboard grid
enum KeyContent: Equatable {
    case consonant(Choseong)
    case symbol(String)
    case backspace
    case backspaceWide       // A2 의 row 3 가로 2칸 ⌫
    case slotBVowelKey       // A3 col 6 row 1 — function-row vowel key 와 동일 동작
    case slotBPunctuation    // A3 col 6 row 2 — function-row 특수문자 swipe 와 동일 동작
    // Moakey bimanual layout key types
    case vowelPrimitive(VowelPrimitiveType)  // ㆍ, ㅣ, ㅡ
    case functional(FunctionalKeyType)        // Mode switch, settings, etc.
    case systemSwitch                         // Globe key (system keyboard switch)
    case quickPunctuation(String)             // Period, comma, etc.
}

enum VowelPrimitiveType: String {
    case dot = "ㆍ"    // Middle dot (아래아)
    case bar = "ㅣ"    // Vertical bar
    case dash = "ㅡ"   // Horizontal dash

    var displayLabel: String { rawValue }
}

enum FunctionalKeyType: String {
    case modeToggle     // Korean ↔ Symbol toggle
    case specialChar    // Special character layer entry
    case settings       // Settings shortcut
    case space          // Space bar
    case returnKey      // Return/Enter
    case languageSwitch // Language switch (short tap = special char, long = system switch)
    case shift          // Shift / caps-lock for English mode
}

enum KeyboardMetrics {
    // Grid layout
    static let gridColumns = 7  // Expanded from 5 to 7
    static let gridRows = 4

    // Key sizing
    static let keySpacing: CGFloat = 4

    /// 약어 후보 바 높이. `AbbreviationCandidateView` 의 `.frame(height:)` 와
    /// `KeyboardViewController` 의 높이 보정이 **같은 값**을 봐야 한다 — 따로 두면
    /// 후보 바가 뜰 때 그 차이만큼 키보드 아래가 잘린다.
    static let abbreviationCandidateBarHeight: CGFloat = 36

    /// 후보 바가 떠 있을 때 키보드 컨테이너에 더해야 할 높이 (바 + VStack 간격).
    static var abbreviationCandidateBarFootprint: CGFloat {
        abbreviationCandidateBarHeight + keySpacing
    }
    static let keyCornerRadius: CGFloat = 8

    // Width ratio for side symbol keys (relative to center keys)
    // Reads from settings; falls back to 0.35 default
    static var symbolWidthRatio: CGFloat {
        CGFloat(KeyboardSettings.shared.sideKeyWidthRatio)
    }

    // Width ratio for action keys (backspace/return) relative to total width
    static let actionKeyWidthRatio: CGFloat = 0.20

    // Function row
    static let functionRowHeight: CGFloat = 44

    // Keyboard height
    static let keyboardHeight: CGFloat = 260

    // MARK: - iPad dynamic height (T6)
    // 런타임 UIScreen 실측에서 계산 → 모델 하드코딩 없이 모든 아이패드에 정확.
    static let iPadPortraitHeightRatio: CGFloat = 0.30
    static let iPadLandscapeHeightRatio: CGFloat = 0.44
    static let iPadPortraitHeightRange: ClosedRange<CGFloat> = 310...400
    static let iPadLandscapeHeightRange: ClosedRange<CGFloat> = 320...420

    // MARK: - User height scale (v1.9)
    // 앱스토어 리뷰 최다 요청(높이 조절). 기기별 기본 높이 위에 곱해지는 배율.

    static let defaultKeyboardHeightScale: Double = 1.0
    /// 하한 0.85 = 아이폰 221pt → 키 1행 38.25pt. iOS 기본 키보드(약 42pt)보다
    /// 낮지만 사용자가 명시적으로 선택한 경우에만 도달한다. 이보다 더 낮추면
    /// 오타율이 급증해 리뷰의 원 요청("작게")과 반대 결과가 나오므로 여기서 막는다.
    static let keyboardHeightScaleRange: ClosedRange<Double> = 0.85...1.35

    /// NaN 은 `min`/`max` 비교를 모두 통과해 그대로 전파되고, 그러면 높이
    /// 제약 constant 가 NaN 이 되어 레이아웃이 통째로 깨진다. 저장값이 손상된
    /// 경우에도 안전하도록 비교 전에 먼저 걸러낸다.
    static func clampedHeightScale(_ scale: Double) -> CGFloat {
        guard scale.isFinite else { return CGFloat(keyboardHeightScaleRange.lowerBound) }
        return CGFloat(min(max(scale, keyboardHeightScaleRange.lowerBound),
                           keyboardHeightScaleRange.upperBound))
    }

    // MARK: - 하단 여백 (홈 인디케이터 회피)
    // 물리 홈 버튼이 없는 아이폰에서 스페이스바가 화면 맨 아래 홈 제스처 구역에
    // 붙어, 스페이스를 누르다 홈 화면으로 튕기는 제보. 키보드 콘텐츠를 그만큼
    // 위로 올리되 **컨테이너 높이도 같이 키워** 키 크기는 그대로 유지한다.

    /// 홈 인디케이터 아이폰의 하단 안전영역 폴백값(세로 / 가로).
    /// 런타임 `view.safeAreaInsets.bottom` 을 읽지 못했을 때만 쓴다.
    static let homeIndicatorBottomInset: CGFloat = 34
    static let homeIndicatorBottomInsetLandscape: CGFloat = 21
    /// 홈 인디케이터 아이패드는 세로/가로 모두 21pt 남짓.
    static let iPadHomeIndicatorBottomInset: CGFloat = 20

    /// 자동 여백 **위에** 사용자가 더 얹는 추가 여백 범위.
    ///
    /// 상한을 홈 인디케이터 높이와 같은 34pt 로 둔 이유: 자동 여백은 iOS 가
    /// 보고하는 실측 안전영역에만 의존하는데(아래 `estimatedBottomSafeInset`
    /// 주석 참조), 어떤 호스트/기기 조합에서 그 값이 0 으로 오면 자동이 무동작이
    /// 된다. 그때도 사용자가 **수동만으로** 홈 제스처 구역을 전부 비울 수 있어야
    /// 한다 — 이 상한이 그 탈출구다.
    static let extraBottomInsetRange: ClosedRange<Double> = 0...34
    static let defaultExtraBottomInset: Double = 0

    /// NaN 은 `min`/`max` 를 모두 통과해 그대로 전파되고, 그러면 높이 제약
    /// constant 가 NaN 이 되어 레이아웃이 통째로 깨진다. `clampedHeightScale`
    /// 과 같은 이유로 비교 전에 먼저 걸러낸다.
    static func clampedExtraBottomInset(_ value: Double) -> CGFloat {
        guard value.isFinite else { return CGFloat(extraBottomInsetRange.lowerBound) }
        return CGFloat(min(max(value, extraBottomInsetRange.lowerBound),
                           extraBottomInsetRange.upperBound))
    }

    /// 기기 하단 안전영역 **추정값**. 화면 장/단변 비율로 홈 인디케이터 기기를 가른다.
    ///
    /// **키보드 익스텐션에서는 쓰지 않는다.** 익스텐션은 실측
    /// `view.safeAreaInsets.bottom` 만 믿는다 — 그 값이 0 이면 우리 뷰가 애초에
    /// 홈 인디케이터 구역까지 내려가 있지 않다는 뜻이라, 추정치를 더하면 여백이
    /// 이중으로 들어간다. 이 함수는 익스텐션이 없는 **메인 앱**(`DeviceSafeArea`)
    /// 에서 앱 창조차 아직 없을 때의 마지막 폴백 전용이다.
    /// 아이폰은 홈 버튼 모델 ≈1.78 : 홈 인디케이터 모델 ≈2.16 으로 확실히 갈리지만,
    /// 아이패드는 12.9" Pro 가 홈 버튼 모델과 해상도(1024×1366)가 같아 비율로
    /// 구분되지 않는다 — 그래서 아이패드는 명백한 비율만 처리하고 나머지는 0을
    /// 돌려 런타임 값에 맡긴다.
    static func estimatedBottomSafeInset(isPad: Bool, isLandscape: Bool,
                                         screenShort: CGFloat, screenLong: CGFloat) -> CGFloat {
        guard screenShort > 0, screenLong > 0, screenShort.isFinite, screenLong.isFinite else { return 0 }
        let ratio = screenLong / screenShort
        if isPad {
            return ratio > 1.40 ? iPadHomeIndicatorBottomInset : 0
        }
        guard ratio > 2.0 else { return 0 }   // 홈 버튼 아이폰
        return isLandscape ? homeIndicatorBottomInsetLandscape : homeIndicatorBottomInset
    }

    /// 실제 적용할 하단 여백 = (자동 ON ? 기기 안전영역 : 0) + 추가 여백.
    /// `deviceInset` 은 런타임 실측값이 있으면 그것, 없으면
    /// `estimatedBottomSafeInset(...)` 을 넘긴다.
    static func resolvedBottomInset(autoEnabled: Bool, deviceInset: CGFloat, extra: Double) -> CGFloat {
        let auto = autoEnabled && deviceInset.isFinite ? max(0, deviceInset) : 0
        return auto + clampedExtraBottomInset(extra)
    }

    /// 키보드 컨테이너 높이. 아이폰은 260, 아이패드는 화면 실측 기반이며,
    /// 둘 다 사용자 배율(`scale`)이 마지막에 곱해진다.
    /// `screenShort`/`screenLong` = `UIScreen.main.bounds` 의 min/max (방향 불변).
    /// `scale` 기본값 1.0 은 배율 도입 이전 호출부(및 기존 테스트)와 동일 동작.
    static func keyboardHeight(isPad: Bool, isLandscape: Bool,
                               screenShort: CGFloat, screenLong: CGFloat,
                               scale: Double = defaultKeyboardHeightScale) -> CGFloat {
        base(isPad: isPad, isLandscape: isLandscape,
             screenShort: screenShort, screenLong: screenLong) * clampedHeightScale(scale)
    }

    /// 배율 적용 전 기기별 기본 높이. 클램프는 기본 높이에만 적용되고 배율은
    /// 그 뒤에 곱해지므로, 아이패드에서도 사용자가 범위 밖으로 키울 수 있다.
    private static func base(isPad: Bool, isLandscape: Bool,
                             screenShort: CGFloat, screenLong: CGFloat) -> CGFloat {
        guard isPad else { return keyboardHeight }   // iPhone: 260
        if isLandscape {
            let raw = screenShort * iPadLandscapeHeightRatio
            return min(max(raw, iPadLandscapeHeightRange.lowerBound), iPadLandscapeHeightRange.upperBound)
        } else {
            let raw = screenLong * iPadPortraitHeightRatio
            return min(max(raw, iPadPortraitHeightRange.lowerBound), iPadPortraitHeightRange.upperBound)
        }
    }

    /// 키보드는 항상 화면 폭을 꽉 채우므로, 키보드 폭이 기기 장축이면 가로.
    /// (단축+장축 중점을 임계로 둬서 인셋/안전영역 오차에 강건.)
    static func isLandscapeKeyboard(keyboardWidth: CGFloat,
                                    screenShort: CGFloat, screenLong: CGFloat) -> Bool {
        keyboardWidth > (screenShort + screenLong) / 2
    }

    /// 좌우 분리 레이아웃 사용 여부. 아이패드 가로는 항상 분리, 세로는 사용자
    /// 토글(`LayoutCustomization.iPadPortraitSplitEnabled`)에 따른다. 아이폰은
    /// 항상 false. 기본 인자(false)는 기존 가로 전용 호출과 호환된다.
    static func usesIPadSplit(isPad: Bool, isLandscape: Bool,
                              portraitSplitEnabled: Bool = false) -> Bool {
        isPad && (isLandscape || portraitSplitEnabled)
    }

    /// 아이패드 분리 레이아웃 좌(또는 우) 숫자패드. 계산기식 3×4.
    static let numberPadBackspaceLabel = "⌫"
    static let numberPadKeys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", numberPadBackspaceLabel]
    ]

    // Audio
    static let clickSoundID: UInt32 = 1104

    // Backspace timing
    static let wordDeleteRepeatInterval: TimeInterval = 0.12

    // Gesture thresholds
    static let gestureThreshold: CGFloat = 20        // Minimum distance to register direction
    static let reversalThreshold: CGFloat = 10       // Lower threshold for opposite direction reversals
    static let directionChangeThreshold: CGFloat = 15 // Distance before direction can change
    static let gestureTimeout: TimeInterval = 0.5    // Max time between direction changes

    // Calculate action key width (backspace/return) based on total width
    static func actionKeyWidth(for totalWidth: CGFloat) -> CGFloat {
        return totalWidth * actionKeyWidthRatio
    }

    // Calculate center key width based on available space
    // Row 0-2: side*2 + center*5 = 0.35*2 + 5 = 5.7 units
    static func centerKeyWidth(for totalWidth: CGFloat, columnCount: Int = 7, mode: KeyboardMode = .korean) -> CGFloat {
        let spacing = keySpacing * CGFloat(columnCount + 1)
        let availableWidth = totalWidth - spacing
        if columnCount == 10 {
            // English mode: 10 equal-width keys, no narrow side keys.
            return availableWidth / 10
        }
        // Korean + Symbol modes: col 0 AND col 6 widened to 1.3x sideRatio (좌우 대칭 정렬).
        // Total row = 1.3*sideRatio*c + 5*c + 1.3*sideRatio*c = c * (sideRatio*2.6 + 5)
        return availableWidth / (symbolWidthRatio * 2.6 + 5)
    }

    // Calculate key height based on available space
    static func keyHeight(for totalHeight: CGFloat) -> CGFloat {
        let availableHeight = totalHeight - functionRowHeight - keySpacing * CGFloat(gridRows + 2)
        return availableHeight / CGFloat(gridRows)
    }

    // Get key width for specific column and row (legacy: assumes 7-col Korean/symbol grid)
    static func keyWidth(for column: Int, row: Int, centerKeyWidth: CGFloat) -> CGFloat {
        let sideWidth = centerKeyWidth * symbolWidthRatio
        // Side columns (col 0 and col 6) are narrow
        if column == 0 || column == 6 {
            return sideWidth
        }
        return centerKeyWidth
    }

    /// Mode-aware key width. English layout uses uniform widths, except row 3
    /// (shift + zxcvbnm + backspace) where shift and backspace are widened
    /// 1.5x so the row edges align with rows 0-1 (10 keys), matching iOS QWERTY.
    static func keyWidth(for column: Int, row: Int, centerKeyWidth: CGFloat, mode: KeyboardMode) -> CGFloat {
        switch mode {
        case .english:
            // Row 3 = shift, z, x, c, v, b, n, m, backspace (9 cells).
            // Make shift (col 0) and backspace (col 8) 1.5x wider so the row
            // visually fills the keyboard like iOS standard QWERTY.
            if row == 3 && (column == 0 || column == 8) {
                return centerKeyWidth * 1.5
            }
            return centerKeyWidth
        case .korean, .symbolFromKorean, .symbolFromEnglish:
            let sideWidth = centerKeyWidth * symbolWidthRatio
            // Korean + Symbol modes: BOTH side columns (0 + 6) widened to 1.3x sideWidth.
            // 좌우 대칭으로 시각적 마진 균형 유지 (PR G7 + 좌우 균형 fix)
            if column == 0 || column == 6 {
                return sideWidth * 1.3
            }
            return keyWidth(for: column, row: row, centerKeyWidth: centerKeyWidth)
        }
    }

    /// `backspaceWide` 의 폭 = 일반 자음 1칸 + 우측 사이드 키(1.3·sideRatio) + spacing.
    /// 인접 셀 (col 5) 만 사용하며 col 6 은 `[3].count == 6` 으로 그리드에 존재 안 함.
    /// 위쪽 row (col 5 + spacing + col 6) 와 같은 폭으로 정렬되도록 한다.
    static func keyWidth(forBackspaceWideAt column: Int, centerKeyWidth: CGFloat) -> CGFloat {
        let sideWidth = centerKeyWidth * symbolWidthRatio * 1.3
        return centerKeyWidth + sideWidth + keySpacing
    }

    // Get number of columns for a row in the active layout.
    static func columnCount(for row: Int, isSymbolMode: Bool) -> Int {
        let layout = isSymbolMode ? symbolLayout : koreanLayout
        guard row >= 0 && row < layout.count else { return 0 }
        return layout[row].count
    }

    /// Mode-aware column count.
    static func columnCount(for row: Int, mode: KeyboardMode) -> Int {
        let layout = activeLayout(for: mode)
        guard row >= 0 && row < layout.count else { return 0 }
        return layout[row].count
    }

    /// Returns the layout array (rows × columns) for the given mode.
    static func activeLayout(for mode: KeyboardMode) -> [[KeyContent]] {
        switch mode {
        case .korean: return koreanLayout
        case .english: return englishLayout
        case .symbolFromKorean, .symbolFromEnglish: return symbolLayout
        }
    }

    /// Layout-aware overload. Uses the user's LayoutCustomization for Korean
    /// and Symbol modes (so the symbol keypad's backspace position mirrors
    /// the Korean layout). English mode is unaffected.
    static func activeLayout(for mode: KeyboardMode, layout: LayoutCustomization) -> [[KeyContent]] {
        activeLayout(for: mode, layout: layout, symbolPage: 0)
    }

    /// Page-aware overload. `symbolPage` only affects symbol modes; letter
    /// modes ignore it. Callers that render or resolve symbol taps must thread
    /// the active `KeyboardViewModel.symbolPage` through here so page 1 keys
    /// aren't resolved against the page 0 grid.
    static func activeLayout(for mode: KeyboardMode, layout: LayoutCustomization, symbolPage: Int) -> [[KeyContent]] {
        switch mode {
        case .korean: return koreanLayout(layout)
        case .english: return englishLayout
        case .symbolFromKorean, .symbolFromEnglish: return symbolLayout(layout, page: symbolPage)
        }
    }

    // Calculate key size based on available width (legacy method for compatibility)
    static func keySize(for totalWidth: CGFloat, totalHeight: CGFloat) -> CGSize {
        let keyWidth = centerKeyWidth(for: totalWidth)
        let keyHeightValue = keyHeight(for: totalHeight)
        return CGSize(width: keyWidth, height: keyHeightValue)
    }

    /// Returns the Korean grid layout for the given LayoutCustomization.
    /// A1 (vowel preset): reproduces v1.3 layout with col 0 from slotC and optional ㆍ↔⌫ swap.
    /// A2 (classic11 preset): placeholder — implemented in Task 4.
    static func koreanLayout(_ layout: LayoutCustomization) -> [[KeyContent]] {
        let leftCol = layout.slotC.map { KeyContent.symbol($0) }
        switch layout.slotA {
        case .vowel:
            let row1Right: KeyContent = layout.slotABackspaceSwap ? .vowelPrimitive(.dot) : .backspace
            let row3Right: KeyContent = layout.slotABackspaceSwap ? .backspace : .vowelPrimitive(.dot)
            return [
                [leftCol[0], .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol("#")],
                [leftCol[1], .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), row1Right],
                [leftCol[2], .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .vowelPrimitive(.bar)],
                [leftCol[3], .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .vowelPrimitive(.dash), row3Right],
            ]
        case .classic11:
            let rightCol = layout.slotARightColumn
            return [
                [leftCol[0], .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol(rightCol[0])],
                [leftCol[1], .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .symbol(rightCol[1])],
                [leftCol[2], .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .symbol(rightCol[2])],
                [leftCol[3], .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspaceWide],
            ]
        case .fullPackage:
            // Classic 베이스 + col 6 에 슬롯 B 임베디드 (모음/특수문자) + wide ⌫.
            // Function row 의 슬롯 B 키는 비활성, 그 폭만큼 스페이스 확장.
            // Row 0 col 6 은 slotARightColumn[0] 을 재사용 (classic11 과 공유).
            let topRight = layout.slotARightColumn.first ?? LayoutCustomization.defaultSlotARightColumn[0]
            return [
                [leftCol[0], .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol(topRight)],
                [leftCol[1], .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .slotBVowelKey],
                [leftCol[2], .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .slotBPunctuation],
                [leftCol[3], .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspaceWide],
            ]
        }
    }

    // Korean mode layout (7 columns × 4 rows, all rows uniform width)
    // Left column: special symbols, Center: consonants, Right column: backspace/vowel primitives
    static let koreanLayout: [[KeyContent]] = [
        [.symbol("~"), .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol("#")],
        [.symbol("^"), .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .backspace],
        [.symbol(";"), .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .vowelPrimitive(.bar)],
        [.symbol("*"), .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .vowelPrimitive(.dash), .vowelPrimitive(.dot)],
    ]

    /// Number of symbol pages. Page 0 = 숫자 + 상용 문장부호(. , ' " 등),
    /// page 1 = 나머지 기호(괄호/수학/통화 등). 전환은 function row 의
    /// 페이지 토글 키(#+= / 123)로 이뤄지며 KeyboardViewModel.symbolPage 가 상태.
    static let symbolPageCount = 2

    // Symbol mode layout (legacy, layout-agnostic).
    // Backspace at row 1 col 6 — kept for older callers that pre-date
    // LayoutCustomization. Mode-aware call sites should use
    // `symbolLayout(_:page:)` so the symbol keypad's backspace position
    // mirrors the user's Korean layout choice. Content mirrors page 0.
    static let symbolLayout: [[KeyContent]] = [
        [.symbol("."), .symbol("!"), .symbol("1"), .symbol("2"), .symbol("3"), .symbol("&"), .symbol("%")],
        [.symbol(","), .symbol("?"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("+"), .backspace],
        [.symbol("'"), .symbol("@"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol(":"), .symbol(")")],
        [.symbol("\""), .symbol("-"), .symbol("*"), .symbol("0"), .symbol("#"), .symbol("/"), .symbol("(")],
    ]

    /// Layout-aware symbol grid for the given page. The symbol keypad's
    /// backspace position follows the user's Korean layout so muscle memory
    /// transfers between modes:
    /// - A1 (.vowel, no swap): wide-cell ⌫ at row 1 col 6.
    /// - A1 (.vowel, swap on): wide-cell ⌫ at row 3 col 6.
    /// - A2 (.classic11) / A3 (.fullPackage): wide ⌫ spanning row 3 col 5+6.
    ///
    /// Page geometry (열 수 / ⌫ 위치 / wide-⌫ 스켈레톤) is identical across
    /// pages — only the symbol *content* differs. Page 0 keeps the digit
    /// cluster (center 3 cols); page 1 drops digits for more symbols.
    static func symbolLayout(_ layout: LayoutCustomization, page: Int = 0) -> [[KeyContent]] {
        page == 0 ? symbolPage0(layout) : symbolPage1(layout)
    }

    /// Page 0 — 숫자 + 상용 문장부호. 왼쪽 열에 . , ' " 를 배치해
    /// 접근성을 높이고, 마침표 키가 생기면서 더블스페이스 우회가 불필요해진다.
    private static func symbolPage0(_ layout: LayoutCustomization) -> [[KeyContent]] {
        switch layout.slotA {
        case .vowel:
            let row1Right: KeyContent = layout.slotABackspaceSwap ? .symbol("(") : .backspace
            let row3Right: KeyContent = layout.slotABackspaceSwap ? .backspace : .symbol("(")
            return [
                [.symbol("."), .symbol("!"), .symbol("1"), .symbol("2"), .symbol("3"), .symbol("&"), .symbol("%")],
                [.symbol(","), .symbol("?"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("+"), row1Right],
                [.symbol("'"), .symbol("@"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol(":"), .symbol(")")],
                [.symbol("\""), .symbol("-"), .symbol("*"), .symbol("0"), .symbol("#"), .symbol("/"), row3Right],
            ]
        case .classic11, .fullPackage:
            return [
                [.symbol("."), .symbol("!"), .symbol("1"), .symbol("2"), .symbol("3"), .symbol("&"), .symbol("%")],
                [.symbol(","), .symbol("?"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("+"), .symbol("(")],
                [.symbol("'"), .symbol("@"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol(":"), .symbol(")")],
                [.symbol("\""), .symbol("-"), .symbol("*"), .symbol("0"), .symbol("#"), .backspaceWide],
            ]
        }
    }

    /// Page 1 — 괄호/수학/통화/기타 기호. 숫자를 두지 않아 가운데 열까지
    /// 기호로 채워 입력 가능한 문자 종류를 늘린다.
    private static func symbolPage1(_ layout: LayoutCustomization) -> [[KeyContent]] {
        switch layout.slotA {
        case .vowel:
            let row1Right: KeyContent = layout.slotABackspaceSwap ? .symbol("§") : .backspace
            let row3Right: KeyContent = layout.slotABackspaceSwap ? .backspace : .symbol("§")
            return [
                [.symbol("["), .symbol("]"), .symbol("{"), .symbol("}"), .symbol("<"), .symbol(">"), .symbol("^")],
                [.symbol("\\"), .symbol("|"), .symbol("="), .symbol("_"), .symbol("~"), .symbol("`"), row1Right],
                [.symbol("$"), .symbol("€"), .symbol("₩"), .symbol("¥"), .symbol("£"), .symbol("·"), .symbol("•")],
                [.symbol("—"), .symbol("…"), .symbol("©"), .symbol("®"), .symbol("™"), .symbol("°"), row3Right],
            ]
        case .classic11, .fullPackage:
            // Wide ⌫ eats 2 cells/row-3, so this branch holds 2 fewer symbols
            // than .vowel per page. Intended omissions vs .vowel: `` ` `` (backtick,
            // niche) and `°` (degree, new). `/` MUST stay reachable here — it was
            // on the pre-page classic keypad, so dropping it would be a regression;
            // it takes the backtick's slot.
            return [
                [.symbol("["), .symbol("]"), .symbol("{"), .symbol("}"), .symbol("<"), .symbol(">"), .symbol("^")],
                [.symbol("\\"), .symbol("|"), .symbol("="), .symbol("_"), .symbol("~"), .symbol("/"), .symbol("§")],
                [.symbol("$"), .symbol("€"), .symbol("₩"), .symbol("¥"), .symbol("£"), .symbol("·"), .symbol("•")],
                [.symbol("—"), .symbol("…"), .symbol("©"), .symbol("®"), .symbol("™"), .backspaceWide],
            ]
        }
    }

    /// English QWERTY layout (4 rows: numbers + 3 letter rows).
    /// All keys are equal-width; sideKey ratio does not apply.
    /// Row 0: 1 2 3 4 5 6 7 8 9 0 (10 numbers)
    /// Row 1: q w e r t y u i o p (10)
    /// Row 2: a s d f g h j k l (9, centered)
    /// Row 3: shift z x c v b n m backspace (9, all equal-width)
    static let englishLayout: [[KeyContent]] = [
        [.symbol("1"), .symbol("2"), .symbol("3"), .symbol("4"), .symbol("5"), .symbol("6"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol("0")],
        [.symbol("q"), .symbol("w"), .symbol("e"), .symbol("r"), .symbol("t"), .symbol("y"), .symbol("u"), .symbol("i"), .symbol("o"), .symbol("p")],
        [.symbol("a"), .symbol("s"), .symbol("d"), .symbol("f"), .symbol("g"), .symbol("h"), .symbol("j"), .symbol("k"), .symbol("l")],
        [.functional(.shift), .symbol("z"), .symbol("x"), .symbol("c"), .symbol("v"), .symbol("b"), .symbol("n"), .symbol("m"), .backspace],
    ]

    // Long press number mapping for Korean mode
    // Only basic consonants (row 1-2) have number mappings
    // ㅂㅈㄷㄱㅅ → 1 2 3 4 5
    // ㅁㄴㅇㄹㅎ → 6 7 8 9 0
    // Long-press numbers aligned with SecondaryKeyAction.defaults
    // Row 0: ㅃ=1, ㅉ=2, ㄸ=3, ㄲ=4, ㅆ=5
    // Row 1: ㅂ=6, ㅈ=7, ㄷ=8, ㄱ=9, ㅅ=0
    // Row 2: ㅁ=,  ㄴ=.  ㅇ=?  ㄹ=!  ㅎ='
    // Row 3: ㅋ=:  ㅌ=@  ㅊ=₩  ㅍ=…
    static let longPressNumbers: [[String?]] = [
        [nil, "1", "2", "3", "4", "5", nil],   // row 0 (ㅃㅉㄸㄲㅆ)
        [nil, "6", "7", "8", "9", "0", nil],   // row 1 (ㅂㅈㄷㄱㅅ + backspace)
        [nil, ",", ".", "?", "!", "'", nil],   // row 2 (ㅁㄴㅇㄹㅎ + ㅣ)
        [nil, ":", "@", "₩", "…", nil, nil],   // row 3 (ㅋㅌㅊㅍ + ㅡ + ㆍ)
    ]

    // Get key content at grid position for given mode
    static func keyContent(at row: Int, column: Int, isSymbolMode: Bool) -> KeyContent? {
        let layout = isSymbolMode ? symbolLayout : koreanLayout
        guard row >= 0 && row < layout.count,
              column >= 0 && column < layout[row].count else {
            return nil
        }
        return layout[row][column]
    }

    /// Mode-aware key lookup. Preferred over the boolean variant for new call sites.
    static func keyContent(at row: Int, column: Int, mode: KeyboardMode) -> KeyContent? {
        let layout = activeLayout(for: mode)
        guard row >= 0 && row < layout.count,
              column >= 0 && column < layout[row].count else {
            return nil
        }
        return layout[row][column]
    }

    /// Layout-aware key lookup. Mirrors the rendering path (`ConsonantGridView`)
    /// so input handlers resolve the same key content the user sees — required
    /// for slotC / slotARightColumn customizations to actually take effect.
    static func keyContent(at row: Int, column: Int, mode: KeyboardMode, layout: LayoutCustomization) -> KeyContent? {
        keyContent(at: row, column: column, mode: mode, layout: layout, symbolPage: 0)
    }

    /// Page-aware key lookup. Symbol-mode tap/long-press handlers must pass the
    /// active `symbolPage` so a tap on page 1 resolves the page 1 symbol rather
    /// than the page 0 grid at the same (row, column).
    static func keyContent(at row: Int, column: Int, mode: KeyboardMode, layout: LayoutCustomization, symbolPage: Int) -> KeyContent? {
        let grid = activeLayout(for: mode, layout: layout, symbolPage: symbolPage)
        guard row >= 0 && row < grid.count,
              column >= 0 && column < grid[row].count else {
            return nil
        }
        return grid[row][column]
    }

    // Get consonant at grid position (for Korean mode only)
    static func consonant(at row: Int, column: Int) -> Choseong? {
        guard let content = keyContent(at: row, column: column, isSymbolMode: false) else {
            return nil
        }
        if case .consonant(let choseong) = content {
            return choseong
        }
        return nil
    }

    // Get long press number for position
    static func longPressNumber(at row: Int, column: Int) -> String? {
        guard row >= 0 && row < longPressNumbers.count,
              column >= 0 && column < longPressNumbers[row].count else {
            return nil
        }
        return longPressNumbers[row][column]
    }

    /// Alternate characters surfaced via long-press in symbol mode. Curated
    /// for actual Korean keyboard use — rarely used Latin punctuation
    /// (`¡ ¿ ‰ §` etc.) is omitted. Order matters — the first item is
    /// inserted if the user releases without dragging.
    static let symbolModeAlternates: [String: [String]] = [
        "$": ["₩", "€", "£", "¥"],
        "*": ["※", "★", "☆"],
        "(": ["[", "{", "<"],
        ")": ["]", "}", ">"],
        "-": ["–", "—", "•"],
        "/": ["\\"],
        ":": [";"],
    ]

    /// Build a transient SecondaryKeyAction for a symbol-mode key so the
    /// existing long-press popup pipeline (KeyView + KeyboardViewModel)
    /// renders alt characters without needing per-key storage in
    /// `KeyboardSettings.secondaryKeyActions`.
    static func symbolModeSecondaryAction(for symbol: String) -> SecondaryKeyAction? {
        guard let alts = symbolModeAlternates[symbol], let first = alts.first else { return nil }
        return SecondaryKeyAction(
            keyId: symbol,
            visibleHint: first,
            primaryLongPressOutput: first,
            popupOutputs: alts
        )
    }

    /// Layout-aware long-press number lookup.
    /// A2 (classic11) places punctuation and a wide backspace in col 6,
    /// so the digit hint table does not apply there — returns nil for col 6.
    /// All other columns delegate to the layout-agnostic overload.
    static func longPressNumber(at row: Int, column: Int, layout: LayoutCustomization) -> String? {
        if column == 6 {
            switch layout.slotA {
            case .vowel:       return longPressNumber(at: row, column: column)
            case .classic11:   return nil
            case .fullPackage: return nil
            }
        }
        return longPressNumber(at: row, column: column)
    }

    // MARK: - Bimanual Layout

    /// Bimanual layout metrics
    static let bimanualColumnCount = 5
    static let bimanualRowCount = 4
    static let vowelColumnWidth: CGFloat = 44.0

    /// Bimanual layout (5 columns × 4 rows of consonants)
    /// Plus right-side vowel primitives and bottom function row
    static let bimanualConsonantGrid: [[KeyContent]] = [
        // Row 1: Double consonants
        [.consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ)],
        // Row 2: Basic consonants
        [.consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ)],
        // Row 3: Remaining consonants
        [.consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ)],
        // Row 4: Bottom consonants
        [.consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspace],
    ]

    /// Right-side vowel primitive column
    static let vowelPrimitiveColumn: [KeyContent] = [
        .vowelPrimitive(.dot),   // ㆍ
        .vowelPrimitive(.bar),   // ㅣ
        .vowelPrimitive(.dash),  // ㅡ
    ]

    /// Bottom function row for bimanual layout
    static let bimanualFunctionRow: [KeyContent] = [
        .functional(.languageSwitch),  // Short tap: special chars / Long: system switch
        .functional(.modeToggle),      // Korean ↔ Symbol (123)
        .quickPunctuation(","),
        .functional(.space),
        .quickPunctuation("."),
        .functional(.returnKey),
    ]

    private static let columnMap: [Choseong: Int] = [
        .ㅃ: 1, .ㅂ: 1, .ㅁ: 1, .ㅋ: 1,
        .ㅉ: 2, .ㅈ: 2, .ㄴ: 2, .ㅌ: 2,
        .ㄸ: 3, .ㄷ: 3, .ㅇ: 3, .ㅊ: 3,
        .ㄲ: 4, .ㄱ: 4, .ㄹ: 4, .ㅍ: 4,
        .ㅆ: 5, .ㅅ: 5, .ㅎ: 5,
    ]

    /// Get the column index (1-5) for a consonant key in bimanual layout
    static func columnIndex(for choseong: Choseong) -> Int {
        return columnMap[choseong] ?? 3
    }
}

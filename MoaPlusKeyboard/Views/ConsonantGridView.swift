import SwiftUI

struct KeyGridView: View {
    let centerKeyWidth: CGFloat
    let keyHeight: CGFloat
    let totalWidth: CGFloat
    let mode: KeyboardMode
    let layoutCustomization: LayoutCustomization
    /// Active symbol-keypad page (ignored outside symbol modes). Threaded from
    /// KeyboardViewModel.symbolPage so page 1 renders its own symbol grid.
    var symbolPage: Int = 0
    let activeKey: (row: Int, column: Int)?
    let previewVowel: Jungseong?
    var shiftState: ShiftState = .off
    let onConsonantTap: (Choseong) -> Void
    let onSymbolTap: (String) -> Void
    let onBackspacePressStart: () -> Void
    let onBackspacePressEnd: () -> Void
    /// (글자, row, column) → 팝업을 열었나. 롱키·팝업 콜백도 **키 위치를 함께** 넘긴다 — 타이머와
    /// 뗌은 키마다 따로 오므로, 위치가 없으면 뷰모델이 롤오버로 먼저 확정한 키나 레이어 전환 전에
    /// 누른 키의 늦은 신호를 지금 눌린 키의 것으로 해석한다 (이슈 #40).
    let onLongPressNumber: (String, Int, Int) -> Bool
    var onShiftLongPress: ((Int, Int) -> Void)? = nil
    let onGestureStart: (Int, Int, CGPoint) -> Void
    /// (row, column, point) — 키 위치를 함께 넘겨야 뷰모델이 롤오버로 먼저 확정한 키의 늦은 이동을 버린다.
    let onGestureMove: (Int, Int, CGPoint) -> Void
    let onGestureEnd: (Int, Int) -> Void
    /// (row, column, translationX)
    var onPopupDrag: ((Int, Int, CGFloat) -> Void)?
    /// (row, column)
    var onPopupRelease: ((Int, Int) -> Void)?
    var onSlotBVowelGestureStart: ((CGPoint) -> Void)? = nil
    var onSlotBVowelGestureMove: ((CGPoint) -> Void)? = nil
    var onSlotBVowelGestureEnd: (() -> Void)? = nil
    var onGestureCancel: ((Int, Int) -> Void)? = nil
    let onPunctuationSlot: (String) -> Void

    /// Returns the rendered width for a single cell, accounting for .backspaceWide.
    private func cellWidth(content: KeyContent, column: Int, row: Int) -> CGFloat {
        if case .backspaceWide = content {
            return KeyboardMetrics.keyWidth(forBackspaceWideAt: column, centerKeyWidth: centerKeyWidth)
        }
        // Slot B embedded keys (A3 col 6) use the same width as other col 6 cells.
        // The mode-aware key width helper already handles col 6 sizing (sideRatio*1.3).
        return KeyboardMetrics.keyWidth(for: column, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
    }

    /// Compute total width of a single row (sum of key widths + gaps).
    ///
    /// 레이아웃을 인자로 받는다 — 예전에는 여기서 직접 `activeLayout` 을 불렀는데,
    /// 이 함수가 행마다 호출되므로 body 1회 평가에 레이아웃이 총 6번(body 1 +
    /// rowCount 1 + 행 4) 재구축됐다. `activeLayout` 은 호출마다 4×7 KeyContent
    /// 배열과 leftCol 배열을 새로 만든다.
    private func rowWidth(for row: Int, in layoutGrid: [[KeyContent]]) -> CGFloat {
        guard row >= 0 && row < layoutGrid.count else { return 0 }
        let cells = layoutGrid[row]
        var width: CGFloat = 0
        for (col, content) in cells.enumerated() {
            width += cellWidth(content: content, column: col, row: row)
            if col < cells.count - 1 {
                width += KeyboardMetrics.keySpacing
            }
        }
        return width
    }

    var body: some View {
        // 레이아웃은 body 당 정확히 1회만 만든다. 행 수·행 폭도 이 값에서 파생시킨다.
        let layoutGrid = KeyboardMetrics.activeLayout(for: mode, layout: layoutCustomization, symbolPage: symbolPage)
        VStack(spacing: KeyboardMetrics.keySpacing) {
            ForEach(0..<layoutGrid.count, id: \.self) { row in
                HStack(spacing: KeyboardMetrics.keySpacing) {
                    let columnCount = layoutGrid[row].count

                    ForEach(0..<columnCount, id: \.self) { column in
                        let content: KeyContent? = layoutGrid[row][column]
                        let isActive = activeKey?.row == row && activeKey?.column == column

                        // 롱키 트리거와 힌트 액션 — 키마다 저장소 조회 1회 (`longPressBinding` 참조).
                        let longPress = Self.longPressBinding(
                            content: content, row: row, column: column, mode: mode,
                            layout: layoutCustomization,
                            englishLongPressUppercase: KeyboardSettings.shared.englishLongPressUppercaseEnabled,
                            storedAction: { KeyboardSettings.shared.secondaryAction(forKey: $0) })

                        let width = cellWidth(content: content ?? .symbol(""), column: column, row: row)

                        // A3 (.fullPackage) embeds slot B keys in col 6.
                        // KeyGridView intercepts those content types and renders the
                        // dedicated standalone views (already used in FunctionRowView).
                        if case .slotBVowelKey = content {
                            SlotBVowelKey(
                                width: width,
                                height: keyHeight,
                                onGestureStart: { point in onSlotBVowelGestureStart?(point) },
                                onGestureMove: { point in onSlotBVowelGestureMove?(point) },
                                onGestureEnd: { onSlotBVowelGestureEnd?() }
                            )
                        } else if case .slotBPunctuation = content {
                            // A3(fullPackage) 슬롯 B 임베드 punct 키: spec §4 bypass 적용
                            PunctuationSwipeKey(
                                width: width,
                                height: keyHeight,
                                slots: layoutCustomization.koreanPunctuationSlots,
                                onPunctuation: { symbol in onPunctuationSlot(symbol) }
                            )
                        } else if row == 0 && column == 6
                                    && mode == .korean
                                    && layoutCustomization.slotARightColumnTopAsPunctuation
                                    && (layoutCustomization.slotA == .vowel || layoutCustomization.slotA == .fullPackage) {
                            // A1 # 자리 또는 A3 slotARightColumn[0] 자리를 긋기 펑크 키로 교체. spec §4 bypass 적용
                            // 슬롯 B(스페이스 옆/col 6 임베드)와 독립된 우측 컬럼 전용 슬롯 사용.
                            PunctuationSwipeKey(
                                width: width,
                                height: keyHeight,
                                slots: layoutCustomization.slotARightColumnPunctuationSlots,
                                onPunctuation: { symbol in onPunctuationSlot(symbol) }
                            )
                        } else {
                        KeyView(
                            content: content ?? .symbol(""),
                            keySize: CGSize(width: width, height: keyHeight),
                            isPressed: isActive,
                            previewVowel: isActive ? previewVowel : nil,
                            longPressNumber: longPress.trigger,
                            secondaryAction: longPress.action,
                            showSecondaryHints: KeyboardSettings.shared.showSecondaryHints,
                            hintSize: KeyboardSettings.shared.hintSize,
                            // 키별 active 판정: 누른 키만 hint/라벨을 숨긴다.
                            // (전역 플래그를 쓰면 타이핑마다 28개 키 hint 가 깜빡임)
                            isGestureActive: isActive,
                            row: row,
                            column: column,
                            shiftState: shiftState,
                            mode: mode,
                            onLongPress: { number in
                                onLongPressNumber(number, row, column)
                            },
                            onBackspacePressStart: {
                                guard case .backspace = content else {
                                    if case .backspaceWide = content { onBackspacePressStart() }
                                    return
                                }
                                onBackspacePressStart()
                            },
                            onBackspacePressEnd: {
                                guard case .backspace = content else {
                                    if case .backspaceWide = content { onBackspacePressEnd() }
                                    return
                                }
                                onBackspacePressEnd()
                            },
                            onGestureStart: { point in
                                onGestureStart(row, column, point)
                            },
                            onGestureMove: { point in
                                onGestureMove(row, column, point)
                            },
                            onGestureEnd: {
                                onGestureEnd(row, column)
                            },
                            onPopupDrag: { translationX in
                                onPopupDrag?(row, column, translationX)
                            },
                            onPopupRelease: {
                                onPopupRelease?(row, column)
                            },
                            onShiftLongPress: { onShiftLongPress?(row, column) },
                            onGestureCancel: { onGestureCancel?(row, column) }
                        )
                        }   // close else branch (slot B intercept)
                    }
                }
                .frame(width: rowWidth(for: row, in: layoutGrid))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

extension KeyGridView {
    /// 키 하나의 롱키 설정. `trigger` 가 nil 이면 그 자리는 롱키가 없고 힌트도 그리지 않는다.
    struct LongPressBinding: Equatable {
        /// 누르고 있으면 팝업을 띄우는 글자(`onLongPress` 로 뷰모델에 넘어간다). 팝업 후보가 있으면
        /// 손 뗄 때 들어가는 건 후보 맨 앞 = `effectivePrimary` 라 이 값과 같다.
        let trigger: String?
        /// 힌트·팝업 후보의 출처. 트리거가 있는 자리에만 준다.
        let action: SecondaryKeyAction?
    }

    /// 그리드가 키마다 부르는 롱키 판정 — 테스트도 이 함수를 그대로 부른다.
    ///
    /// - 액션: 심볼 모드는 `KeyboardMetrics.symbolModeSecondaryAction` 으로 합성, 그 밖에는
    ///   자음(호환 자모, 예 "ㄱ")이나 심볼 문자열(영문 숫자 "1")로 저장소를 **한 번** 조회한다.
    /// - 트리거:
    ///   - 한글: 자음 키이고 레이아웃 고정표(`KeyboardMetrics.longPressNumber(at:column:layout:)`)에
    ///     값이 있는 자리만. 고정표는 롱키 유무를 정하는 문(門)이자, 저장된 출력이 비었을 때의
    ///     대체값이다. 글자는 액션의 `effectivePrimary` 가 우선 (이슈 #37 의 부차 원인 — 예전에는
    ///     고정표만 읽어 ㅈ 을 고쳐도 트리거가 7 이었다. 주 원인은 손 뗄 때 `popupOutputs[0]` 이
    ///     들어가 롱프레스 출력을 무시한 것으로, `SecondaryKeyAction.effectiveCandidates` 가 고친다).
    ///   - 영문: 숫자 키는 `effectivePrimary`, letter 키는 설정이 켜져 있으면 대문자.
    ///   - 심볼: 대체 문자표의 첫 글자(`effectivePrimary`).
    /// - 한글 모드 왼쪽 열 같은 심볼 칸은 글자가 우연히 저장된 keyId(예: slotC 를 "7"·"ㄱ" 로
    ///   바꾼 칸)와 같아도 롱키가 없으므로 그 액션의 힌트를 그리지 않는다.
    static func longPressBinding(
        content: KeyContent?,
        row: Int,
        column: Int,
        mode: KeyboardMode,
        layout: LayoutCustomization,
        englishLongPressUppercase: Bool,
        storedAction: (String) -> SecondaryKeyAction?
    ) -> LongPressBinding {
        let action: SecondaryKeyAction? = {
            switch content {
            case .consonant(let choseong) where !mode.isSymbol:
                return storedAction(String(choseong.compatibilityCharacter))
            case .symbol(let s):
                return mode.isSymbol ? KeyboardMetrics.symbolModeSecondaryAction(for: s) : storedAction(s)
            default:
                return nil
            }
        }()
        let primary: String? = action.map(\.effectivePrimary).flatMap { $0.isEmpty ? nil : $0 }

        let trigger: String? = {
            switch mode {
            case .korean:
                guard case .consonant = content,
                      let table = KeyboardMetrics.longPressNumber(at: row, column: column, layout: layout)
                else { return nil }
                return primary ?? table
            case .english:
                guard case .symbol(let s) = content else { return nil }
                if s.first?.isNumber == true { return primary }
                // 영문 letter 롱프레스 = 대문자. 숫자 행은 위에서 처리하므로 여기 오는 건 q~m 뿐이다.
                if s.count == 1, s.first?.isLetter == true, englishLongPressUppercase {
                    return s.uppercased()
                }
                return nil
            case .symbolFromKorean, .symbolFromEnglish:
                guard case .symbol = content else { return nil }
                return primary
            }
        }()

        return LongPressBinding(trigger: trigger, action: trigger == nil ? nil : action)
    }
}

// Legacy alias for compatibility
typealias ConsonantGridView = KeyGridView

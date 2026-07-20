import SwiftUI

struct FunctionRowView: View {
    let totalWidth: CGFloat
    let mode: KeyboardMode
    let onToggleSymbolPressed: () -> Void
    let onToggleLetterPressed: () -> Void
    let onSpacePressed: () -> Void
    let onPunctuation: (String) -> Void
    let onReturnPressed: () -> Void
    var onCursorMoveDelta: ((Int) -> Void)? = nil
    /// Active symbol-keypad page. Drives the page-toggle key label (#+= / 123).
    var symbolPage: Int = 0
    /// Fired by the symbol-mode page-toggle key (slot B position). nil outside
    /// symbol mode / when the host doesn't wire it.
    var onSymbolPagePressed: (() -> Void)? = nil
    var onLanguageSwitchPressed: (() -> Void)? = nil
    var useBimanualLayout: Bool = false
    var layoutCustomization: LayoutCustomization = LayoutCustomization()
    var onSlotBVowelGestureStart: ((CGPoint) -> Void)? = nil
    var onSlotBVowelGestureMove: ((CGPoint) -> Void)? = nil
    var onSlotBVowelGestureEnd: (() -> Void)? = nil

    private let spacing: CGFloat = KeyboardMetrics.keySpacing
    private let height: CGFloat = KeyboardMetrics.functionRowHeight

    /// Label for the 한글-or-ABC / !#1 toggle.
    /// In symbol mode, shows the target letter mode (한글/ABC) the user will return to.
    private var symbolToggleLabel: String {
        if mode.isSymbol {
            return mode.letterMode == .korean ? "한글" : "ABC"
        }
        return "!#1"
    }

    /// Label for the 한/영 toggle (shows the *target* letter mode).
    private var letterToggleLabel: String {
        mode.letterMode == .korean ? "ABC" : "한"
    }

    /// Label for the symbol-page toggle — shows the *target* page (iOS 관례).
    /// Page 0 (숫자판) → "#+=", page 1 (기호판) → "123".
    private var symbolPageToggleLabel: String {
        symbolPage == 0 ? "#+=" : "123"
    }

    /// 현재 모드에서 긋기 펑크 키를 표시할지. 심볼 모드는 항상 OFF (스코프 밖).
    private var punctuationEnabledForMode: Bool {
        if mode.isSymbol { return false }
        return mode == .korean
            ? layoutCustomization.koreanPunctuationEnabled
            : layoutCustomization.englishPunctuationEnabled
    }

    var body: some View {
        if useBimanualLayout {
            bimanualLayoutBody
        } else if mode.isSymbol {
            // 심볼 모드: 비어있던 슬롯 B 자리에 페이지 토글(#+= / 123) 배치.
            symbolLayoutBody
        } else if !punctuationEnabledForMode || (layoutCustomization.slotA == .fullPackage && mode == .korean) {
            // 펑크 키 OFF이거나 A3 한글 모드(그리드에 임베드 펑크 있음)면 긴 스페이스.
            // 영문 모드는 A3여도 그리드 임베드 없으므로 기본 레이아웃 사용.
            longSpaceLayoutBody
        } else {
            defaultLayoutBody
        }
    }

    // MARK: - Symbol layout
    // Same geometry as the default layout, but the slot B position (now placed
    // to the LEFT of the space bar, iOS-style) holds the symbol-page toggle
    // (#+= / 123) instead of the punctuation swipe key.
    // [한글/ABC] [한/영] [#+=/123] [   space   ] [return]

    private var symbolLayoutBody: some View {
        HStack(spacing: spacing) {
            FunctionKeyView(
                content: AnyView(
                    Text(symbolToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: symbolToggleWidth,
                height: height,
                action: onToggleSymbolPressed
            )

            FunctionKeyView(
                content: AnyView(
                    Text(letterToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: letterToggleWidth,
                height: height,
                action: onToggleLetterPressed
            )

            symbolPageToggleKey(width: punctuationWidth)

            SpaceKeyView(
                width: spaceWidth,
                height: height,
                onTap: onSpacePressed,
                onCursorMove: onCursorMoveDelta ?? { _ in }
            )

            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "return")
                        .font(.system(size: 20))
                ),
                width: returnWidth,
                height: height,
                action: onReturnPressed
            )
        }
    }

    /// Symbol-page toggle key (#+= / 123). Narrow slot-B width, so the label
    /// uses a slightly smaller font to fit the 3-character labels.
    private func symbolPageToggleKey(width: CGFloat) -> some View {
        FunctionKeyView(
            content: AnyView(
                Text(symbolPageToggleLabel)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            ),
            width: width,
            height: height,
            action: onSymbolPagePressed ?? {}
        )
    }

    // MARK: - Long-space layout (A3 .fullPackage + non-Korean modes)
    // Slot B is dropped and the space bar absorbs the freed width.
    // [123/한글] [한/영] [        space        ] [return]

    private var longSpaceLayoutBody: some View {
        HStack(spacing: spacing) {
            FunctionKeyView(
                content: AnyView(
                    Text(symbolToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: symbolToggleWidth,
                height: height,
                action: onToggleSymbolPressed
            )

            FunctionKeyView(
                content: AnyView(
                    Text(letterToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: letterToggleWidth,
                height: height,
                action: onToggleLetterPressed
            )

            SpaceKeyView(
                width: longSpaceWidth,
                height: height,
                onTap: onSpacePressed,
                onCursorMove: onCursorMoveDelta ?? { _ in }
            )

            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "return")
                        .font(.system(size: 20))
                ),
                width: returnWidth,
                height: height,
                action: onReturnPressed
            )
        }
    }

    /// Space bar absorbs the slot B punctuation key + 1 internal gap.
    private var longSpaceWidth: CGFloat {
        spaceWidth + punctuationWidth + spacing
    }

    // MARK: - Default layout
    // [123/한글] [한/영] [   space   ] [긋기 .] [return]

    private var defaultLayoutBody: some View {
        HStack(spacing: spacing) {
            // Symbol toggle (123/한글)
            FunctionKeyView(
                content: AnyView(
                    Text(symbolToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: symbolToggleWidth,
                height: height,
                action: onToggleSymbolPressed
            )

            // Letter toggle (한/영)
            FunctionKeyView(
                content: AnyView(
                    Text(letterToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: letterToggleWidth,
                height: height,
                action: onToggleLetterPressed
            )

            // Space bar
            SpaceKeyView(
                width: spaceWidth,
                height: height,
                onTap: onSpacePressed,
                onCursorMove: onCursorMoveDelta ?? { _ in }
            )

            // Slot B — punctuation (B2) or vowel key (B1) per layout customization.
            slotBKey(width: punctuationWidth)

            // Return button
            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "return")
                        .font(.system(size: 20))
                ),
                width: returnWidth,
                height: height,
                action: onReturnPressed
            )
        }
    }

    /// Renders the slot B key based on layoutCustomization.slotB.
    /// `.punctuation` → tap=. swipe ←=? →=! ↑=, ↓=.
    /// `.vowelKey` → tap=ㆍ + 8-direction single-stroke vowels.
    /// 영문 모드는 자음드래그 모음 입력 흐름이 없으므로 slotB == .vowelKey 무시하고
    /// 강제로 punctuation 사용. 한글 모드는 사용자 설정 그대로.
    @ViewBuilder
    private func slotBKey(width: CGFloat) -> some View {
        let effectiveSlotB: SlotBPreset = mode == .korean ? layoutCustomization.slotB : .punctuation
        switch effectiveSlotB {
        case .punctuation:
            let slots = mode == .korean
                ? layoutCustomization.koreanPunctuationSlots
                : layoutCustomization.englishPunctuationSlots
            PunctuationSwipeKey(
                width: width,
                height: height,
                slots: slots,
                onPunctuation: onPunctuation
            )
        case .vowelKey:
            SlotBVowelKey(
                width: width,
                height: height,
                onGestureStart: onSlotBVowelGestureStart ?? { _ in },
                onGestureMove: onSlotBVowelGestureMove ?? { _ in },
                onGestureEnd: onSlotBVowelGestureEnd ?? {}
            )
        }
    }

    // MARK: - Bimanual layout
    // Layout: [🌐] [한글/123] [한/영] [   space   ] [긋기 .] [return]

    private var bimanualLayoutBody: some View {
        HStack(spacing: spacing) {
            // Language switch key (globe)
            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                ),
                width: bimanualGlobeWidth,
                height: height,
                action: onLanguageSwitchPressed ?? {}
            )

            // Mode toggle (한글/123)
            FunctionKeyView(
                content: AnyView(
                    Text(symbolToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: bimanualToggleWidth,
                height: height,
                action: onToggleSymbolPressed
            )

            // Letter toggle (한/영)
            FunctionKeyView(
                content: AnyView(
                    Text(letterToggleLabel)
                        .font(.system(size: 16, weight: .medium))
                ),
                width: bimanualPunctuationWidth,
                height: height,
                action: onToggleLetterPressed
            )

            // Space bar (takes remaining width)
            SpaceKeyView(
                width: bimanualSpaceWidth,
                height: height,
                onTap: onSpacePressed,
                onCursorMove: onCursorMoveDelta ?? { _ in }
            )

            // Slot B — symbol-page toggle in symbol mode, else punctuation/vowel per customization.
            if mode.isSymbol {
                symbolPageToggleKey(width: bimanualPunctuationWidth)
            } else {
                slotBKey(width: bimanualPunctuationWidth)
            }

            // Return key
            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "return")
                        .font(.system(size: 20))
                ),
                width: returnWidth,
                height: height,
                action: onReturnPressed
            )
        }
    }

    // MARK: - Default layout widths

    /// The KeyboardView wraps its VStack in `.padding(KeyboardMetrics.keySpacing)`,
    /// which steals `2 * spacing` from the horizontal axis. The grid above us
    /// absorbs that slack via its center-key formula (8 internal gaps), but the
    /// function row's child widths sum *exactly* to `totalWidth`, so without
    /// compensating here the rightmost child (return key) overflows and gets
    /// clipped. Subtract the outer padding once so all downstream math fits.
    private var effectiveTotalWidth: CGFloat {
        max(0, totalWidth - spacing * 2)
    }

    private var returnWidth: CGFloat {
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        let usesWideBackspace = layoutCustomization.slotA == .fullPackage
            || (mode.isSymbol && layoutCustomization.slotA != .vowel)
            || (mode == .korean && !layoutCustomization.koreanPunctuationEnabled)
        if usesWideBackspace {
            // 확장형(A3) / classic11 symbol / 한글 펑크OFF: 2셀 너비로 백스페이스와 정렬.
            return KeyboardMetrics.keyWidth(forBackspaceWideAt: 0, centerKeyWidth: centerKeyWidth)
        }
        // Default (Korean and English): use the Korean 7-col formula so the
        // enter key is the same pixel width in both modes. The space bar
        // absorbs the difference in English mode.
        let sideWidth = centerKeyWidth * KeyboardMetrics.symbolWidthRatio
        return sideWidth + centerKeyWidth + KeyboardMetrics.keySpacing
    }

    private var availableWidthWithoutReturn: CGFloat {
        // Default layout: 5 children (toggles + space + punct + return) → 4 internal gaps.
        max(0, effectiveTotalWidth - returnWidth - spacing * 4)
    }

    private var symbolToggleWidth: CGFloat {
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        return centerKeyWidth * KeyboardMetrics.symbolWidthRatio * 1.3
    }

    private var letterToggleWidth: CGFloat {
        KeyboardMetrics.centerKeyWidth(for: totalWidth)
    }

    private var punctuationWidth: CGFloat {
        availableWidthWithoutReturn * 0.16
    }

    private var spaceWidth: CGFloat {
        // Default layout: 5 children → 4 internal gaps.
        let consumedByOthers = symbolToggleWidth + letterToggleWidth + punctuationWidth + returnWidth
        return max(0, effectiveTotalWidth - consumedByOthers - spacing * 4)
    }

    // MARK: - Bimanual layout widths

    private var bimanualGlobeWidth: CGFloat {
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        return centerKeyWidth * KeyboardMetrics.symbolWidthRatio
    }

    private var bimanualToggleWidth: CGFloat {
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        return centerKeyWidth * 1.2
    }

    private var bimanualPunctuationWidth: CGFloat {
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        return centerKeyWidth * KeyboardMetrics.symbolWidthRatio
    }

    private var bimanualSpaceWidth: CGFloat {
        // Bimanual layout: 6 children (globe + toggle + letterToggle + space + slotB + return)
        // → 5 internal gaps. Uses effectiveTotalWidth to compensate for parent padding.
        let fixedWidths = bimanualGlobeWidth + bimanualToggleWidth + bimanualPunctuationWidth * 2 + returnWidth
        return max(0, effectiveTotalWidth - fixedWidths - spacing * 5)
    }
}

// MARK: - Punctuation swipe key

/// 5개 슬롯(tap/←/→/↑/↓)을 외부에서 주입받는 긋기 펑크 키.
/// 빈 문자열("") 슬롯은 미리보기에서 숨김 + 드래그/탭 시 입력 무시.
struct PunctuationSwipeKey: View {
    let width: CGFloat
    let height: CGFloat
    let slots: PunctuationSlots
    let onPunctuation: (String) -> Void

    @State private var isPressed = false
    @State private var didDrag = false

    private static let dragThreshold: CGFloat = 12

    private var bg: Color { KeyboardSettings.shared.themeSettings.resolvedFunctionKeyBackground }
    private var fg: Color { KeyboardSettings.shared.themeSettings.resolvedKeyText }

    /// 글자 수에 따라 미리보기 폰트 축소. 1자=16/9, 2자=12/8, 3자+=10/7.
    private func mainFontSize(for text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 16
        case 2:    return 12
        default:   return 10
        }
    }
    private func hintFontSize(for text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 9
        case 2:    return 8
        default:   return 7
        }
    }

    @ViewBuilder
    private func hint(_ text: String) -> some View {
        if text.isEmpty {
            Text(" ").font(.system(size: 9)).foregroundColor(.clear)
        } else {
            Text(text).font(.system(size: hintFontSize(for: text))).foregroundColor(fg.opacity(0.5))
        }
    }

    @ViewBuilder
    private func main(_ text: String) -> some View {
        if text.isEmpty {
            Text(" ").font(.system(size: 16, weight: .medium)).foregroundColor(.clear)
        } else {
            Text(text).font(.system(size: mainFontSize(for: text), weight: .medium)).foregroundColor(fg)
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            hint(slots.up)
            HStack(spacing: 4) {
                hint(slots.left)
                main(slots.tap)
                hint(slots.right)
            }
            hint(slots.down)
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                .fill(isPressed ? bg.opacity(0.7) : bg)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed { isPressed = true }
                    if !didDrag {
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dx) >= Self.dragThreshold || abs(dy) >= Self.dragThreshold {
                            didDrag = true
                            let symbol: String
                            if abs(dx) > abs(dy) {
                                symbol = dx > 0 ? slots.right : slots.left
                            } else {
                                symbol = dy > 0 ? slots.down : slots.up
                            }
                            // 빈 슬롯 가드 — 입력 안 함
                            if !symbol.isEmpty {
                                onPunctuation(symbol)
                            }
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if !didDrag {
                        if !slots.tap.isEmpty {
                            onPunctuation(slots.tap)
                        }
                    }
                    didDrag = false
                }
        )
    }
}

// MARK: - Slot B vowel key (B1 preset)

/// 슬롯 B `.vowelKey` 프리셋. tap = ㆍ; 드래그 = 자음 키와 동일한 멀티 스트로크
/// 모음 파이프라인 (GestureAnalyzer + VowelResolver). 단일 스트로크 ㅏ/ㅓ/ㅗ/ㅜ
/// 부터 합성 모음 ㅑ/ㅕ/ㅛ/ㅠ/ㅒ/ㅖ/ㅢ/ㅘ/ㅙ/ㅚ/ㅝ/ㅞ/ㅟ 까지 모두 지원.
/// 뷰는 제스처 포인트만 ViewModel 로 전달한다 — 방향 판정은 ViewModel 에서.
struct SlotBVowelKey: View {
    let width: CGFloat
    let height: CGFloat
    let onGestureStart: (CGPoint) -> Void
    let onGestureMove: (CGPoint) -> Void
    let onGestureEnd: () -> Void

    @State private var isPressed = false

    private var bg: Color { KeyboardSettings.shared.themeSettings.resolvedFunctionKeyBackground }
    private var fg: Color { KeyboardSettings.shared.themeSettings.resolvedKeyText }

    var body: some View {
        VStack(spacing: 1) {
            Text("ㅗ").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
            HStack(spacing: 4) {
                Text("ㅓ").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
                Text("ㆍ").font(.system(size: 16, weight: .medium)).foregroundColor(fg)
                Text("ㅏ").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
            }
            Text("ㅜ").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                .fill(isPressed ? bg.opacity(0.7) : bg)
        )
        .gesture(
            // Named coordinate space ("keyboardPreview") so points are in the
            // keyboard's frame, not the key's local frame. Used by settings
            // preview for opposite-side bubble positioning. Falls back to
            // local coords if the named space isn't on an ancestor (it's
            // declared on KeyboardView's root, present in both production
            // and preview).
            DragGesture(minimumDistance: 0, coordinateSpace: .named("keyboardPreview"))
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        onGestureStart(value.startLocation)
                    }
                    onGestureMove(value.location)
                }
                .onEnded { _ in
                    isPressed = false
                    onGestureEnd()
                }
        )
    }
}

/// Drives continuous cursor movement while the space bar is held pushed in one
/// direction. `DragGesture.onChanged` only fires while the finger *moves*, so a
/// held-still finger produces no events — a repeating timer is required to keep
/// the cursor moving. The repeat accelerates the longer the direction is held.
///
/// Timer follows the project rule (CLAUDE.md): `[weak self]` capture and
/// `RunLoop.main.add(forMode: .common)` so it keeps firing during UI tracking
/// and can't retain the view. Held by SpaceKeyView via `@State` (a plain
/// reference type — it drives no view updates, so no ObservableObject needed).
final class SpaceCursorRepeater {
    /// Called on each repeat tick with the direction (+1 forward / -1 back).
    var onStep: ((Int) -> Void)?

    private var timer: Timer?
    private var direction: Int = 0
    private var interval: TimeInterval = 0.14
    private var minInterval: TimeInterval = 0.045

    private static let accelerationFactor: TimeInterval = 0.85

    /// Begin (or redirect) continuous movement. No-op if already repeating in
    /// the same direction, so repeated onChanged calls don't restart the ramp.
    /// The ramp (start interval → floor) comes from the user's
    /// `cursorRepeatSpeed` setting, read fresh on each start.
    func start(direction dir: Int) {
        guard dir != 0 else { stop(); return }
        if timer != nil && direction == dir { return }
        stop()
        direction = dir
        let ramp = KeyboardSettings.shared.cursorRepeatInterval
        interval = ramp.initial
        minInterval = ramp.min
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        direction = 0
    }

    var isRunning: Bool { timer != nil }

    private func scheduleNext() {
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.onStep?(self.direction)
            self.interval = max(self.minInterval, self.interval * Self.accelerationFactor)
            self.scheduleNext()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit { stop() }
}

struct SpaceKeyView: View {
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void
    let onCursorMove: (Int) -> Void

    @State private var isPressed = false
    @State private var didDrag = false
    @State private var lastReportedOffset: CGFloat = 0
    @State private var repeater = SpaceCursorRepeater()
    /// Which edge zone is currently driving auto-repeat (0 = none, -1 left,
    /// +1 right). Drives the edge-zone highlight so the user sees when the
    /// space bar has flipped into continuous-scroll mode.
    @State private var activeRepeatDirection: Int = 0

    private static let dragThreshold: CGFloat = 8
    private static let pixelsPerStep: CGFloat = 12
    /// Fraction of the space-bar width at each end that acts as the auto-repeat
    /// zone. Proportional (not absolute pt) so it scales to small phones —
    /// holding the finger in the outer 15% of the bar repeats in that direction.
    private static let edgeZoneFraction: CGFloat = 0.15

    private var themeBackgroundColor: Color {
        KeyboardSettings.shared.themeSettings.resolvedFunctionKeyBackground
    }
    private var themeTextColor: Color {
        KeyboardSettings.shared.themeSettings.resolvedKeyText
    }

    /// One auto-repeat edge zone: a tint + directional chevron, both derived
    /// from the theme text color (`resolvedKeyText`) so they track theme/custom
    /// color changes and always contrast with the space-bar background — no
    /// hardcoded accent. Dim when idle, bright when the finger is inside it
    /// (continuous-scroll active).
    @ViewBuilder
    private func edgeZone(side: Int) -> some View {
        let active = activeRepeatDirection == side
        ZStack {
            // Very light zone wash just to delineate the region; the chevron is
            // the real indicator. Both derive from the theme text color.
            Rectangle()
                .fill(themeTextColor.opacity(active ? 0.18 : 0.06))
            // Chevron in the theme text color as-is: full opacity when the
            // finger is in this zone (continuous-scroll on), dimmed otherwise
            // so both zones stay discoverable while dragging.
            Image(systemName: side < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeTextColor.opacity(active ? 1.0 : 0.4))
        }
        .frame(width: width * Self.edgeZoneFraction)
    }

    var body: some View {
        Text("space")
            .font(.system(size: 16))
            .foregroundColor(themeTextColor.opacity(0.6))
            .frame(width: width, height: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                        .fill(isPressed ? themeBackgroundColor.opacity(0.7) : themeBackgroundColor)
                    // While dragging for cursor movement, reveal BOTH edge zones
                    // so the user can see where to aim before reaching one — the
                    // zones are invisible at rest. Each zone shows a chevron in
                    // the theme text color (guaranteed contrast, unlike accent);
                    // the active zone (finger inside) brightens to confirm
                    // continuous-scroll is engaged. Only shows once a drag starts,
                    // so a plain space tap never flashes.
                    if didDrag {
                        HStack(spacing: 0) {
                            edgeZone(side: -1)
                            Spacer(minLength: 0)
                            edgeZone(side: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius))
                    }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed { isPressed = true }
                        // When the cursor-by-drag toggle is off, never enter
                        // drag mode — small finger movements (≥ dragThreshold)
                        // would otherwise suppress the onTap fallback in
                        // `onEnded`, dropping the space input on the floor.
                        guard KeyboardSettings.shared.cursorMoveBySpaceDragEnabled else { return }
                        let dx = value.translation.width
                        if !didDrag && abs(dx) >= Self.dragThreshold {
                            didDrag = true
                            lastReportedOffset = 0
                            repeater.onStep = { onCursorMove($0) }
                        }
                        if didDrag {
                            // Auto-repeat zone is defined by finger POSITION within
                            // the bar (outer 15% each end), not absolute drag
                            // distance — so it scales to any bar width. location.x
                            // is in the key's local space and can run past the
                            // edges when the finger leaves the bar.
                            let locX = value.location.x
                            let leftEdge = width * Self.edgeZoneFraction
                            let rightEdge = width * (1 - Self.edgeZoneFraction)
                            if locX <= leftEdge {
                                repeater.start(direction: -1)
                                if activeRepeatDirection != -1 { activeRepeatDirection = -1 }
                            } else if locX >= rightEdge {
                                repeater.start(direction: 1)
                                if activeRepeatDirection != 1 { activeRepeatDirection = 1 }
                            } else {
                                // Middle: precise distance-based stepping. Stop any
                                // active repeat and re-baseline so returning to the
                                // middle doesn't produce a jump.
                                if repeater.isRunning {
                                    repeater.stop()
                                    lastReportedOffset = dx
                                }
                                if activeRepeatDirection != 0 { activeRepeatDirection = 0 }
                                let totalSteps = Int(dx / Self.pixelsPerStep)
                                let lastSteps = Int(lastReportedOffset / Self.pixelsPerStep)
                                let delta = totalSteps - lastSteps
                                if delta != 0 {
                                    onCursorMove(delta)
                                    lastReportedOffset = dx
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        repeater.stop()
                        activeRepeatDirection = 0
                        if !didDrag {
                            onTap()
                        }
                        didDrag = false
                        lastReportedOffset = 0
                    }
            )
    }
}

struct FunctionKeyView: View {
    let content: AnyView
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    private var themeBackgroundColor: Color {
        KeyboardSettings.shared.themeSettings.resolvedFunctionKeyBackground
    }

    private var themeTextColor: Color {
        KeyboardSettings.shared.themeSettings.resolvedKeyText
    }

    var body: some View {
        content
            .foregroundColor(themeTextColor)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(isPressed ? themeBackgroundColor.opacity(0.7) : themeBackgroundColor)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Korean Mode (default)")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            mode: .korean,
            onToggleSymbolPressed: { print("Symbol") },
            onToggleLetterPressed: { print("Letter") },
            onSpacePressed: { print("Space") },
            onPunctuation: { print("Punct: \($0)") },
            onReturnPressed: { print("Return") }
        )

        Text("Symbol Mode (default)")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            mode: .symbolFromKorean,
            onToggleSymbolPressed: { print("Symbol") },
            onToggleLetterPressed: { print("Letter") },
            onSpacePressed: { print("Space") },
            onPunctuation: { print("Punct: \($0)") },
            onReturnPressed: { print("Return") }
        )

        Text("English Mode (default)")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            mode: .english,
            onToggleSymbolPressed: { print("Symbol") },
            onToggleLetterPressed: { print("Letter") },
            onSpacePressed: { print("Space") },
            onPunctuation: { print("Punct: \($0)") },
            onReturnPressed: { print("Return") }
        )
    }
    .padding()
    .background(Color(.systemGray6))
}

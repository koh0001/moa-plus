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

    var body: some View {
        if useBimanualLayout {
            bimanualLayoutBody
        } else if mode == .korean && layoutCustomization.slotA == .fullPackage {
            longSpaceLayoutBody
        } else {
            defaultLayoutBody
        }
    }

    // MARK: - Long-space layout (A3 .fullPackage)
    // Slot B is embedded in col 6 of the grid, so the function row drops it
    // and absorbs the freed width into the space bar.
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
    @ViewBuilder
    private func slotBKey(width: CGFloat) -> some View {
        switch layoutCustomization.slotB {
        case .punctuation:
            PunctuationSwipeKey(
                width: width,
                height: height,
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

            // Slot B — punctuation (B2) or vowel key (B1) per layout customization.
            slotBKey(width: bimanualPunctuationWidth)

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
        if layoutCustomization.slotA == .fullPackage {
            // 확장형(A3): match wide backspace width (*1.3) so right edges align with row 3.
            return KeyboardMetrics.keyWidth(forBackspaceWideAt: 0, centerKeyWidth: centerKeyWidth)
        }
        // Default: match standard backspace width (sideWidth + centerKeyWidth + spacing).
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

/// Tap = ".", swipe up = ",", swipe left = "?", swipe right = "!", swipe down = ".".
struct PunctuationSwipeKey: View {
    let width: CGFloat
    let height: CGFloat
    let onPunctuation: (String) -> Void

    @State private var isPressed = false
    @State private var didDrag = false

    private static let dragThreshold: CGFloat = 12

    private var bg: Color { KeyboardSettings.shared.themeSettings.resolvedFunctionKeyBackground }
    private var fg: Color { KeyboardSettings.shared.themeSettings.resolvedKeyText }

    var body: some View {
        VStack(spacing: 1) {
            Text(",").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
            HStack(spacing: 4) {
                Text("?").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
                Text(".").font(.system(size: 16, weight: .medium)).foregroundColor(fg)
                Text("!").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
            }
            Text(".").font(.system(size: 9)).foregroundColor(fg.opacity(0.5))
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
                                symbol = dx > 0 ? "!" : "?"
                            } else {
                                symbol = dy > 0 ? "." : ","
                            }
                            onPunctuation(symbol)
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if !didDrag {
                        onPunctuation(".")
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

struct SpaceKeyView: View {
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void
    let onCursorMove: (Int) -> Void

    @State private var isPressed = false
    @State private var didDrag = false
    @State private var lastReportedOffset: CGFloat = 0

    private static let dragThreshold: CGFloat = 8
    private static let pixelsPerStep: CGFloat = 12

    private var themeBackgroundColor: Color {
        KeyboardSettings.shared.themeSettings.resolvedFunctionKeyBackground
    }
    private var themeTextColor: Color {
        KeyboardSettings.shared.themeSettings.resolvedKeyText
    }

    var body: some View {
        Text("space")
            .font(.system(size: 16))
            .foregroundColor(themeTextColor.opacity(0.6))
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(isPressed ? themeBackgroundColor.opacity(0.7) : themeBackgroundColor)
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
                        }
                        if didDrag {
                            let totalSteps = Int(dx / Self.pixelsPerStep)
                            let lastSteps = Int(lastReportedOffset / Self.pixelsPerStep)
                            let delta = totalSteps - lastSteps
                            if delta != 0 {
                                onCursorMove(delta)
                                lastReportedOffset = dx
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
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

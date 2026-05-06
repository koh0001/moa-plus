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
        } else {
            defaultLayoutBody
        }
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

            // Swipe punctuation key (tap = ".", up = ",", left = "?", right = "!", down = ".")
            PunctuationSwipeKey(
                width: punctuationWidth,
                height: height,
                onPunctuation: onPunctuation
            )

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

            // Swipe punctuation
            PunctuationSwipeKey(
                width: bimanualPunctuationWidth,
                height: height,
                onPunctuation: onPunctuation
            )

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

    private var returnWidth: CGFloat {
        // Match backspace width: sideWidth + centerKeyWidth + spacing
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        let sideWidth = centerKeyWidth * KeyboardMetrics.symbolWidthRatio
        return sideWidth + centerKeyWidth + KeyboardMetrics.keySpacing
    }

    private var availableWidthWithoutReturn: CGFloat {
        // 5 internal gaps for 5 buttons (4 widgets + return) plus 2 outer paddings
        totalWidth - returnWidth - spacing * 5
    }

    private var symbolToggleWidth: CGFloat {
        availableWidthWithoutReturn * 0.20
    }

    private var letterToggleWidth: CGFloat {
        availableWidthWithoutReturn * 0.16
    }

    private var punctuationWidth: CGFloat {
        availableWidthWithoutReturn * 0.16
    }

    private var spaceWidth: CGFloat {
        availableWidthWithoutReturn * 0.48
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
        // Remaining width after all fixed elements and gaps
        let gapCount: CGFloat = 7  // 6 keys = 5 gaps, plus 2 outer edges omitted (HStack handles)
        let fixedWidths = bimanualGlobeWidth + bimanualToggleWidth + bimanualPunctuationWidth * 2 + returnWidth
        return totalWidth - fixedWidths - spacing * (gapCount - 2)
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

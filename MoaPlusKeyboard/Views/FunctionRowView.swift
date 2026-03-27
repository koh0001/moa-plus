import SwiftUI

struct FunctionRowView: View {
    let totalWidth: CGFloat
    let isSymbolMode: Bool
    let onToggleModePressed: () -> Void
    let onCommaPressed: () -> Void
    let onSpacePressed: () -> Void
    let onReturnPressed: () -> Void
    var onLanguageSwitchPressed: (() -> Void)? = nil
    var onPeriodPressed: (() -> Void)? = nil
    var useBimanualLayout: Bool = false

    private let spacing: CGFloat = KeyboardMetrics.keySpacing
    private let height: CGFloat = KeyboardMetrics.functionRowHeight

    var body: some View {
        if useBimanualLayout {
            bimanualLayoutBody
        } else {
            defaultLayoutBody
        }
    }

    // MARK: - Default layout

    private var defaultLayoutBody: some View {
        HStack(spacing: spacing) {
            // 123/한글 toggle button (replaces globe)
            FunctionKeyView(
                content: AnyView(
                    Text(isSymbolMode ? "한글" : "123")
                        .font(.system(size: 16, weight: .medium))
                ),
                width: toggleWidth,
                height: height,
                action: onToggleModePressed
            )

            // Comma key (left of space)
            FunctionKeyView(
                content: AnyView(
                    Text(",")
                        .font(.system(size: 20))
                ),
                width: commaWidth,
                height: height,
                action: onCommaPressed
            )

            // Space bar
            FunctionKeyView(
                content: AnyView(
                    Text("space")
                        .font(.system(size: 16))
                        .foregroundColor(KeyboardSettings.shared.themeSettings.resolvedKeyText.opacity(0.6))
                ),
                width: spaceWidth,
                height: height,
                action: onSpacePressed
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
    // Layout: [🌐] [한글/123] [,] [   space   ] [.] [return]

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
                    Text(isSymbolMode ? "한글" : "123")
                        .font(.system(size: 16, weight: .medium))
                ),
                width: bimanualToggleWidth,
                height: height,
                action: onToggleModePressed
            )

            // Comma
            FunctionKeyView(
                content: AnyView(
                    Text(",")
                        .font(.system(size: 20))
                ),
                width: bimanualPunctuationWidth,
                height: height,
                action: onCommaPressed
            )

            // Space bar (takes remaining width)
            FunctionKeyView(
                content: AnyView(
                    Text("space")
                        .font(.system(size: 16))
                        .foregroundColor(KeyboardSettings.shared.themeSettings.resolvedKeyText.opacity(0.6))
                ),
                width: bimanualSpaceWidth,
                height: height,
                action: onSpacePressed
            )

            // Period
            FunctionKeyView(
                content: AnyView(
                    Text(".")
                        .font(.system(size: 20))
                ),
                width: bimanualPunctuationWidth,
                height: height,
                action: onPeriodPressed ?? {}
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
        totalWidth - returnWidth - spacing * 5  // 5 gaps for 4 buttons + edges
    }

    private var toggleWidth: CGFloat {
        availableWidthWithoutReturn * 0.30
    }

    private var commaWidth: CGFloat {
        availableWidthWithoutReturn * 0.14
    }

    private var spaceWidth: CGFloat {
        availableWidthWithoutReturn * 0.56
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
            isSymbolMode: false,
            onToggleModePressed: { print("Toggle") },
            onCommaPressed: { print("Comma") },
            onSpacePressed: { print("Space") },
            onReturnPressed: { print("Return") }
        )

        Text("Symbol Mode (default)")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            isSymbolMode: true,
            onToggleModePressed: { print("Toggle") },
            onCommaPressed: { print("Comma") },
            onSpacePressed: { print("Space") },
            onReturnPressed: { print("Return") }
        )

        Text("Korean Mode (bimanual)")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            isSymbolMode: false,
            onToggleModePressed: { print("Toggle") },
            onCommaPressed: { print("Comma") },
            onSpacePressed: { print("Space") },
            onReturnPressed: { print("Return") },
            onLanguageSwitchPressed: { print("Globe") },
            onPeriodPressed: { print("Period") },
            useBimanualLayout: true
        )
    }
    .padding()
    .background(Color(.systemGray6))
}

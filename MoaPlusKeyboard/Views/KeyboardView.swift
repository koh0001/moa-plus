import SwiftUI
import Combine

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var settings = KeyboardSettings.shared
    // Observe sub-states directly to reduce unnecessary redraws
    @ObservedObject var gestureState: GestureState
    @ObservedObject var popupState: PopupState
    /// Test/preview seam (default nil = production, no behavior change). When
    /// set, forces the iPad split decision instead of reading UIDevice/UIScreen
    /// — host-less unit tests can't observe the real idiom, so snapshots use it.
    var layoutOverride: (isPad: Bool, isLandscape: Bool)? = nil
    private static let closingBrackets: Set<String> = [")", "]", "}", ">", "」", "』", "》", "】", "〕"]
    @State private var cachedBgImage: UIImage?
    @State private var cachedBgImageId: String?

    private var keyboardBackground: some View {
        Group {
            if let image = cachedBgImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(KeyboardSettings.shared.themeSettings.backgroundOpacity)
                    .clipped()
            } else {
                Color(.systemGray6)
            }
        }
    }

    @ViewBuilder
    private func keyGrid(centerKeyWidth: CGFloat, keyHeight: CGFloat, totalWidth: CGFloat) -> some View {
        KeyGridView(
            centerKeyWidth: centerKeyWidth,
            keyHeight: keyHeight,
            totalWidth: totalWidth,
            mode: viewModel.keyboardMode,
            layoutCustomization: settings.layoutCustomization,
            activeKey: viewModel.activeKey,
            previewVowel: viewModel.previewVowel,
            shiftState: viewModel.shiftState,
            onConsonantTap: { viewModel.inputConsonant($0) },
            onSymbolTap: { viewModel.inputSymbol($0) },
            onBackspacePressStart: { viewModel.beginBackspacePress() },
            onBackspacePressEnd: { viewModel.endBackspacePress() },
            onLongPressNumber: { viewModel.inputLongPressNumber($0) },
            onShiftLongPress: { viewModel.lockShift() },
            onGestureStart: { row, column, point in viewModel.gestureStarted(row: row, column: column, at: point) },
            onGestureMove: { viewModel.gestureMoved(to: $0) },
            onGestureEnd: { row, column in viewModel.gestureEnded(row: row, column: column) },
            onPopupDrag: { viewModel.updatePopupSelection(translationX: $0) },
            onPopupRelease: { viewModel.confirmPopupSelection() },
            onSlotBVowelGestureStart: { viewModel.slotBVowelGestureStarted(at: $0) },
            onSlotBVowelGestureMove: { viewModel.slotBVowelGestureMoved(to: $0) },
            onSlotBVowelGestureEnd: { viewModel.slotBVowelGestureEnded() },
            onPunctuationSlot: { viewModel.inputSymbol($0, bypassAutoBracket: true) }
        )
    }

    @ViewBuilder
    private func numberPad(panelWidth: CGFloat, keyHeight: CGFloat) -> some View {
        // panelWidth is already stripped of outer padding and HStack gap by the caller.
        // NumberPadView internally subtracts only the 2 inter-key gaps (3 columns → 2 gaps).
        NumberPadView(
            panelWidth: panelWidth,
            keyHeight: keyHeight,
            onDigit: { viewModel.inputSymbol($0) },
            onBackspacePressStart: { viewModel.beginBackspacePress() },
            onBackspacePressEnd: { viewModel.endBackspacePress() }
        )
    }

    @ViewBuilder
    private func functionRow(totalWidth: CGFloat) -> some View {
        FunctionRowView(
            totalWidth: totalWidth,
            mode: viewModel.keyboardMode,
            onToggleSymbolPressed: { viewModel.toggleSymbolMode() },
            onToggleLetterPressed: { viewModel.toggleLetterMode() },
            onSpacePressed: { viewModel.inputSpace() },
            onPunctuation: { viewModel.inputSymbol($0, bypassAutoBracket: true) },
            onReturnPressed: { viewModel.inputReturn() },
            onCursorMoveDelta: { viewModel.moveCursor(by: $0) },
            layoutCustomization: settings.layoutCustomization,
            onSlotBVowelGestureStart: { viewModel.slotBVowelGestureStarted(at: $0) },
            onSlotBVowelGestureMove: { viewModel.slotBVowelGestureMoved(to: $0) },
            onSlotBVowelGestureEnd: { viewModel.slotBVowelGestureEnded() }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(
                for: geometry.size.width,
                columnCount: viewModel.keyboardMode == .english ? 10 : 7,
                mode: viewModel.keyboardMode
            )
            let keyHeight = KeyboardMetrics.keyHeight(for: geometry.size.height)
            let screen = UIScreen.main.bounds
            let screenShort = min(screen.width, screen.height)
            let screenLong = max(screen.width, screen.height)
            let isPad = layoutOverride?.isPad ?? (UIDevice.current.userInterfaceIdiom == .pad)
            let isLandscape = layoutOverride?.isLandscape ?? KeyboardMetrics.isLandscapeKeyboard(
                keyboardWidth: geometry.size.width, screenShort: screenShort, screenLong: screenLong)
            let useSplit = KeyboardMetrics.usesIPadSplit(
                isPad: isPad, isLandscape: isLandscape,
                portraitSplitEnabled: settings.layoutCustomization.iPadPortraitSplitEnabled)
                && viewModel.keyboardMode == .korean

            // Split-mode panel metrics — hoisted so the long-press popup can
            // reference them even though the grid block is inside `if useSplit`.
            let splitSpacing = KeyboardMetrics.keySpacing
            let numpadWidth = (geometry.size.width - splitSpacing * 3) * 0.31
            let moakiWidth  = (geometry.size.width - splitSpacing * 3) * 0.69
            let moakiCenterKeyWidth = KeyboardMetrics.centerKeyWidth(
                for: moakiWidth, columnCount: 7, mode: .korean)

                ZStack {
                    VStack(spacing: KeyboardMetrics.keySpacing) {
                        // Abbreviation candidate bar
                        if viewModel.isAbbreviationCandidateVisible,
                           !viewModel.abbreviationCandidates.isEmpty {
                            AbbreviationCandidateView(
                                trigger: viewModel.abbreviationCandidates.first?.trigger ?? "",
                                candidates: viewModel.abbreviationCandidates,
                                onConfirm: { expansion in viewModel.confirmAbbreviation(expansion) },
                                onDismiss: { viewModel.dismissAbbreviation() }
                            )
                        }

                        if useSplit {
                            HStack(spacing: splitSpacing) {
                                if settings.layoutCustomization.numberPadSide == .left {
                                    numberPad(panelWidth: numpadWidth, keyHeight: keyHeight)
                                        .frame(width: numpadWidth)
                                    keyGrid(centerKeyWidth: moakiCenterKeyWidth, keyHeight: keyHeight, totalWidth: moakiWidth)
                                        .frame(width: moakiWidth)
                                } else {
                                    keyGrid(centerKeyWidth: moakiCenterKeyWidth, keyHeight: keyHeight, totalWidth: moakiWidth)
                                        .frame(width: moakiWidth)
                                    numberPad(panelWidth: numpadWidth, keyHeight: keyHeight)
                                        .frame(width: numpadWidth)
                                }
                            }
                            functionRow(totalWidth: geometry.size.width)
                        } else {
                            keyGrid(centerKeyWidth: centerKeyWidth, keyHeight: keyHeight, totalWidth: geometry.size.width)
                            functionRow(totalWidth: geometry.size.width)
                        }
                    }
                    .padding(KeyboardMetrics.keySpacing)

                    // Gesture overlay (shown when enabled or forced, and in Korean mode)
                    if (settings.showGesturePreview || viewModel.forceShowGesturePreview) && viewModel.keyboardMode == .korean {
                        GestureOverlayView(
                            directions: gestureState.directions,
                            startPoint: gestureState.startPoint,
                            currentVowel: gestureState.previewVowel
                        )
                    }

                    // Long-press popup with candidate bar
                    if popupState.text != nil,
                       let activeRow = gestureState.activeKey?.row,
                       let activeCol = gestureState.activeKey?.column {
                        let sp = KeyboardMetrics.keySpacing
                        // In split mode the moaki grid is rendered at moakiWidth/moakiCenterKeyWidth
                        // and offset from the screen edge by the numpad panel (when numpad is on the
                        // left). Compute the popup X in the moaki grid's local coordinate space then
                        // add moakiLeftInset to convert to the full keyboard coordinate space.
                        let popupCenterKeyWidth = useSplit ? moakiCenterKeyWidth : centerKeyWidth
                        let popupGridWidth      = useSplit ? moakiWidth          : geometry.size.width
                        let moakiLeftInset: CGFloat = useSplit
                            ? (settings.layoutCustomization.numberPadSide == .left
                                ? (numpadWidth + splitSpacing)
                                : 0)
                            : 0
                        let xInGrid = keyXPosition(column: activeCol, row: activeRow, centerKeyWidth: popupCenterKeyWidth, spacing: sp, totalWidth: popupGridWidth)
                        let x = xInGrid + moakiLeftInset
                        let y = CGFloat(activeRow) * (keyHeight + sp) + sp + keyHeight / 2
                        let popupY = activeRow == 0 ? y + keyHeight * 0.9 : y - keyHeight * 0.9
                        let rawCandidates = popupState.candidates
                        let selectedIdx = popupState.selectedIndex
                        let isRightEdge = activeCol >= 5
                        // Auto-bracket hides standalone closing brackets in
                        // letter modes (where the keyboard auto-pairs). In
                        // symbol mode the user is explicitly picking the
                        // character, so the filter must not run.
                        let shouldFilterClosers = KeyboardSettings.shared.autoBracketEnabled && !viewModel.keyboardMode.isSymbol
                        let candidates = shouldFilterClosers
                            ? rawCandidates.filter { !Self.closingBrackets.contains($0) }
                            : rawCandidates
                        // Right-edge: reverse display so leftward drag matches visual order
                        let displayCandidates = isRightEdge ? Array(candidates.reversed()) : candidates
                        let displaySelectedIdx = isRightEdge ? (candidates.count - 1 - min(selectedIdx, candidates.count - 1)) : min(selectedIdx, candidates.count - 1)

                        HStack(spacing: 2) {
                            ForEach(0..<displayCandidates.count, id: \.self) { i in
                                let text = displayCandidates[i]
                                // Show bracket pair if auto-bracket enabled
                                let label = KeyboardSettings.shared.autoBracketEnabled
                                    ? (bracketPairLabel(text) ?? text)
                                    : text
                                Text(label)
                                    .font(.system(size: label.count > 1 ? 14 : 18, weight: i == displaySelectedIdx ? .bold : .regular))
                                    .foregroundColor(i == displaySelectedIdx ? .white : .primary)
                                    .frame(width: label.count > 1 ? 44 : 36, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(i == displaySelectedIdx ? Color.accentColor : Color(.systemBackground))
                                    )
                            }
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        )
                        .position(x: {
                            let cellSize: CGFloat = 36
                            let popupHalfWidth = CGFloat(candidates.count) * (cellSize + 2) / 2 + 8
                            // Clamp within the moaki grid + its left inset (full width in non-split).
                            let clampMin = moakiLeftInset + popupHalfWidth + 4
                            let clampMax = moakiLeftInset + popupGridWidth - popupHalfWidth - 4
                            // Right-edge keys: anchor popup to the left of key
                            if activeCol >= 5 {
                                return min(x, clampMax)
                            }
                            // Left-edge keys: anchor popup to the right
                            if activeCol == 0 {
                                return max(x, clampMin)
                            }
                            return min(max(x, clampMin), clampMax)
                        }(), y: popupY)
                        .allowsHitTesting(false)
                    }
                }
                .background(keyboardBackground)
                .onAppear { viewModel.setCenterKeyWidth(centerKeyWidth) }
                .onChange(of: centerKeyWidth) { _, newValue in
                    viewModel.setCenterKeyWidth(newValue)
                }
        }
        // Named coordinate space lets the slot-B vowel key report its
        // gesture start point in the keyboard's frame (instead of the key's
        // local frame), so the settings preview can position UI based on
        // which half of the keyboard the user touched. Production keyboard
        // ignores this — the value is only consumed in preview mode.
        .coordinateSpace(name: "keyboardPreview")
        .onAppear { loadBackgroundIfNeeded() }
        .onChange(of: settings.themeSettings.backgroundImageId) { loadBackgroundIfNeeded() }
    }

    private func loadBackgroundIfNeeded() {
        let currentId = settings.themeSettings.backgroundImageId
        guard currentId != cachedBgImageId else { return }
        cachedBgImageId = currentId
        if let id = currentId {
            cachedBgImage = BackgroundImageManager.shared.loadUserImage(withId: id)
        } else {
            cachedBgImage = nil
        }
    }

    /// Calculate the X center of a key based on column/row, with grid centered horizontally
    private func keyXPosition(column: Int, row: Int, centerKeyWidth: CGFloat, spacing: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let mode = viewModel.keyboardMode
        let columnCount = KeyboardMetrics.columnCount(for: row, mode: mode)

        // Calculate total grid width for centering
        var totalGridWidth: CGFloat = 0
        for col in 0..<columnCount {
            totalGridWidth += KeyboardMetrics.keyWidth(for: col, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
            if col < columnCount - 1 {
                totalGridWidth += spacing
            }
        }

        let leftMargin = max(spacing, (totalWidth - totalGridWidth) / 2)

        var x = leftMargin
        for col in 0..<columnCount {
            let w = KeyboardMetrics.keyWidth(for: col, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
            if col == column {
                return x + w / 2
            }
            x += w + spacing
        }
        return totalWidth / 2 // fallback: center
    }

    /// Returns "( )" style label if the character is an opening bracket, nil otherwise
    private func bracketPairLabel(_ text: String) -> String? {
        let pairs: [String: String] = [
            "(": "( )", "[": "[ ]", "{": "{ }", "<": "< >",
            "「": "「」", "『": "『』", "《": "《》", "【": "【】", "〔": "〔〕"
        ]
        return pairs[text]
    }
}

#Preview {
    let vm = KeyboardViewModel()
    KeyboardView(viewModel: vm, gestureState: vm.gestureState, popupState: vm.popupState)
        .frame(height: 280)
}

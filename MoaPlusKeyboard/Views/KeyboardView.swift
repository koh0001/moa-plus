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
    /// 테스트 seam (기본 nil = 프로덕션, 동작 변화 없음). 설정되면 `cachedBgImage` 대신 이 사진을
    /// 배경으로 그린다. `cachedBgImage` 는 `.onAppear` 에서 채우는 `@State` 라 `ImageRenderer`
    /// 한 번의 렌더에는 들어오지 않는다 — `KeyboardView` 단위 배경 렌더 테스트(이슈 #39 리뷰,
    /// `BackgroundImageFitTests.test_keyboardView_*`)가 이 경로로 사진을 넣어, 테마의 맞춤 방식·
    /// 크기·투명도·밑바탕과 한손 모드 본체 기준 배치가 실제 `keyboardBackground` 를 거쳐
    /// 그려지는지 본다.
    var backgroundImageOverride: UIImage? = nil
    @State private var cachedBgImage: UIImage?
    @State private var cachedBgImageId: String?

    /// 키보드 배경. 사진이 덮지 않는 곳(전체 보이기·크기 축소)은 평소 배경색이 보인다 (이슈 #39).
    ///
    /// 사진 밑에 깔린 `systemGray6` 은 익스텐션에서는 원래부터 있던 색이다 — 컨트롤러 뷰
    /// 배경이 `systemGray6`, 호스팅 뷰가 `.clear` 라 반투명 사진은 늘 그 위에 합성됐다.
    /// 그래서 꽉 채우기·100%(기본)는 픽셀 단위로 예전과 같다. 메인 앱 미리보기만 사진 밑이
    /// 목록 셀 색에서 실제 키보드와 같은 색으로 바뀐다.
    ///
    /// - Parameter photoFocusInsets: 사진을 맞출 영역을 이 배경에서 뺄 폭. 한손 모드는 배경을
    ///   띠까지 한 번에 그리므로(바깥 HStack) 띠 폭을 넘겨 사진을 **본체** 기준으로 놓는다 —
    ///   안 넘기면 줄인 사진이 전체 폭 가운데에 놓여 띠 밑으로 밀린다. 규칙은
    ///   `BackgroundImageLayout.displayRect`.
    private func keyboardBackground(photoFocusInsets: EdgeInsets = EdgeInsets()) -> some View {
        ZStack {
            Color(.systemGray6)
            if let image = backgroundImageOverride ?? cachedBgImage {
                let theme = settings.themeSettings
                KeyboardBackgroundImageView(
                    image: image,
                    opacity: theme.backgroundOpacity,
                    contentMode: theme.backgroundImageContentMode,
                    scale: theme.backgroundImageScale,
                    focusInsets: photoFocusInsets
                )
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
            symbolPage: viewModel.symbolPage,
            activeKey: viewModel.activeKey,
            previewVowel: viewModel.previewVowel,
            shiftState: viewModel.shiftState,
            onConsonantTap: { viewModel.inputConsonant($0) },
            onSymbolTap: { viewModel.inputSymbol($0) },
            onBackspacePressStart: { viewModel.beginBackspacePress() },
            onBackspacePressEnd: { viewModel.endBackspacePress() },
            onLongPressNumber: { number, row, column in
                viewModel.inputLongPressNumber(number, row: row, column: column)
            },
            onShiftLongPress: { row, column in viewModel.lockShift(row: row, column: column) },
            onGestureStart: { row, column, point in viewModel.gestureStarted(row: row, column: column, at: point) },
            onGestureMove: { row, column, point in viewModel.gestureMoved(row: row, column: column, to: point) },
            onGestureEnd: { row, column in viewModel.gestureEnded(row: row, column: column) },
            onPopupDrag: { row, column, translationX in
                viewModel.updatePopupSelection(row: row, column: column, translationX: translationX)
            },
            onPopupRelease: { row, column in viewModel.confirmPopupSelection(row: row, column: column) },
            onSlotBVowelGestureStart: { viewModel.slotBVowelGestureStarted(at: $0) },
            onSlotBVowelGestureMove: { viewModel.slotBVowelGestureMoved(to: $0) },
            onSlotBVowelGestureEnd: { viewModel.slotBVowelGestureEnded() },
            onGestureCancel: { row, column in viewModel.cancelGesture(row: row, column: column) },
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
            symbolPage: viewModel.symbolPage,
            onSymbolPagePressed: { viewModel.toggleSymbolPage() },
            onLanguageSwitchPressed: { viewModel.switchKeyboard() },
            showGlobeKey: viewModel.canSwitchInputMode,
            layoutCustomization: settings.layoutCustomization,
            onSlotBVowelGestureStart: { viewModel.slotBVowelGestureStarted(at: $0) },
            onSlotBVowelGestureMove: { viewModel.slotBVowelGestureMoved(to: $0) },
            onSlotBVowelGestureEnd: { viewModel.slotBVowelGestureEnded() }
        )
    }

    var body: some View {
        GeometryReader { outer in
            if let side = oneHandedSide(fullWidth: outer.size.width) {
                // 한손 모드: 본체는 좁힌 폭으로 그대로 그리고(그리드·기능행·팝업·오버레이가 모두
                // 주어진 폭을 따른다), 빈쪽에 위치 전환 띠를 붙인다. 배경은 바깥에서 한 번만.
                let width = KeyboardPlacement.keyboardWidth(
                    totalWidth: outer.size.width, ratio: settings.oneHandedWidthRatio)
                // 띠 폭 — 배경 사진은 이만큼 뺀 본체 기준으로 놓는다 (이슈 #39 리뷰).
                let stripWidth = max(0, outer.size.width - width)
                HStack(spacing: 0) {
                    if side == .right { oneHandedStrip(side: side) }
                    keyboardContent(drawsBackground: false)
                        .frame(width: width)
                    if side == .left { oneHandedStrip(side: side) }
                }
                .background(keyboardBackground(photoFocusInsets: EdgeInsets(
                    top: 0,
                    leading: side == .right ? stripWidth : 0,
                    bottom: 0,
                    trailing: side == .left ? stripWidth : 0)))
            } else {
                keyboardContent(drawsBackground: true)
            }
        }
        // 기능행 키들이 누르는 순간 울릴 수 있게 주입 (이슈 #23).
        // 그리드 키와 슬롯B 는 `gestureStarted` / `slotBVowelGestureStarted` 가
        // 이미 터치 다운에서 불리므로 ViewModel 쪽에서 처리한다.
        .environment(\.keyPressFeedback) { viewModel.keyPressFeedback() }
        // 레이어 전환 키(한/영 · 123/한글 · #+=/123)는 탭 대신 레이어 전환 햅틱 (이슈 #41).
        // 이 주입을 빠뜨리면 기본값(no-op)이 실려 그 키들이 조용해진다.
        .environment(\.layerSwitchPressFeedback) { viewModel.layerSwitchPressFeedback() }
        .onAppear { loadBackgroundIfNeeded() }
        .onChange(of: settings.themeSettings.backgroundImageId) { loadBackgroundIfNeeded() }
    }

    /// 한손 모드를 실제로 적용할 쪽. 아이폰 세로 화면에서만 — 판정은 **전체 폭** 기준.
    private func oneHandedSide(fullWidth: CGFloat) -> KeyboardPlacement? {
        let screen = UIScreen.main.bounds
        let isPad = layoutOverride?.isPad ?? (UIDevice.current.userInterfaceIdiom == .pad)
        let isLandscape = layoutOverride?.isLandscape ?? KeyboardMetrics.isLandscapeKeyboard(
            keyboardWidth: fullWidth,
            screenShort: min(screen.width, screen.height),
            screenLong: max(screen.width, screen.height))
        return settings.keyboardPlacement.effectiveSide(isPad: isPad, isLandscape: isLandscape)
    }

    /// 한손 모드의 빈쪽 띠: 반대쪽으로 옮기기 + 전체 폭으로 돌아가기 (순정 키보드와 같은 구성).
    ///
    /// 아이콘은 **기능키 모양 버튼 위에** 그린다. 키보드 배경 위에 키 글자색만 쓰면 글자색이 흰
    /// 테마(다크 차콜·네이비)나 배경 이미지에서 밝은 배경에 묻힌다(실기기 확인). 기능키 배경 +
    /// 키 글자색은 테마가 짝지어 둔 조합이라 어떤 테마에서도 대비가 보장된다.
    private func oneHandedStrip(side: KeyboardPlacement) -> some View {
        let bottomInset = KeyboardMetrics.resolvedBottomInset(
            autoEnabled: settings.keyboardAutoBottomInsetEnabled,
            deviceInset: viewModel.bottomSafeAreaInset,
            extra: settings.keyboardExtraBottomInset)
        return VStack(spacing: 20) {
            oneHandedButton(
                systemName: side == .left ? "chevron.right" : "chevron.left",
                size: 20,
                label: side == .left ? "키보드를 오른쪽으로" : "키보드를 왼쪽으로"
            ) {
                settings.keyboardPlacement = side == .left ? .right : .left
            }
            oneHandedButton(systemName: "arrow.up.left.and.arrow.down.right",
                            size: 17, label: "키보드 전체 폭") {
                settings.keyboardPlacement = .full
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, bottomInset)
    }

    private func oneHandedButton(systemName: String, size: CGFloat, label: String,
                                 action: @escaping () -> Void) -> some View {
        Button {
            viewModel.keyPressFeedback()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(settings.resolvedKeyText)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                        .fill(settings.resolvedFunctionKeyBackground)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                )
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func keyboardContent(drawsBackground: Bool) -> some View {
        GeometryReader { geometry in
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(
                for: geometry.size.width,
                columnCount: viewModel.keyboardMode == .english ? 10 : 7,
                mode: viewModel.keyboardMode
            )
            // 약어 후보 바가 차지하는 몫은 그리드 계산에서 **먼저 빼야** 한다.
            // `keyHeight(for:)` 는 주어진 높이를 그리드 행에 전부 나눠주므로, 컨테이너만
            // 키워 두면 늘어난 높이를 키들이 그대로 흡수해 버리고 후보 바는 여전히
            // 아래로 넘쳐 기능행이 잘린다(실기기 확인).
            let candidateBarFootprint: CGFloat = viewModel.isAbbreviationCandidateVisible
                ? KeyboardMetrics.abbreviationCandidateBarFootprint
                : 0
            let screen = UIScreen.main.bounds
            let screenShort = min(screen.width, screen.height)
            let screenLong = max(screen.width, screen.height)
            let isPad = layoutOverride?.isPad ?? (UIDevice.current.userInterfaceIdiom == .pad)
            let isLandscape = layoutOverride?.isLandscape ?? KeyboardMetrics.isLandscapeKeyboard(
                keyboardWidth: geometry.size.width, screenShort: screenShort, screenLong: screenLong)
            // 하단 여백(홈 인디케이터 회피). 근거는 실측 안전영역 하나뿐이다 —
            // 익스텐션은 `KeyboardViewController` 가, 호스트 앱 미리보기는
            // `KeyboardPreviewView` 가 각자 실측값을 `bottomSafeAreaInset` 에
            // 밀어넣는다. 여기서 화면 크기로 다시 추정하면 컨테이너 높이 계산
            // (`KeyboardViewController.bottomInset()`)과 규칙이 갈려 기능행이 잘린다.
            let bottomInset = KeyboardMetrics.resolvedBottomInset(
                autoEnabled: settings.keyboardAutoBottomInsetEnabled,
                deviceInset: viewModel.bottomSafeAreaInset,
                extra: settings.keyboardExtraBottomInset)
            // 후보 바와 **똑같은 이유**로 여백도 그리드 배분에서 먼저 빼야 한다.
            // `keyHeight(for:)` 는 주어진 높이를 4행에 전부 나눠주므로, 컨테이너만
            // 키우고 여기서 안 빼면 늘어난 높이를 키들이 흡수해 버리고 기능행은
            // 여전히 아래로 넘쳐 잘린다.
            let keyHeight = KeyboardMetrics.keyHeight(
                for: geometry.size.height - candidateBarFootprint - bottomInset)
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
                        // Abbreviation candidate bar.
                        // 표시 조건은 `isAbbreviationCandidateVisible` **하나만** 본다 —
                        // KeyboardViewController 의 높이 보정이 같은 플래그를 구독하므로,
                        // 여기에 조건을 더 붙이면 둘이 어긋나 높이가 안 맞는다.
                        if viewModel.isAbbreviationCandidateVisible {
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
                    .padding(.bottom, bottomInset)

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
                        // 후보 바가 떠 있으면 그리드가 그만큼 아래로 밀리므로 팝업 좌표도
                        // 같이 밀어야 한다 — 안 그러면 팝업이 키 위가 아닌 곳에 뜬다.
                        let y = candidateBarFootprint
                            + CGFloat(activeRow) * (keyHeight + sp) + sp + keyHeight / 2
                        let popupY = activeRow == 0 ? y + keyHeight * 0.9 : y - keyHeight * 0.9
                        let candidates = Self.popupDisplayCandidates(
                            candidates: popupState.candidates, text: popupState.text)
                        let selectedIdx = popupState.selectedIndex
                        let isRightEdge = activeCol >= 5
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
                .background(Group { if drawsBackground { keyboardBackground() } })
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
        //
        // 한손 모드에서도 **좁힌 본체 안쪽**에 둬야 한다 — 긋기 시작점·오버레이·팝업이 모두
        // 이 좌표계라, 바깥에 두면 띠 폭만큼 어긋난다. EarlyTouch 의 키 찾기는 `.global`
        // 이라 띠와 무관하다.
        .coordinateSpace(name: "keyboardPreview")
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

    /// 롱키 팝업에 그릴 후보. 뷰모델이 `SecondaryKeyAction.effectiveCandidates` 로 이미 닫는
    /// 괄호 필터까지 마친 배열을 **그대로** 그린다 — 여기서 한 번 더 거르면 손 뗄 때 들어가는
    /// 글자(뷰모델 배열의 선택 칸)와 화면이 어긋나고, 후보가 전부 닫는 괄호면 빈 팝업이 뜬다
    /// (이슈 #37 리뷰).
    ///
    /// 후보가 없는 키(영문 letter 롱프레스 대문자, 대체문자 없는 심볼 키)는 팝업 텍스트
    /// 자체를 유일한 후보로 그린다. 빈 배열로 두면 패딩과 그림자만 남아 키보드 위에 정체를
    /// 알 수 없는 검은 점이 뜬다.
    static func popupDisplayCandidates(candidates: [String], text: String?) -> [String] {
        candidates.isEmpty ? [text].compactMap { $0 } : candidates
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

// MARK: - 배경 사진 (이슈 #39)

/// 키보드 배경 사진. 크기·위치는 `BackgroundImageLayout.displayRect` 가 정한다 — 기본은 가운데,
/// 한손 모드는 `focusInsets`(띠) 를 뺀 본체 기준.
///
/// `image` 는 `KeyboardView.cachedBgImage` 가 들고 있는 다운샘플본(`BackgroundImageManager`
/// 상한 1536px) 그대로다. 맞춤 방식·크기 슬라이더는 **프레임만** 바꾸고 다시 디코딩·리샘플하지
/// 않는다 — 익스텐션 메모리 한계(~30MB) 때문에 슬라이더 틱마다 비트맵을 새로 만들면 안 된다.
/// 사진은 이 뷰의 영역 밖으로 그리지 않는다(꽉 채우기에서 넘치는 부분은 잘린다).
struct KeyboardBackgroundImageView: View {
    let image: UIImage
    let opacity: Double
    let contentMode: BackgroundImageContentMode
    let scale: Double
    /// 사진을 맞출 영역을 이 뷰에서 뺄 폭 (기본 0 = 뷰 전체). 한손 모드의 띠 폭.
    var focusInsets: EdgeInsets = EdgeInsets()

    var body: some View {
        GeometryReader { geo in
            // 폭·높이가 0 이하로 떨어지면 `displayRect` 가 뷰 전체 기준으로 돌아간다.
            let focus = CGRect(
                x: focusInsets.leading,
                y: focusInsets.top,
                width: max(0, geo.size.width - focusInsets.leading - focusInsets.trailing),
                height: max(0, geo.size.height - focusInsets.top - focusInsets.bottom))
            let rect = BackgroundImageLayout.displayRect(
                imageSize: image.size,
                containerSize: geo.size,
                focus: focus,
                contentMode: contentMode,
                scale: scale
            )
            Image(uiImage: image)
                .resizable()
                .frame(width: rect.width, height: rect.height)
                .opacity(opacity)
                .position(x: rect.midX, y: rect.midY)
        }
        .clipped()
    }
}

// MARK: - 누름 시점 햅틱 주입 (이슈 #23)

/// 키를 **누르는 순간** 울릴 피드백. 손을 뗄 때(입력 확정)가 아니라 터치 다운에서
/// 울려야 긋기 입력에서도 반응이 즉각적으로 느껴진다.
///
/// 기능행 키(`FunctionKeyView` / `SpaceKeyView` / `PunctuationSwipeKey`)는 생성 지점이
/// 20곳이 넘어 인자로 넘기면 한두 곳을 빠뜨리기 쉽다. 환경 값으로 한 번만 주입한다.
/// 기본값은 no-op 이라 미리보기·테스트는 영향을 받지 않는다.
private struct KeyPressFeedbackKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

/// 레이어 전환 키의 누름 피드백 (이슈 #41). `keyPressFeedback` 과 같은 시점(누르는 순간, 키 하나에
/// 한 번)이고, 탭 햅틱 **대신** 울린다. 기본값은 no-op.
private struct LayerSwitchPressFeedbackKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

/// 기능키를 누르는 순간 낼 피드백 종류 (`FunctionKeyView.pressFeedback`).
enum KeyPressFeedbackKind {
    /// 일반 키 — 탭 햅틱 (`keyPressFeedback`).
    case tap
    /// 한/영 · 123/한글 · #+=/123 — 레이어 전환 햅틱 (`layerSwitchPressFeedback`).
    case layerSwitch
}

extension EnvironmentValues {
    var keyPressFeedback: () -> Void {
        get { self[KeyPressFeedbackKey.self] }
        set { self[KeyPressFeedbackKey.self] = newValue }
    }

    var layerSwitchPressFeedback: () -> Void {
        get { self[LayerSwitchPressFeedbackKey.self] }
        set { self[LayerSwitchPressFeedbackKey.self] = newValue }
    }
}

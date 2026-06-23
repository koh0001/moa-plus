# iPad 동적 높이 + 가로 좌우 분리 키보드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 아이패드에서만 키보드 높이를 화면에 맞게 키우고, 가로일 때 좌=숫자패드 / 우=모아키 그리드로 분리한다(아이폰 무손상).

**Architecture:** 순수 함수(높이·방향·분리 판정)를 `KeyboardMetrics`에 두고 단위 테스트로 고정한다. `KeyboardViewController`가 런타임 `UIScreen` 실측으로 높이 제약을 설정·회전 대응하고, `KeyboardView`가 iPad 가로에서 분리 레이아웃으로 분기한다. 모아키 패널은 기존 `KeyGridView`를, 하단은 기존 `FunctionRowView`를 재사용한다.

**Tech Stack:** Swift, SwiftUI(키보드 UI), UIKit(`UIInputViewController`), XCTest. 시뮬레이터 `iPhone 17` / `iPad (A16)` 또는 `iPad Pro 13-inch (M4)`.

## Global Constraints

- **아이패드 전용 게이트**: 모든 신규 동작은 `UIDevice.current.userInterfaceIdiom == .pad` (또는 `traitCollection.userInterfaceIdiom == .pad`) 안에서만. 아이폰 경로는 한 줄도 변경 금지. `KeyboardMetrics.keyboardHeight`(상수 260)는 아이폰 값으로 보존.
- **App Group ID 변경 금지**: `group.com.moaki.keyboard`.
- **`KeyboardSettings`에 새 옵션 추가 시**: `LayoutCustomization`은 `init(from:)`에서 `decodeIfPresent` + `?? 기본값` 가드 필수 + `CodingKeys`에 키 추가(디코딩 실패 시 전체 설정 리셋 방지).
- **신규 enum 케이스 추가 시** 모든 exhaustive switch 점검.
- **테스트 명령**: `xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoaPlusKeyboardTests`. 키보드 익스텐션은 incremental 빌드 누락이 잦으니 검증 시 `clean test` 권장.
- **빌드 명령**: `xcodebuild build -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17'`.

---

### Task 1: 동적 높이 순수 함수 (KeyboardMetrics)

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift` (line 58-59 근처 `keyboardHeight` 상수 옆에 추가)
- Test: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift` (파일 끝에 추가)

**Interfaces:**
- Consumes: 기존 `static let keyboardHeight: CGFloat = 260`.
- Produces:
  - `static func keyboardHeight(isPad: Bool, isLandscape: Bool, screenShort: CGFloat, screenLong: CGFloat) -> CGFloat`
  - 상수: `iPadPortraitHeightRatio = 0.30`, `iPadLandscapeHeightRatio = 0.44`, `iPadPortraitHeightRange = 310...400`, `iPadLandscapeHeightRange = 320...420`.

- [ ] **Step 1: 실패하는 테스트 작성** — `KeyboardMetricsLayoutTests.swift` 끝(`}` 직전)에 추가:

```swift
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoaPlusKeyboardTests/KeyboardMetricsLayoutTests`
Expected: 컴파일 실패 ("type 'KeyboardMetrics' has no member 'keyboardHeight(isPad:...)'").

- [ ] **Step 3: 최소 구현** — `KeyboardMetrics.swift`의 `static let keyboardHeight: CGFloat = 260` 바로 아래에 추가:

```swift
    // MARK: - iPad dynamic height (T6)
    // 런타임 UIScreen 실측에서 계산 → 모델 하드코딩 없이 모든 아이패드에 정확.
    static let iPadPortraitHeightRatio: CGFloat = 0.30
    static let iPadLandscapeHeightRatio: CGFloat = 0.44
    static let iPadPortraitHeightRange: ClosedRange<CGFloat> = 310...400
    static let iPadLandscapeHeightRange: ClosedRange<CGFloat> = 320...420

    /// 키보드 컨테이너 높이. 아이폰은 항상 260(현행 유지), 아이패드만 화면 실측 기반.
    /// `screenShort`/`screenLong` = `UIScreen.main.bounds` 의 min/max (방향 불변).
    static func keyboardHeight(isPad: Bool, isLandscape: Bool,
                               screenShort: CGFloat, screenLong: CGFloat) -> CGFloat {
        guard isPad else { return keyboardHeight }   // iPhone: 260, 무손상
        if isLandscape {
            let raw = screenShort * iPadLandscapeHeightRatio
            return min(max(raw, iPadLandscapeHeightRange.lowerBound), iPadLandscapeHeightRange.upperBound)
        } else {
            let raw = screenLong * iPadPortraitHeightRatio
            return min(max(raw, iPadPortraitHeightRange.lowerBound), iPadPortraitHeightRange.upperBound)
        }
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: (Step 2와 동일)
Expected: PASS (6개 신규 테스트 포함).

- [ ] **Step 5: 커밋**

```bash
git add MoaPlusKeyboard/Utilities/KeyboardMetrics.swift MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift
git commit -m "feat(ipad): dynamic keyboard height function (iPhone unchanged)"
```

---

### Task 2: 방향·분리 판정 순수 함수 (KeyboardMetrics)

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift` (Task 1 블록 아래)
- Test: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift`

**Interfaces:**
- Produces:
  - `static func isLandscapeKeyboard(keyboardWidth: CGFloat, screenShort: CGFloat, screenLong: CGFloat) -> Bool`
  - `static func usesIPadSplit(isPad: Bool, isLandscape: Bool) -> Bool`
- 비고: 키보드 GeometryReader 의 `size.height` 는 키보드 높이(작음)라 `width > height` 로는 방향 판정 불가. 키보드 폭이 기기 **장축(long)** 인지로 판정한다.

- [ ] **Step 1: 실패하는 테스트 작성** — 파일 끝에 추가:

```swift
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... -only-testing:MoaPlusKeyboardTests/KeyboardMetricsLayoutTests`
Expected: 컴파일 실패 (`isLandscapeKeyboard`/`usesIPadSplit` 없음).

- [ ] **Step 3: 최소 구현** — Task 1 블록 아래 추가:

```swift
    /// 키보드는 항상 화면 폭을 꽉 채우므로, 키보드 폭이 기기 장축이면 가로.
    /// (단축+장축 중점을 임계로 둬서 인셋/안전영역 오차에 강건.)
    static func isLandscapeKeyboard(keyboardWidth: CGFloat,
                                    screenShort: CGFloat, screenLong: CGFloat) -> Bool {
        keyboardWidth > (screenShort + screenLong) / 2
    }

    /// 좌우 분리 레이아웃 사용 여부 — 아이패드 가로에서만.
    static func usesIPadSplit(isPad: Bool, isLandscape: Bool) -> Bool {
        isPad && isLandscape
    }
```

- [ ] **Step 4: 테스트 통과 확인** — Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add MoaPlusKeyboard/Utilities/KeyboardMetrics.swift MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift
git commit -m "feat(ipad): landscape + split-decision predicates"
```

---

### Task 3: numberPadSide 설정 (LayoutCustomization)

**Files:**
- Modify: `MoaPlusKeyboard/Models/LayoutCustomization.swift`
- Test: `MoaPlusKeyboardTests/KeyboardSettingsLayoutTests.swift` (기존 round-trip 테스트 파일에 추가)

**Interfaces:**
- Produces: `enum NumberPadSide: String, Codable, CaseIterable { case left, right }`, `LayoutCustomization.numberPadSide: NumberPadSide`(기본 `.left`).

- [ ] **Step 1: 실패하는 테스트 작성** — `KeyboardSettingsLayoutTests.swift` 끝(`}` 직전)에 추가:

```swift
    // MARK: - numberPadSide (T6)

    func testNumberPadSide_defaultIsLeft() {
        XCTAssertEqual(LayoutCustomization().numberPadSide, .left)
    }

    func testNumberPadSide_roundTripsRight() throws {
        var lc = LayoutCustomization()
        lc.numberPadSide = .right
        let data = try JSONEncoder().encode(lc)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded.numberPadSide, .right)
    }

    func testNumberPadSide_absentKeyDecodesToLeft() throws {
        // 구버전 JSON(키 없음) → 기본 .left (전체 설정 리셋 방지)
        let json = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: json)
        XCTAssertEqual(decoded.numberPadSide, .left)
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... -only-testing:MoaPlusKeyboardTests/KeyboardSettingsLayoutTests`
Expected: 컴파일 실패 (`numberPadSide` 없음).

- [ ] **Step 3: 최소 구현** — `LayoutCustomization.swift`:

(a) `SlotBPreset` enum 아래에 enum 추가:
```swift
enum NumberPadSide: String, Codable, CaseIterable {
    case left   // 좌=숫자패드 (기본)
    case right  // 우=숫자패드
}
```
(b) `struct LayoutCustomization` 의 stored property 영역(`var slotC` 아래)에 추가:
```swift
    /// iPad 가로 분리 레이아웃에서 숫자패드 위치. 아이폰/세로에선 무시.
    var numberPadSide: NumberPadSide = .left
```
(c) `init(from:)` 의 마지막 `slotARightColumnPunctuationSlots = ...` 줄 아래에 추가:
```swift
        numberPadSide = try c.decodeIfPresent(NumberPadSide.self, forKey: .numberPadSide) ?? .left
```
(d) `CodingKeys` 에 `numberPadSide` 추가:
```swift
    private enum CodingKeys: String, CodingKey {
        case slotA, slotABackspaceSwap, slotARightColumn, slotB, slotC
        case koreanPunctuationEnabled, englishPunctuationEnabled, slotARightColumnTopAsPunctuation
        case koreanPunctuationSlots, englishPunctuationSlots, slotARightColumnPunctuationSlots
        case numberPadSide
    }
```

- [ ] **Step 4: 테스트 통과 확인** — Expected: PASS (3개 신규).

- [ ] **Step 5: 커밋**

```bash
git add MoaPlusKeyboard/Models/LayoutCustomization.swift MoaPlusKeyboardTests/KeyboardSettingsLayoutTests.swift
git commit -m "feat(ipad): numberPadSide setting with decode guard"
```

---

### Task 4: 숫자패드 키 모델 (KeyboardMetrics)

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`
- Test: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift`

**Interfaces:**
- Produces: `static let numberPadKeys: [[String]]` (4행 × 3열), `static let numberPadBackspaceLabel = "⌫"`.

- [ ] **Step 1: 실패하는 테스트 작성** — 파일 끝에 추가:

```swift
    // MARK: - number pad model (T6)

    func testNumberPadKeys_shape() {
        XCTAssertEqual(KeyboardMetrics.numberPadKeys.count, 4)
        for row in KeyboardMetrics.numberPadKeys { XCTAssertEqual(row.count, 3) }
    }

    func testNumberPadKeys_contents() {
        XCTAssertEqual(KeyboardMetrics.numberPadKeys[0], ["1", "2", "3"])
        XCTAssertEqual(KeyboardMetrics.numberPadKeys[3], [".", "0", KeyboardMetrics.numberPadBackspaceLabel])
    }
```

- [ ] **Step 2: 테스트 실패 확인** — Expected: 컴파일 실패 (`numberPadKeys` 없음).

- [ ] **Step 3: 최소 구현** — Task 2 블록 아래 추가:

```swift
    /// 아이패드 분리 레이아웃 좌(또는 우) 숫자패드. 계산기식 3×4.
    static let numberPadBackspaceLabel = "⌫"
    static let numberPadKeys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", numberPadBackspaceLabel]
    ]
```

- [ ] **Step 4: 테스트 통과 확인** — Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add MoaPlusKeyboard/Utilities/KeyboardMetrics.swift MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift
git commit -m "feat(ipad): number pad key model"
```

---

### Task 5: NumberPadView (SwiftUI)

**Files:**
- Create: `MoaPlusKeyboard/Views/NumberPadView.swift`
- 빌드 검증(렌더링은 수동). SwiftUI 뷰는 단위 테스트하지 않는 것이 이 코드베이스 관례.

**Interfaces:**
- Consumes: `KeyboardMetrics.numberPadKeys`, `KeyboardMetrics.numberPadBackspaceLabel`, `KeyboardMetrics.keySpacing`, `KeyboardMetrics.keyCornerRadius`.
- Produces:
```swift
struct NumberPadView: View {
    let panelWidth: CGFloat
    let keyHeight: CGFloat
    let onDigit: (String) -> Void
    let onBackspacePressStart: () -> Void
    let onBackspacePressEnd: () -> Void
}
```

- [ ] **Step 1: 뷰 작성** — `NumberPadView.swift` 신규:

```swift
import SwiftUI

/// 아이패드 가로 분리 레이아웃의 숫자패드(계산기식 3×4).
/// 키 탭은 KeyboardViewModel 의 기존 입력 경로(inputSymbol / 백스페이스)로 흐른다.
struct NumberPadView: View {
    let panelWidth: CGFloat
    let keyHeight: CGFloat
    let onDigit: (String) -> Void
    let onBackspacePressStart: () -> Void
    let onBackspacePressEnd: () -> Void

    @ObservedObject private var settings = KeyboardSettings.shared

    private var keyWidth: CGFloat {
        let spacing = KeyboardMetrics.keySpacing
        return (panelWidth - spacing * 2) / 3
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.keySpacing) {
            ForEach(Array(KeyboardMetrics.numberPadKeys.enumerated()), id: \.offset) { _, row in
                HStack(spacing: KeyboardMetrics.keySpacing) {
                    ForEach(row, id: \.self) { key in
                        keyView(for: key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(for key: String) -> some View {
        let theme = settings.themeSettings
        if key == KeyboardMetrics.numberPadBackspaceLabel {
            Text(key)
                .font(.system(size: 22))
                .frame(width: keyWidth, height: keyHeight)
                .background(RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(theme.resolvedFunctionKeyBackground))
                .foregroundColor(theme.resolvedKeyText)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in }   // press-and-hold handled by onLongPress below
                )
                .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                    if pressing { onBackspacePressStart() } else { onBackspacePressEnd() }
                }, perform: {})
        } else {
            Button(action: { onDigit(key) }) {
                Text(key)
                    .font(.system(size: 22))
                    .frame(width: keyWidth, height: keyHeight)
                    .background(RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                        .fill(theme.resolvedKeyBackground))
                    .foregroundColor(theme.resolvedKeyText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
```

비고: `themeSettings.resolvedKeyBackground` / `resolvedKeyText` / `resolvedFunctionKeyBackground` 는 기존 `ThemeSettings` 의 computed 색상(`ConsonantKeyView` 가 쓰는 것과 동일). 실제 이름이 다르면 `ConsonantKeyView.swift` 에서 사용하는 정확한 프로퍼티명으로 교체.

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild build -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`. (resolved* 프로퍼티명 불일치 시 `ConsonantKeyView.swift` 의 이름으로 수정 후 재빌드.)

- [ ] **Step 3: 커밋**

```bash
git add MoaPlusKeyboard/Views/NumberPadView.swift
git commit -m "feat(ipad): NumberPadView (calculator-style 3x4)"
```

---

### Task 6: KeyboardView 분리 레이아웃 분기

**Files:**
- Modify: `MoaPlusKeyboard/Views/KeyboardView.swift` (body 의 `VStack { 추상화바 + KeyGridView + FunctionRowView }` 영역, line 37-141 근처)
- 빌드 + 수동(iPad 시뮬레이터) 검증.

**Interfaces:**
- Consumes: `KeyboardMetrics.usesIPadSplit`, `KeyboardMetrics.isLandscapeKeyboard`, `KeyGridView`(기존 시그니처), `FunctionRowView`(기존), `NumberPadView`(Task 5), `LayoutCustomization.numberPadSide`(Task 3).

- [ ] **Step 1: KeyGridView/FunctionRowView 호출을 헬퍼로 추출**

현재 `body` 의 `VStack` 안에 인라인된 `KeyGridView(...)`(line 51-105)와 `FunctionRowView(...)`(line 108-139) 호출을, `KeyboardView` 에 아래 두 함수로 추출(콜백 내용은 그대로 이동):

```swift
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
```

- [ ] **Step 2: 분리 판정 + 분기 추가**

`body` 의 `GeometryReader { geometry in ... }` 안, `centerKeyWidth`/`keyHeight` let 아래에 추가:

```swift
            let screen = UIScreen.main.bounds
            let screenShort = min(screen.width, screen.height)
            let screenLong = max(screen.width, screen.height)
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let isLandscape = KeyboardMetrics.isLandscapeKeyboard(
                keyboardWidth: geometry.size.width, screenShort: screenShort, screenLong: screenLong)
            let useSplit = KeyboardMetrics.usesIPadSplit(isPad: isPad, isLandscape: isLandscape)
                && viewModel.keyboardMode == .korean
```

기존 `VStack(spacing: KeyboardMetrics.keySpacing) { 추상화바; KeyGridView(...); FunctionRowView(...) }` 를 아래로 교체(추상화바는 양쪽 공통 상단 유지):

```swift
                    VStack(spacing: KeyboardMetrics.keySpacing) {
                        if viewModel.isAbbreviationCandidateVisible,
                           !viewModel.abbreviationCandidates.isEmpty {
                            AbbreviationCandidateView(
                                trigger: viewModel.abbreviationCandidates.first?.trigger ?? "",
                                candidates: viewModel.abbreviationCandidates,
                                onConfirm: { viewModel.confirmAbbreviation($0) },
                                onDismiss: { viewModel.dismissAbbreviation() }
                            )
                        }

                        if useSplit {
                            let spacing = KeyboardMetrics.keySpacing
                            let numpadWidth = (geometry.size.width - spacing * 3) * 0.31
                            let moakiWidth = (geometry.size.width - spacing * 3) * 0.69
                            let moakiCenterKeyWidth = KeyboardMetrics.centerKeyWidth(
                                for: moakiWidth, columnCount: 7, mode: .korean)
                            let numpad = NumberPadView(
                                panelWidth: numpadWidth,
                                keyHeight: keyHeight,
                                onDigit: { viewModel.inputSymbol($0) },
                                onBackspacePressStart: { viewModel.beginBackspacePress() },
                                onBackspacePressEnd: { viewModel.endBackspacePress() }
                            )
                            HStack(spacing: spacing) {
                                if settings.layoutCustomization.numberPadSide == .left {
                                    numpad.frame(width: numpadWidth)
                                    keyGrid(centerKeyWidth: moakiCenterKeyWidth, keyHeight: keyHeight, totalWidth: moakiWidth)
                                        .frame(width: moakiWidth)
                                } else {
                                    keyGrid(centerKeyWidth: moakiCenterKeyWidth, keyHeight: keyHeight, totalWidth: moakiWidth)
                                        .frame(width: moakiWidth)
                                    numpad.frame(width: numpadWidth)
                                }
                            }
                            functionRow(totalWidth: geometry.size.width)
                        } else {
                            keyGrid(centerKeyWidth: centerKeyWidth, keyHeight: keyHeight, totalWidth: geometry.size.width)
                            functionRow(totalWidth: geometry.size.width)
                        }
                    }
                    .padding(KeyboardMetrics.keySpacing)
```

비고: 롱프레스 팝업 좌표 계산(line 152-)은 분리 시 모아키 패널이 우측으로 밀려 어긋날 수 있으나, 분리 레이아웃은 슬롯B/자음 팝업을 그대로 쓰므로 1차 구현에선 기존 코드 유지. 팝업 위치 보정은 수동 검증 후 필요 시 후속(미해결로 명시).

- [ ] **Step 3: 빌드 확인**

Run: `xcodebuild build -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: 아이폰 회귀 자동 검증**

Run: `xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoaPlusKeyboardTests`
Expected: 전체 PASS (아이폰 경로 `useSplit=false` 유지 → 기존 동작 불변).

- [ ] **Step 5: 커밋**

```bash
git add MoaPlusKeyboard/Views/KeyboardView.swift
git commit -m "feat(ipad): split layout branch in KeyboardView (landscape only)"
```

---

### Task 7: KeyboardViewController 동적 높이 + 회전 대응

**Files:**
- Modify: `MoaPlusKeyboard/KeyboardViewController.swift` (line 35-54 높이 제약, line 71-82 viewWillAppear)
- 빌드 + 수동(iPad 시뮬레이터 회전) 검증.

**Interfaces:**
- Consumes: `KeyboardMetrics.keyboardHeight(isPad:isLandscape:screenShort:screenLong:)`(Task 1), `KeyboardMetrics.isLandscapeKeyboard`(Task 2).

- [ ] **Step 1: 높이 계산 헬퍼 추가** — `KeyboardViewController` 에 메서드 추가:

```swift
    private func computedKeyboardHeight() -> CGFloat {
        let bounds = UIScreen.main.bounds
        let screenShort = min(bounds.width, bounds.height)
        let screenLong = max(bounds.width, bounds.height)
        let isPad = traitCollection.userInterfaceIdiom == .pad
        // 키보드 폭 = 현재 화면 폭. 레이아웃 전이면 UIScreen 폭으로 폴백.
        let width = view.bounds.width > 0 ? view.bounds.width : bounds.width
        let isLandscape = KeyboardMetrics.isLandscapeKeyboard(
            keyboardWidth: width, screenShort: screenShort, screenLong: screenLong)
        return KeyboardMetrics.keyboardHeight(
            isPad: isPad, isLandscape: isLandscape, screenShort: screenShort, screenLong: screenLong)
    }
```

- [ ] **Step 2: viewDidLoad / viewWillAppear 에서 사용**

(a) `viewDidLoad` 의 `constant: KeyboardMetrics.keyboardHeight` (line 44) 를:
```swift
            constant: computedKeyboardHeight()
```
(b) `viewWillAppear` 의 `heightConstraint?.constant = KeyboardMetrics.keyboardHeight` (line 81) 를:
```swift
        heightConstraint?.constant = computedKeyboardHeight()
```

- [ ] **Step 3: 회전 대응 오버라이드 추가** — `viewDidAppear` 아래에 추가:

```swift
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            let bounds = UIScreen.main.bounds
            let screenShort = min(bounds.width, bounds.height)
            let screenLong = max(bounds.width, bounds.height)
            let isPad = self.traitCollection.userInterfaceIdiom == .pad
            let isLandscape = KeyboardMetrics.isLandscapeKeyboard(
                keyboardWidth: size.width, screenShort: screenShort, screenLong: screenLong)
            self.heightConstraint?.constant = KeyboardMetrics.keyboardHeight(
                isPad: isPad, isLandscape: isLandscape, screenShort: screenShort, screenLong: screenLong)
        })
    }
```

- [ ] **Step 4: 빌드 + 아이폰 회귀 확인**

Run: `xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoaPlusKeyboardTests`
Expected: PASS (아이폰 `isPad=false` → 260 유지). 추가로 빌드 성공.

- [ ] **Step 5: 수동 검증 (iPad 시뮬레이터)**

iPad 시뮬레이터에서 앱 실행 → 키보드 띄움 → 세로/가로 회전 시 높이 갱신·분리 전환 확인. (사용자 실기기 없음 → 시뮬레이터 필수.)

- [ ] **Step 6: 커밋**

```bash
git add MoaPlusKeyboard/KeyboardViewController.swift
git commit -m "feat(ipad): dynamic height in controller + rotation handling"
```

---

### Task 8: 설정 UI — 숫자패드 좌/우 토글

**Files:**
- Modify: `MoaPlus/Settings/LayoutCustomizationView.swift`
- 빌드 + 수동 검증.

**Interfaces:**
- Consumes: `LayoutCustomization.numberPadSide`(Task 3), `KeyboardSettings.shared`.

- [ ] **Step 1: 파일 구조 확인**

`LayoutCustomizationView.swift` 를 열어 기존 설정 바인딩 패턴(예: `slotB` Picker / Toggle, `KeyboardSettings.shared.layoutCustomization.xxx` 를 set 하는 방식)을 확인하고 삽입 지점을 정한다. 기존 컨트롤이 `Binding(get:set:)` 로 `KeyboardSettings.shared.layoutCustomization` 을 갱신하는 패턴을 그대로 따른다.

- [ ] **Step 2: 바인딩 + Picker 추가**

뷰에 바인딩 computed 추가(기존 패턴에 맞춰):
```swift
    private var numberPadSideBinding: Binding<NumberPadSide> {
        Binding(
            get: { KeyboardSettings.shared.layoutCustomization.numberPadSide },
            set: { KeyboardSettings.shared.layoutCustomization.numberPadSide = $0 }
        )
    }
```
적절한 `Section` 안에 컨트롤 추가:
```swift
                Picker("iPad 가로 숫자패드 위치", selection: numberPadSideBinding) {
                    Text("왼쪽").tag(NumberPadSide.left)
                    Text("오른쪽").tag(NumberPadSide.right)
                }
                .pickerStyle(.segmented)
                Text("아이패드를 가로로 쓸 때 숫자패드를 어느 쪽에 둘지 선택합니다.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
```

- [ ] **Step 3: 빌드 확인**

Run: `xcodebuild build -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`. (`KeyboardSettings.shared.layoutCustomization` set 이 `@Published`/`objectWillChange` 로 영속되는지 기존 컨트롤과 동일하게 동작하는지 확인.)

- [ ] **Step 4: 수동 검증**

설정에서 좌/우 전환 → 앱 재진입/키보드 재로딩 시 유지되는지 확인.

- [ ] **Step 5: 커밋**

```bash
git add MoaPlus/Settings/LayoutCustomizationView.swift
git commit -m "feat(ipad): settings toggle for number pad side"
```

---

## Self-Review (작성자 점검 완료)

- **Spec coverage:** 동적 높이(T1,T7) / 방향·분리 판정(T2) / 분리 레이아웃(T6) / NumberPadView(T4,T5) / numberPadSide 설정(T3,T8) / 아이폰 회귀 가드(T1,T2,T6,T7 테스트) — 전부 태스크 매핑됨.
- **Spec 정정:** 분리 판정을 `width>height`(키보드 기하상 항상 참) → `isLandscapeKeyboard`(키보드 폭이 장축인지)로 교체. T2에 반영.
- **Type consistency:** `keyboardHeight(isPad:isLandscape:screenShort:screenLong:)`, `isLandscapeKeyboard(keyboardWidth:screenShort:screenLong:)`, `usesIPadSplit(isPad:isLandscape:)`, `numberPadKeys`, `NumberPadSide`, `NumberPadView(panelWidth:keyHeight:onDigit:onBackspacePressStart:onBackspacePressEnd:)` — 태스크 간 시그니처 일치.
- **알려진 미해결(수동 검증 후 후속):** 분리 시 롱프레스 팝업 X좌표 보정(모아키가 우측으로 밀림), `NumberPadView` 의 `theme.resolved*` 프로퍼티명은 `ConsonantKeyView` 실제 이름과 대조 필요.

## 비범위 / 후속
- 아이폰 가로 높이 축소 / 아이패드 세로 분리 / 그리드 폭 캡 — 이번 plan 제외.
- 분리 레이아웃의 롱프레스 팝업 좌표 보정 — 수동 검증 후 필요 시.

<!-- /autoplan restore point: /Users/ock_mini/.gstack/projects/koh0001-moa-plus/main-autoplan-restore-20260508-225931.md -->
# 키보드 레이아웃 커스터마이즈 — 구현 계획 (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spec [`docs/superpowers/specs/2026-05-08-keyboard-layout-customization-design.md`] v2 의 3 슬롯 레이아웃 커스터마이즈 (슬롯 A 2 프리셋 + swap 토글, 슬롯 B 2 프리셋, 슬롯 C 셀 단위 매핑) + 첫 실행 모달 + 설정 화면 슬롯 시각 표시. 1.3 사용자 무중단 마이그레이션.

**Architecture:**
1. `LayoutCustomization` Codable struct 가 슬롯 상태 + swap 토글 보유
2. `KeyboardMetrics.koreanLayout(_:)` 가 layout 을 받아 [[KeyContent]] 산출
3. `KeyboardSettings.shared.layoutCustomization` 변경 시 `@Published` 통해 KeyboardView/Preview 즉시 갱신
4. 첫 실행 모달은 `firstLaunchModalShown` flag 로 1 회만 표시
5. 설정 화면에 라이브 KeyboardPreviewView + 슬롯 영역 강조 overlay

**Tech Stack:** Swift 5+, SwiftUI, Combine, App Group `group.com.moaki.keyboard` UserDefaults, JSONEncoder/Decoder. iOS 키보드 익스텐션 메모리 ~30MB 제약.

**v2 변경:** A3 (풀 패키지) 제거. A1 에 백스페이스 ↔ ㆍ swap 토글 추가. 첫 실행 모달 + 슬롯 시각 표시 신규.

---

## File Structure

### Create
| 경로 | 책임 |
|---|---|
| `MoaPlusKeyboard/Models/LayoutCustomization.swift` | 데이터 모델 |
| `MoaPlus/Settings/LayoutCustomizationView.swift` | 설정 화면 (라이브 프리뷰 + 슬롯 하이라이트) |
| `MoaPlus/Views/FirstLaunchLayoutModalView.swift` | 첫 실행 모달 |
| `MoaPlusKeyboardTests/LayoutCustomizationTests.swift` | 모델 단위 테스트 |
| `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift` | 레이아웃 산출 검증 |

### Modify
| 경로 | 변경 |
|---|---|
| `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift` | `KeyContent.backspaceWide` 추가, `koreanLayout(_:)` 함수 |
| `MoaPlusKeyboard/Utilities/KeyboardSettings.swift` | `layoutCustomization` + `firstLaunchModalShown` |
| `MoaPlusKeyboard/Views/KeyboardView.swift` | layoutCustomization → KeyGridView 전달 |
| `MoaPlusKeyboard/Views/ConsonantGridView.swift` | wide bksp grid span |
| `MoaPlusKeyboard/Views/ConsonantKeyView.swift` | `backspaceWide` 렌더 |
| `MoaPlusKeyboard/ViewModels/KeyboardViewModel.swift` | 슬롯 B 모음 키 핸들러 |
| `MoaPlusKeyboard/Views/FunctionRowView.swift` | 슬롯 B 가 `.vowelKey` 일 때 자음드래그 패턴 키 렌더 |
| `MoaPlus/Settings/InputSettingsView.swift` | "레이아웃 커스터마이즈" NavigationLink |
| `MoaPlus/ContentView.swift` | 첫 실행 모달 시트 연결 |

---

## Task 1: LayoutCustomization 모델 + Codable 테스트

**Files:**
- Create: `MoaPlusKeyboard/Models/LayoutCustomization.swift`
- Create: `MoaPlusKeyboardTests/LayoutCustomizationTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
import XCTest
@testable import MoaPlusKeyboard

final class LayoutCustomizationTests: XCTestCase {
    func testDefaultMatches13Behavior() {
        let layout = LayoutCustomization()
        XCTAssertEqual(layout.slotA, .vowel)
        XCTAssertFalse(layout.slotABackspaceSwap)
        XCTAssertEqual(layout.slotB, .punctuation)
        XCTAssertEqual(layout.slotC, ["~", "^", ";", "*"])
    }

    func testCodableRoundTrip() throws {
        var original = LayoutCustomization()
        original.slotA = .classic11
        original.slotABackspaceSwap = true
        original.slotB = .vowelKey
        original.slotC = ["@", "#", "$", "%"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSlotCMustHaveFourElements() {
        let json = #"{"slotA":"vowel","slotB":"punctuation","slotC":["a","b"]}"#
        let data = json.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded?.slotC.count, 4)
    }

    func testSwapDefaultIsFalse() {
        let json = #"{"slotA":"vowel","slotB":"punctuation","slotC":["~","^",";","*"]}"#
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertFalse(decoded.slotABackspaceSwap, "swap 필드 없는 디스크 데이터는 false 로 시작")
    }
}
```

- [ ] **Step 2: 테스트 실행 (FAIL)** — `LayoutCustomization` 미정의 컴파일 에러.

- [ ] **Step 3: 모델 구현**

```swift
import Foundation

enum SlotAPreset: String, Codable, CaseIterable {
    case vowel        // A1 — 모음 (기본, 1.3)
    case classic11    // A2 — 1.1 특수문자
}

enum SlotBPreset: String, Codable, CaseIterable {
    case punctuation  // B2 — 특수문자 (기본, 1.3)
    case vowelKey     // B1 — 자음드래그 패턴 모음 키
}

struct LayoutCustomization: Codable, Equatable {
    var slotA: SlotAPreset = .vowel
    /// A1 일 때 백스페이스 ↔ ㆍ 위치 swap. A2 일 때 무시.
    var slotABackspaceSwap: Bool = false
    var slotB: SlotBPreset = .punctuation
    var slotC: [String] = LayoutCustomization.defaultSlotC

    static let defaultSlotC: [String] = ["~", "^", ";", "*"]

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slotA = try c.decodeIfPresent(SlotAPreset.self, forKey: .slotA) ?? .vowel
        slotABackspaceSwap = try c.decodeIfPresent(Bool.self, forKey: .slotABackspaceSwap) ?? false
        slotB = try c.decodeIfPresent(SlotBPreset.self, forKey: .slotB) ?? .punctuation
        let raw = try c.decodeIfPresent([String].self, forKey: .slotC) ?? Self.defaultSlotC
        slotC = Self.normalizeSlotC(raw)
    }

    private static func normalizeSlotC(_ raw: [String]) -> [String] {
        var result = raw.prefix(4).map { $0.isEmpty ? " " : $0 }
        while result.count < 4 { result.append(defaultSlotC[result.count]) }
        return Array(result)
    }

    private enum CodingKeys: String, CodingKey {
        case slotA, slotABackspaceSwap, slotB, slotC
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**
- [ ] **Step 5: 메인 앱 타겟 멤버십 추가**: `ruby scripts/add_target_membership.rb MoaPlusKeyboard/Models/LayoutCustomization.swift`
- [ ] **Step 6: Commit**: `feat: add LayoutCustomization model with Codable normalization`

---

## Task 2: KeyContent.backspaceWide 케이스 추가

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`

- [ ] **Step 1: KeyContent 에 한 케이스 추가**

```swift
enum KeyContent: Equatable {
    case consonant(Choseong)
    case symbol(String)
    case backspace
    case vowelPrimitive(VowelPrimitiveType)
    case functional(FunctionalKeyType)
    case systemSwitch
    case quickPunctuation(String)

    case backspaceWide       // A2 의 row 3 가로 2칸 ⌫
}
```

- [ ] **Step 2: 빌드해서 exhaustive switch 에러 모두 찾기 + placeholder 처리**

`ConsonantGridView.swift` 의 `secondaryKeyId` 클로저 / `longPressNumber` 클로저에 `.backspaceWide` 추가 (둘 다 빈 문자열 / nil 반환).

`ConsonantKeyView.swift` 의 `keyLabel` 분기:
```swift
case .backspaceWide:
    AnyView(Image(systemName: "delete.left").font(.system(size: 20)))
```

`isBackspaceKey` computed 업데이트:
```swift
var isBackspaceKey: Bool {
    if case .backspace = content { return true }
    if case .backspaceWide = content { return true }
    return false
}
```

- [ ] **Step 3: 빌드 + 기존 테스트 PASS 확인**
- [ ] **Step 4: Commit**: `feat: add KeyContent.backspaceWide case (placeholder render)`

---

## Task 3: koreanLayout(_:) 함수 + A1 + swap 분기

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`
- Create: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift`

- [ ] **Step 1: 테스트 작성**

```swift
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
}
```

- [ ] **Step 2: 테스트 실행 (FAIL)** — `koreanLayout(_:)` 미구현.

- [ ] **Step 3: A1 분기 구현**

```swift
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
        fatalError("Implemented in Task 4")
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**
- [ ] **Step 5: Commit**: `feat: add koreanLayout(_:) with A1 + backspace swap`

---

## Task 4: A2 (1.1 특수문자) 분기 + 가로 백스페이스

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`
- Modify: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift`

- [ ] **Step 1: A2 테스트 추가**

```swift
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
```

- [ ] **Step 2: 테스트 실행 (FAIL)**

- [ ] **Step 3: A2 케이스 구현**

```swift
case .classic11:
    return [
        [leftCol[0], .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol("!")],
        [leftCol[1], .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .symbol("?")],
        [leftCol[2], .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .symbol(".")],
        [leftCol[3], .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspaceWide],
    ]
```

- [ ] **Step 4: Commit**: `feat: add A2 (1.1 classic) layout with wide backspace`

---

## Task 5: Wide backspace 폭 + columnCount 처리

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`
- Modify: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift`

- [ ] **Step 1: 폭 계산 테스트 추가**

```swift
func testKeyWidth_backspaceWideIsTwoCellsPlusGap() {
    let centerWidth: CGFloat = 40.0
    let normal = KeyboardMetrics.keyWidth(for: 5, row: 3, centerKeyWidth: centerWidth, mode: .korean)
    let wide = KeyboardMetrics.keyWidth(forBackspaceWideAt: 5, centerKeyWidth: centerWidth)
    XCTAssertEqual(wide, normal * 2 + KeyboardMetrics.keySpacing, accuracy: 0.01)
}
```

- [ ] **Step 2: 폭 계산 구현**

```swift
static func keyWidth(forBackspaceWideAt column: Int, centerKeyWidth: CGFloat) -> CGFloat {
    return centerKeyWidth * 2 + keySpacing
}
```

- [ ] **Step 3: Commit**: `feat: add wide-backspace width helper`

---

## Task 6: longPressNumbers — 레이아웃 인지

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`
- Modify: `MoaPlusKeyboardTests/KeyboardMetricsLayoutTests.swift`

- [ ] **Step 1: 테스트**

```swift
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
```

- [ ] **Step 2: 함수 추가**

```swift
static func longPressNumber(at row: Int, column: Int, layout: LayoutCustomization) -> String? {
    if column == 6 {
        switch layout.slotA {
        case .vowel:        return longPressNumber(at: row, column: column)
        case .classic11:    return nil
        }
    }
    return longPressNumber(at: row, column: column)
}
```

- [ ] **Step 3: Commit**: `feat: layout-aware long-press number lookup`

---

## Task 7: KeyboardSettings 통합 (layoutCustomization + firstLaunchModalShown)

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardSettings.swift`
- Create: `MoaPlusKeyboardTests/KeyboardSettingsLayoutTests.swift`

- [ ] **Step 1: 테스트**

```swift
import XCTest
@testable import MoaPlusKeyboard

final class KeyboardSettingsLayoutTests: XCTestCase {
    func testDefaultLayoutCustomizationIsV13() {
        let s = KeyboardSettings.shared
        XCTAssertEqual(s.layoutCustomization.slotA, .vowel)
        XCTAssertFalse(s.layoutCustomization.slotABackspaceSwap)
        XCTAssertEqual(s.layoutCustomization.slotB, .punctuation)
    }

    func testFirstLaunchFlagDefaultFalse() {
        XCTAssertFalse(KeyboardSettings.shared.firstLaunchModalShown)
    }

    func testRoundTripPersistsAcrossLoadAll() {
        let s = KeyboardSettings.shared
        var custom = LayoutCustomization()
        custom.slotA = .classic11
        custom.slotABackspaceSwap = true
        s.layoutCustomization = custom
        s.loadAll()
        XCTAssertEqual(s.layoutCustomization.slotA, .classic11)
        XCTAssertTrue(s.layoutCustomization.slotABackspaceSwap)
        s.layoutCustomization = LayoutCustomization()
    }
}
```

- [ ] **Step 2: KeyboardSettings 변경**

```swift
private enum Keys {
    // ... 기존 ...
    static let layoutCustomization = "layoutCustomization"
    static let firstLaunchModalShown = "firstLaunchModalShown"
}

@Published var layoutCustomization: LayoutCustomization = LayoutCustomization() {
    didSet {
        guard !isLoading else { return }
        save(layoutCustomization, forKey: Keys.layoutCustomization)
    }
}

@Published var firstLaunchModalShown: Bool = false {
    didSet {
        guard !isLoading else { return }
        writePrimitive(firstLaunchModalShown, forKey: Keys.firstLaunchModalShown)
    }
}

// loadAll() 추가:
layoutCustomization = load(LayoutCustomization.self, forKey: Keys.layoutCustomization) ?? LayoutCustomization()
firstLaunchModalShown = defaults.bool(forKey: Keys.firstLaunchModalShown)

// resetAll() 추가:
layoutCustomization = LayoutCustomization()
firstLaunchModalShown = false
```

- [ ] **Step 3: Commit**: `feat: persist LayoutCustomization + first-launch flag`

---

## Task 8: KeyboardView/KeyGridView 가 layoutCustomization 소비

**Files:**
- Modify: `MoaPlusKeyboard/Utilities/KeyboardMetrics.swift`
- Modify: `MoaPlusKeyboard/Views/KeyboardView.swift`
- Modify: `MoaPlusKeyboard/Views/ConsonantGridView.swift`

- [ ] **Step 1: KeyboardMetrics.activeLayout(for:layout:) 추가**

```swift
static func activeLayout(for mode: KeyboardMode, layout: LayoutCustomization) -> [[KeyContent]] {
    switch mode {
    case .korean: return koreanLayout(layout)
    case .english: return englishLayout
    case .symbolFromKorean, .symbolFromEnglish: return symbolLayout
    }
}
```

- [ ] **Step 2: KeyGridView 시그니처에 layoutCustomization 추가**

```swift
struct KeyGridView: View {
    let centerKeyWidth: CGFloat
    let keyHeight: CGFloat
    let totalWidth: CGFloat
    let mode: KeyboardMode
    let layoutCustomization: LayoutCustomization   // 신규
    // ... 기존 ...
}
```

`columnCount(for:row:mode:)` / `keyContent(at:row:column:mode:)` 호출 → `activeLayout(for:mode:layout:)` 사용으로 변경.

- [ ] **Step 3: KeyboardView 가 settings.layoutCustomization 전달**

```swift
KeyGridView(
    centerKeyWidth: centerKeyWidth,
    keyHeight: keyHeight,
    totalWidth: geometry.size.width,
    mode: viewModel.keyboardMode,
    layoutCustomization: settings.layoutCustomization,  // 신규
    // ... 기존 ...
)
```

- [ ] **Step 4: 빌드 + 기존 테스트 PASS**
- [ ] **Step 5: Commit**: `feat: thread LayoutCustomization through grid rendering`

---

## Task 9: backspaceWide 그리드 렌더링 (실제 동작)

**Files:**
- Modify: `MoaPlusKeyboard/Views/ConsonantGridView.swift`

- [ ] **Step 1: cellWidth 헬퍼 추가** (Task 5 의 keyWidth 함수 사용)

```swift
private func cellWidth(content: KeyContent, column: Int, row: Int) -> CGFloat {
    if case .backspaceWide = content {
        return KeyboardMetrics.keyWidth(forBackspaceWideAt: column, centerKeyWidth: centerKeyWidth)
    }
    return KeyboardMetrics.keyWidth(for: column, row: row, centerKeyWidth: centerKeyWidth, mode: mode)
}
```

`body` 의 `let width = ...` 호출 + `rowWidth(for:)` 모두 `cellWidth` 사용으로 교체.

- [ ] **Step 2: 시뮬레이터 수동 확인** — `settings.layoutCustomization.slotA = .classic11` 임시 set 후 row 3 백스페이스 가로 길어진 모습 + 백스페이스 long-press word delete 정상 동작 확인.
- [ ] **Step 3: Commit**: `feat: render backspaceWide spanning 2 columns`

---

## Task 10: 슬롯 B 모음 키 (B1) — 펑크션 행에서

**Files:**
- Modify: `MoaPlusKeyboard/Views/FunctionRowView.swift`
- Modify: `MoaPlusKeyboard/ViewModels/KeyboardViewModel.swift`
- Modify: `MoaPlusKeyboardTests/KeyboardViewModelVowelDragTests.swift`

- [ ] **Step 1: ViewModel 핸들러 테스트**

```swift
func testSlotBVowelKey_tapInsertsDot() {
    let vm = KeyboardViewModel()
    vm.handleSlotBVowelKey(direction: nil)
    XCTAssertEqual(vm.composer.standaloneVowel, .ㆍ)
}

func testSlotBVowelKey_rightDragInsertsA() {
    let vm = KeyboardViewModel()
    vm.handleSlotBVowelKey(direction: .right)
    XCTAssertEqual(vm.composer.standaloneVowel, .ㅏ)
}
```

- [ ] **Step 2: ViewModel 구현**

```swift
func handleSlotBVowelKey(direction: GestureDirection?) {
    guard let direction = direction else {
        composer.combineVowel(.ㆍ)
        emitComposingText()
        return
    }
    let vowel = VowelResolver.shared.resolveSingleStroke(direction: direction,
                                                         settings: settings.gestureSettings)
    if let vowel = vowel {
        composer.combineVowel(vowel)
        emitComposingText()
    }
}
```

(`VowelResolver.resolveSingleStroke` 가 없으면 기존 `resolve(directions:)` 의 단일 스트로크 결과 추출 함수 추가.)

- [ ] **Step 3: FunctionRowView 의 슬롯 B 키를 layoutCustomization 에 따라 분기**

```swift
struct FunctionRowView: View {
    // ... 기존 ...
    let layoutCustomization: LayoutCustomization   // 신규
    var onSlotBVowelKey: ((GestureDirection?) -> Void)? = nil

    private var defaultLayoutBody: some View {
        HStack(spacing: spacing) {
            FunctionKeyView(... 123 ...)
            FunctionKeyView(... 한 ...)
            SpaceKeyView(...)
            // 슬롯 B 분기
            switch layoutCustomization.slotB {
            case .punctuation:
                PunctuationSwipeKey(width: punctuationWidth, height: height,
                                    onPunctuation: onPunctuation)
            case .vowelKey:
                SlotBVowelKey(width: punctuationWidth, height: height,
                              onAction: onSlotBVowelKey ?? { _ in })
            }
            FunctionKeyView(... return ...)
        }
    }
}
```

`SlotBVowelKey` 신규 View — 기존 `PunctuationSwipeKey` 를 본떠서 8방향 GestureAnalyzer 사용.

- [ ] **Step 4: KeyboardView 가 layoutCustomization + onSlotBVowelKey 전달**
- [ ] **Step 5: 시뮬레이터 확인** — 슬롯 B 를 `.vowelKey` 로 set, 펑크션 행에서 ㆍ 키 동작 확인.
- [ ] **Step 6: Commit**: `feat: slot B vowel key with single-stroke direction mapping`

---

## Task 11: LayoutCustomizationView 설정 화면 (슬롯 시각 표시 + swap 토글)

**Files:**
- Create: `MoaPlus/Settings/LayoutCustomizationView.swift`

- [ ] **Step 1: 화면 구현**

```swift
import SwiftUI

struct LayoutCustomizationView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var highlightedSlot: HighlightedSlot? = nil
    @State private var editingCellIndex: Int? = nil
    @State private var cellEditText: String = ""
    @State private var showingCellEdit = false

    enum HighlightedSlot { case a, b, c }

    var body: some View {
        List {
            Section {
                ZStack {
                    KeyboardPreviewView()
                    SlotHighlightOverlay(slot: highlightedSlot)
                }
                .padding(.vertical, 4)
            } header: {
                Text("미리보기")
            }

            // 슬롯 A
            Section {
                radioRow(.vowel, title: "모음 (현재)", desc: "⌫ + ㅣ ㅡ ㆍ")
                radioRow(.classic11, title: "1.1 특수문자", desc: "! ? . + 가로 ⌫")
                if settings.layoutCustomization.slotA == .vowel {
                    Toggle("백스페이스 ↔ ㆍ 위치 swap", isOn: Binding(
                        get: { settings.layoutCustomization.slotABackspaceSwap },
                        set: { newValue in
                            var c = settings.layoutCustomization
                            c.slotABackspaceSwap = newValue
                            settings.layoutCustomization = c
                        }
                    ))
                }
            } header: {
                Button(action: { highlightedSlot = .a }) {
                    HStack {
                        Text("우측 컬럼 (슬롯 A)")
                        Image(systemName: "rectangle.portrait.righthalf.filled")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            } footer: {
                Text("우측 끝 컬럼의 키 매핑.")
            }

            // 슬롯 B
            Section {
                slotBRow(.punctuation, title: "특수문자 (현재)", desc: "tap=. ←=? →=! ↑=, ↓=.")
                slotBRow(.vowelKey, title: "모음 키", desc: "tap=ㆍ + 8방향 모음")
            } header: {
                Button(action: { highlightedSlot = .b }) {
                    HStack {
                        Text("스페이스 옆 키 (슬롯 B)")
                        Image(systemName: "rectangle.bottomthird.inset.filled")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }

            // 슬롯 C
            Section {
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Text("\(i+1)번 셀 (row \(i))")
                        Spacer()
                        Button(settings.layoutCustomization.slotC[i]) {
                            startCellEdit(index: i)
                        }
                        .font(.system(size: 16, weight: .medium))
                    }
                }
                Button("기본값으로 초기화", action: resetSlotC).foregroundColor(.red)
            } header: {
                Button(action: { highlightedSlot = .c }) {
                    HStack {
                        Text("좌측 컬럼 (슬롯 C)")
                        Image(systemName: "rectangle.portrait.lefthalf.filled")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            } footer: {
                Text("각 셀에 1~4 자 문자.")
            }
        }
        .navigationTitle("레이아웃 커스터마이즈")
        .alert("셀 편집", isPresented: $showingCellEdit) {
            TextField("문자", text: $cellEditText)
            Button("취소", role: .cancel) {}
            Button("저장", action: commitCellEdit)
        } message: {
            Text("1~4 자 입력")
        }
    }

    @ViewBuilder
    private func radioRow(_ preset: SlotAPreset, title: String, desc: String) -> some View {
        Button(action: {
            var c = settings.layoutCustomization
            c.slotA = preset
            settings.layoutCustomization = c
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    Text(desc).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if settings.layoutCustomization.slotA == preset {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func slotBRow(_ preset: SlotBPreset, title: String, desc: String) -> some View { /* 동일 패턴 */ }

    private func startCellEdit(index: Int) { /* ... */ }
    private func commitCellEdit() {
        guard let i = editingCellIndex else { return }
        let trimmed = String(cellEditText.prefix(4))
        guard !trimmed.isEmpty else { return }
        var c = settings.layoutCustomization
        c.slotC[i] = trimmed
        settings.layoutCustomization = c
        editingCellIndex = nil
    }
    private func resetSlotC() {
        var c = settings.layoutCustomization
        c.slotC = LayoutCustomization.defaultSlotC
        settings.layoutCustomization = c
    }
}

struct SlotHighlightOverlay: View {
    let slot: LayoutCustomizationView.HighlightedSlot?

    var body: some View {
        GeometryReader { geo in
            Group {
                switch slot {
                case .a: highlightRect(in: geo, fraction: .right)
                case .b: highlightRect(in: geo, fraction: .bottom)
                case .c: highlightRect(in: geo, fraction: .left)
                case nil: EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: slot)
        }
    }
    // ... 슬롯 영역 좌표 계산 + RoundedRectangle 강조 ...
}
```

- [ ] **Step 2: SlotHighlightOverlay 좌표 계산** — 키보드 비율 기반 (col 6 / 펑크션 행 / col 0). 정확한 픽셀 매칭은 시뮬레이터에서 시각 확인.
- [ ] **Step 3: 시뮬레이터 확인** — 라이브 프리뷰 + 슬롯 변경 즉시 반영 + 헤더 탭 시 강조.
- [ ] **Step 4: Commit**: `feat: add LayoutCustomizationView with live preview + slot highlights`

---

## Task 12: SettingsMainView 재구성 (UX 통일 #1)

**Files:**
- Modify: `MoaPlus/Settings/SettingsMainView.swift`

- [ ] **Step 1: 새 IA 로 SettingsMainView 변경**

```swift
import SwiftUI

struct SettingsMainView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(destination: KeyboardSettingsView()) {
                    Label("키보드", systemImage: "keyboard")
                }
                NavigationLink(destination: AppearanceSettingsView()) {
                    Label("외형", systemImage: "paintbrush")
                }
                NavigationLink(destination: FeedbackSettingsView()) {
                    Label("반응", systemImage: "waveform")
                }
                NavigationLink(destination: AbbreviationSettingsView()) {
                    Label("단축어", systemImage: "text.badge.plus")
                }
            }
            Section {
                NavigationLink(destination: HelpView()) {
                    Label("도움말", systemImage: "questionmark.circle")
                }
                NavigationLink(destination: AboutView()) {
                    Label("앱 정보", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("설정")
    }
}
```

- [ ] **Step 2: 임시 stub 화면 추가** — `KeyboardSettingsView`, `HelpView` 가 아직 없으므로 컴파일 에러 방지용 빈 stub 추가:

```swift
// MoaPlus/Settings/_TempStubs.swift (이번 task 끝에 삭제)
struct KeyboardSettingsView: View { var body: some View { Text("TODO Task 13") } }
struct HelpView: View { var body: some View { Text("TODO Task 17") } }
```

- [ ] **Step 3: 빌드 PASS** — 메인 페이지 동작 확인 (stub 들 누르면 placeholder 표시)
- [ ] **Step 4: Commit**: `feat: restructure SettingsMainView to flat 6-item IA`

---

## Task 13: KeyboardSettingsView 신규 (입력 통합 허브)

**Files:**
- Create: `MoaPlus/Settings/KeyboardSettingsView.swift`

- [ ] **Step 1: 통합 hub 화면 작성**

```swift
import SwiftUI

struct KeyboardSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section {
                NavigationLink(destination: LayoutCustomizationView()) {
                    HStack {
                        Label("레이아웃", systemImage: "rectangle.3.group")
                        Spacer()
                        Text(layoutSummary).font(.caption).foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: GestureSettingsView()) {
                    HStack {
                        Label("제스처 (긋기)", systemImage: "hand.draw")
                        Spacer()
                        Text(gestureSummary).font(.caption).foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: LongPressSettingsView()) {
                    Label("롱프레스 (보조 매핑)", systemImage: "hand.tap")
                }
            } footer: {
                Text("키보드 입력 관련 모든 설정.")
            }

            Section {
                NavigationLink(destination: BackspaceSettingsView()) {
                    Label("백스페이스", systemImage: "delete.left")
                }
                NavigationLink(destination: InputBehaviorSettingsView()) {
                    Label("입력 동작", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("키보드")
    }

    private var layoutSummary: String {
        let c = settings.layoutCustomization
        switch c.slotA {
        case .vowel: return c.slotABackspaceSwap ? "모음 (swap)" : "모던"
        case .classic11: return "클래식 1.1"
        }
    }

    private var gestureSummary: String {
        let p = settings.gestureSettings.swipeProfile
        let mode: String = {
            switch p.mode {
            case .right: return "오른손"; case .left: return "왼손"
            case .both: return "양손"; case .custom: return "커스텀"
            }
        }()
        return "\(mode) · \(p.swipeLength.displayName)"
    }
}
```

- [ ] **Step 2: 임시 stub 추가** — `LongPressSettingsView`, `BackspaceSettingsView`, `InputBehaviorSettingsView` placeholder
- [ ] **Step 3: 빌드 + 동작 확인**
- [ ] **Step 4: Commit**: `feat: add KeyboardSettingsView hub for all input settings`

---

## Task 14: BackspaceSettingsView 신규 (속도 + 단어삭제 통합)

**Files:**
- Create: `MoaPlus/Settings/BackspaceSettingsView.swift`
- Modify: `MoaPlus/Settings/FeedbackSettingsView.swift` (백스페이스 섹션 제거)

- [ ] **Step 1: 신규 화면 작성**

```swift
import SwiftUI

struct BackspaceSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section {
                Picker("속도", selection: $settings.backspaceSpeed) {
                    Text("느리게").tag(0)
                    Text("보통").tag(1)
                    Text("빠르게").tag(2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("반복 속도")
            } footer: {
                Text("길게 누를 때 글자가 반복 삭제되는 속도입니다.")
            }

            Section {
                Toggle("단어 단위 삭제", isOn: $settings.wordDeleteEnabled)
                if settings.wordDeleteEnabled {
                    HStack {
                        Text("전환 시간")
                        Spacer()
                        Text("\(settings.wordDeleteDelay, specifier: "%.1f")초").foregroundColor(.secondary)
                    }
                    Slider(value: $settings.wordDeleteDelay, in: 0.8...3.0, step: 0.1)
                }
            } header: {
                Text("단어 단위 삭제")
            } footer: {
                Text(settings.wordDeleteEnabled
                    ? "백스페이스를 \(String(format: \"%.1f\", settings.wordDeleteDelay))초 이상 누르면 공백 단위로 빠르게 삭제합니다."
                    : "백스페이스를 길게 눌러도 한 글자씩만 삭제합니다.")
            }

            Section {
                NavigationLink(destination: LayoutCustomizationView()) {
                    HStack {
                        Text("백스페이스 위치 변경")
                        Spacer()
                        Text("레이아웃에서").font(.caption).foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("위치는 키보드 레이아웃 페이지에서 설정합니다.")
            }
        }
        .navigationTitle("백스페이스")
    }
}
```

- [ ] **Step 2: FeedbackSettingsView 의 백스페이스 섹션 제거** — `backspaceSpeed`, `wordDeleteEnabled`, `wordDeleteDelay` 관련 Section 모두 삭제. 햅틱/사운드 유지.

- [ ] **Step 3: 빌드 + 시뮬레이터 확인** — 백스페이스 페이지 진입 + Feedback 페이지엔 백스페이스 섹션 없음 확인
- [ ] **Step 4: Commit**: `feat: add BackspaceSettingsView (consolidates speed + word delete + position)`

---

## Task 15: InputBehaviorSettingsView 신규 (괄호 + 커서 드래그)

**Files:**
- Create: `MoaPlus/Settings/InputBehaviorSettingsView.swift`

- [ ] **Step 1: 신규 화면**

```swift
import SwiftUI

struct InputBehaviorSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section {
                Toggle("괄호 자동 닫기", isOn: $settings.autoBracketEnabled)
            } footer: {
                Text("( [ { 등 여는 괄호 입력 시 닫는 괄호를 자동 삽입하고 커서를 가운데에 놓습니다.")
            }

            Section {
                Toggle("스페이스 드래그로 커서 이동", isOn: $settings.cursorMoveBySpaceDragEnabled)
            } footer: {
                Text("스페이스바를 길게 누른 채 드래그하면 커서가 좌우로 이동합니다.")
            }
        }
        .navigationTitle("입력 동작")
    }
}
```

- [ ] **Step 2: Commit**: `feat: add InputBehaviorSettingsView (auto-bracket + cursor drag)`

---

## Task 16: LongPressSettingsView 신규 (기존 SecondaryInputSettingsView 정리)

**Files:**
- Create: `MoaPlus/Settings/LongPressSettingsView.swift` (기존 SecondaryInputSettingsView 의 내용 중 롱프레스만 남김)

- [ ] **Step 1: 새 파일에 롱프레스 관련 섹션만 복사**

```swift
import SwiftUI

struct LongPressSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var editingAction: SecondaryKeyAction?

    var body: some View {
        List {
            Section {
                Toggle("힌트 표시", isOn: $settings.showSecondaryHints)
                if settings.showSecondaryHints {
                    Picker("힌트 크기", selection: $settings.hintSize) {
                        Text("작게").tag(0); Text("보통").tag(1); Text("크게").tag(2)
                    }.pickerStyle(.segmented)
                    Toggle("전체 후보 표시", isOn: $settings.showDetailedHints)
                }
            } header: { Text("보조 힌트 표시") }
              footer: { Text(settings.showDetailedHints ? "각 키에 롱프레스 후보 문자가 모두 표시됩니다." : "각 자음 키에 대표 숫자/기호 힌트를 작게 표시합니다.") }

            Section {
                HStack {
                    Text("롱프레스 반응 시간")
                    Spacer()
                    Text("\(settings.longPressDelay, specifier: "%.1f")초").foregroundColor(.secondary)
                }
                Slider(value: $settings.longPressDelay, in: 0.2...1.0, step: 0.1)
            } header: { Text("롱프레스 속도") }
              footer: { Text("짧을수록 빠르게 보조 입력이 활성화됩니다. 기본값: 0.5초") }

            // 키 매핑 섹션 — SecondaryInputSettingsView 에서 그대로 복사
            // (괄호 자동 닫기 섹션은 InputBehaviorSettingsView 로 이동했으므로 여기 없음)
            Section {
                ForEach(settings.secondaryKeyActions) { action in
                    Button { editingAction = action } label: { /* 기존 row UI 그대로 */ }
                }
            } header: { Text("키 매핑") }
        }
        .navigationTitle("롱프레스")
        .sheet(item: $editingAction) { action in /* 기존 sheet 그대로 */ }
    }
}
```

- [ ] **Step 2: Commit**: `feat: add LongPressSettingsView (renames + decouples from autoBracket)`

---

## Task 17: HelpView 신규 (튜토리얼 + 타이핑 연습 진입)

**Files:**
- Create: `MoaPlus/Settings/HelpView.swift`

- [ ] **Step 1: 신규 화면**

```swift
import SwiftUI

struct HelpView: View {
    @State private var showTutorial = false
    @State private var showPractice = false

    var body: some View {
        List {
            Section {
                Button {
                    showTutorial = true
                } label: {
                    Label("튜토리얼 다시 보기", systemImage: "book.pages")
                }
                Button {
                    showPractice = true
                } label: {
                    Label("타이핑 연습", systemImage: "keyboard.badge.eye")
                }
            } footer: {
                Text("8 단계 튜토리얼 또는 33 개 연습 항목으로 모아키 입력 익히기.")
            }
        }
        .navigationTitle("도움말")
        .fullScreenCover(isPresented: $showTutorial) {
            // 기존 TutorialView 시작점 — Tutorial 폴더 안의 TutorialFlowView 또는 첫 단계 호출
            TutorialView() // 이름은 실제 구현에 맞춰 — Tutorial/ 폴더 검토
        }
        .fullScreenCover(isPresented: $showPractice) {
            TypingPracticeView()
        }
    }
}
```

- [ ] **Step 2: Tutorial 진입 wiring 확인** — `MoaPlus/Tutorial/` 폴더의 진입 View 이름 확인. 첫 실행 onboarding 과 동일한 진입점 호출.
- [ ] **Step 3: Commit**: `feat: add HelpView with tutorial + practice entry`

---

## Task 18: LayoutCustomizationView 에 sideKeyWidth slider 통합

**Files:**
- Modify: `MoaPlus/Settings/LayoutCustomizationView.swift` (Task 11 에서 만든 파일)

- [ ] **Step 1: "키 크기" 섹션 추가 (Task 11 의 LayoutCustomizationView 끝 부분)**

```swift
Section {
    HStack {
        Text("좌우 특수키")
        Spacer()
        Text("\(Int(settings.sideKeyWidthRatio * 100))%").foregroundColor(.secondary)
    }
    Slider(value: $settings.sideKeyWidthRatio, in: 0.15...1.0, step: 0.05)
} header: {
    Text("키 크기")
} footer: {
    Text("좌우 끝 키의 너비. 기본 70% (정사각).")
}
```

- [ ] **Step 2: 시뮬레이터 확인** — slider 동작 + 라이브 프리뷰에 즉시 반영
- [ ] **Step 3: Commit**: `refactor: move sideKeyWidthRatio slider to LayoutCustomizationView`

---

## Task 19: 기존 InputSettingsView / SecondaryInputSettingsView 삭제

**Files:**
- Delete: `MoaPlus/Settings/InputSettingsView.swift`
- Delete: `MoaPlus/Settings/SecondaryInputSettingsView.swift`
- Modify: `MoaPlus.xcodeproj/project.pbxproj` (파일 참조 제거)

- [ ] **Step 1: 사용처 확인** — `grep -r "InputSettingsView\|SecondaryInputSettingsView" --include="*.swift"`. 모든 참조가 제거되었는지 확인 (KeyboardSettingsView 가 LongPressSettingsView 사용, SettingsMainView 가 KeyboardSettingsView 사용 — 직접 참조 없음).
- [ ] **Step 2: 파일 삭제 + xcodeproj 참조 제거** — 빌드 통과 확인
- [ ] **Step 3: GestureSettingsView 의 "디버그" 섹션 흡수** — `showGesturePreview` 토글을 GestureSettingsView 에 이동 (InputSettingsView 에 있던 디버그 섹션). 기존 GestureSettingsView 마지막에 다음 추가:

```swift
Section {
    Toggle("제스처 미리보기", isOn: $settings.showGesturePreview)
} footer: {
    Text("입력 시 긋기 방향과 예측 모음을 화면에 표시합니다.")
}
```

- [ ] **Step 4: SettingsMainView 의 임시 stub (Task 12 Step 2) 제거** — `_TempStubs.swift` 삭제 또는 KeyboardSettingsView/HelpView 가 진짜 구현으로 교체된 시점에서 stub 자체 삭제.
- [ ] **Step 5: 빌드 + 모든 settings 페이지 진입 동작 확인**
- [ ] **Step 6: Commit**: `chore: remove obsolete InputSettings + SecondaryInputSettings views`

---

## Task 20: 첫 실행 모달 (FirstLaunchLayoutModalView)

**Files:**
- Create: `MoaPlus/Views/FirstLaunchLayoutModalView.swift`
- Modify: `MoaPlus/ContentView.swift`

- [ ] **Step 1: 모달 View 작성**

```swift
import SwiftUI

struct FirstLaunchLayoutModalView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 16)
            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            Text("키보드 모드를 선택하세요")
                .font(.title2.bold())
            Text("v1.4 부터 키보드 레이아웃을 선택할 수 있습니다.\n이전 1.1 레이아웃을 좋아하셨나요?")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                ChoiceCard(
                    title: "모던 (현재)",
                    subtitle: "우측에 모음 키 ㅣ ㅡ ㆍ + 백스페이스 위쪽",
                    miniImage: ModernPreview(),
                    onSelect: { applyModern(); dismiss() }
                )
                ChoiceCard(
                    title: "클래식 1.1",
                    subtitle: "! ? . + 가로 백스페이스. 모음 키 없음 (자음 스와이프)",
                    miniImage: ClassicPreview(),
                    onSelect: { applyClassic(); dismiss() }
                )
            }

            Button("나중에") { markShown(); dismiss() }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            Spacer()
            Text("언제든 설정 → 입력 → 레이아웃 커스터마이즈에서 변경 가능")
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(.horizontal, 28)
        .interactiveDismissDisabled(false)
        .onDisappear { markShown() }
    }

    private func applyModern() {
        var c = LayoutCustomization()  // 모두 default = modern
        settings.layoutCustomization = c
        markShown()
    }

    private func applyClassic() {
        var c = LayoutCustomization()
        c.slotA = .classic11
        c.slotB = .vowelKey
        settings.layoutCustomization = c
        markShown()
    }

    private func markShown() {
        if !settings.firstLaunchModalShown {
            settings.firstLaunchModalShown = true
        }
    }
}

private struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let miniImage: AnyView
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                miniImage.frame(width: 80, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundColor(.primary)
                    Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// ModernPreview / ClassicPreview = mini KeyboardPreviewView 또는 정적 이미지
```

- [ ] **Step 2: ContentView 에서 시트 연결**

```swift
@State private var showFirstLaunchModal = false

.onAppear {
    if !KeyboardSettings.shared.firstLaunchModalShown {
        showFirstLaunchModal = true
    }
}
.sheet(isPresented: $showFirstLaunchModal) {
    FirstLaunchLayoutModalView()
}
```

- [ ] **Step 3: 시뮬레이터 확인** — 새 설치 또는 `firstLaunchModalShown = false` 강제 set 후 첫 실행 모달 정상 표시.
- [ ] **Step 4: Commit**: `feat: add first-launch layout selection modal (Korean labels + previews)`

---

## Task 21: 통합 QA + 마이그레이션 확인

- [ ] **Step 1: v1.3 → v1.4 시뮬레이션** — 1.3 빌드 설치 → 본 브랜치 빌드 클린 install 아닌 update 설치 → 키보드 동작 확인 (변화 없어야).

- [ ] **Step 2: 4 시나리오 수동 검증**
  - 시나리오 1: 기본 (A1 + swap OFF + B2 + C 기본값) — 1.3 동일
  - 시나리오 2: A1 + swap ON — 백스페이스 row 3, ㆍ row 1
  - 시나리오 3: A2 + B1 — 1.1 클래식 + 펑크션 행 모음 키
  - 시나리오 4: 슬롯 C 사용자 정의 — col 0 변경

- [ ] **Step 3: 첫 실행 모달 수동 확인**
  - 새 빌드 + 모달 표시
  - "모던" 선택 → A1 + B2 적용
  - "클래식 1.1" 선택 → A2 + B1 적용
  - "나중에" 선택 → 변화 없음, `firstLaunchModalShown = true`

- [ ] **Step 4: 단위 테스트 전체 PASS**
- [ ] **Step 5: 메모리 / 성능 빠른 체크** — 키보드 ON/OFF 30회, 30MB 한계 내.
- [ ] **Step 6: UX 통일 검증** — 새 IA 진입 경로 모두 동작:
  - 메인 → 키보드 → 레이아웃 (2 단)
  - 메인 → 키보드 → 백스페이스 (2 단)
  - 메인 → 키보드 → 입력 동작 (2 단)
  - 메인 → 도움말 → 튜토리얼 / 타이핑 연습
  - 반응 페이지엔 백스페이스 섹션 없음
- [ ] **Step 7: 발견된 버그 fix + 재확인 → 최종 commit (필요 시)**

---

## Self-Review (v3)

**Spec coverage:**
- 슬롯 A 2 프리셋 + swap → Tasks 1, 3, 4 ✓
- 슬롯 B 2 프리셋 (B1 펑크션 행) → Task 10 ✓
- 슬롯 C 셀 단위 매핑 → Task 11 ✓
- A3 제거 → 모든 task 에서 A3 언급 없음 ✓
- 첫 실행 모달 → Task 20 ✓
- 슬롯 시각 표시 → Task 11 의 SlotHighlightOverlay ✓
- 한국어 모달 라벨 → Task 20 의 "모던" / "클래식 1.1" ✓
- 마이그레이션 자동 → Task 7 default 값 ✓
- Telemetry 미수집 → 본 plan 에 telemetry task 없음 ✓
- long-press number 처리 → Task 6 ✓
- **UX 풀 통일** → Tasks 12-19 ✓
  - SettingsMainView 6 항목 평면 → Task 12 ✓
  - KeyboardSettingsView hub → Task 13 ✓
  - BackspaceSettingsView 분리 → Task 14 ✓
  - InputBehaviorSettingsView 분리 → Task 15 ✓
  - LongPressSettingsView (rename + 괄호 분리) → Task 16 ✓
  - HelpView 신규 → Task 17 ✓
  - sideKeyWidth slider 통합 → Task 18 ✓
  - 기존 view 삭제 → Task 19 ✓

**Type consistency:** `LayoutCustomization`, `SlotAPreset`, `SlotBPreset`, `slotABackspaceSwap`, `firstLaunchModalShown` 전 task 동일 ✓. 새 settings view 이름 (KeyboardSettingsView / BackspaceSettingsView / InputBehaviorSettingsView / LongPressSettingsView / HelpView) 전 task 동일 ✓.

**Placeholder scan:** Task 3 의 fatalError 가 의도된 PASS-THROUGH (Task 4 에서 채움) ✓. Task 12 의 stub view (Task 19 에서 삭제) 는 일시적 placeholder 명시 ✓. 그 외 TBD/TODO 없음 ✓.

**v3 task 의존성 그래프:**
```
Tasks 1-7 (data + render):  병렬 가능, 순차 권장 (TDD)
Task 8 (wire grid):         Tasks 1-7 완료 후
Task 9-10 (render + B1):    Task 8 후
Task 11 (LayoutCustomizationView): Task 10 후
Task 12 (SettingsMain restructure): Task 11 후
Tasks 13-17 (new views):    Task 12 후, 서로 병렬 가능
Task 18 (slider 통합):      Task 11 + Task 13 후
Task 19 (delete obsolete):  Tasks 13-18 모두 후
Task 20 (modal):            Task 11 후 (Settings UI 와 무관)
Task 21 (QA):               모든 task 후
```

**v3 의 추가 시간 추정:** Tasks 12-19 추가 = 약 +5 시간 (BackspaceSettingsView 30 분, InputBehaviorSettingsView 30 분, LongPressSettingsView 30 분, HelpView 1 시간, KeyboardSettingsView 1 시간, SettingsMainView 30 분, sideKeyWidth 통합 15 분, 삭제 + 정리 45 분).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-08-keyboard-layout-customization.md` (v2).**

**다음 — 실행 방식:**
1. **Subagent-Driven (recommended)** — task 별 fresh subagent 디스패치, task 사이 검토.
2. **Inline Execution** — executing-plans 로 batch 실행, 체크포인트 검토.

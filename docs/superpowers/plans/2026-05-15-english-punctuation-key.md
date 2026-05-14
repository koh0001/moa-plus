# 영문 자판 긋기 펑크 키 + 슬롯 커스터마이즈 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한글 모드에 있는 긋기 펑크 키를 영문 모드에도 옵션으로 추가하고, 양쪽 모드 슬롯(tap/←/→/↑/↓)을 사용자가 자유 텍스트로 커스텀할 수 있게 한다. 한글 자판 A1 프리셋의 `#` 자리도 옵션으로 긋기 펑크 키로 교체 가능.

**Architecture:** `LayoutCustomization`에 `PunctuationSlots` 신규 타입과 모드별 enable/slots 필드를 추가한다. `PunctuationSwipeKey` 뷰는 슬롯 데이터를 주입받아 동작/미리보기를 렌더. `FunctionRowView`는 모드별 enable 플래그로 default/longSpace 레이아웃 분기를 결정. `ConsonantGridView`는 A1 옵션 ON일 때 # 자리를 펑크 키로 교체. 설정 UI는 `LayoutCustomizationView`에 신규 섹션으로 추가.

**Tech Stack:** Swift / SwiftUI / UIKit (extension entrypoint), XCTest, App Group UserDefaults.

**Spec:** [`docs/superpowers/specs/2026-05-15-english-punctuation-key-design.md`](../specs/2026-05-15-english-punctuation-key-design.md)

**Test 실행 노트:** CLI `xcodebuild test`는 `TEST_HOST` 미설정으로 불가. 단위 테스트는 Xcode `Cmd+U`로 실행. 빌드 검증은 `xcodebuild ... build`로 자동 가능.

---

## Task 1: `PunctuationSlots` 타입 정의

**Files:**
- Modify: `MoaPlusKeyboard/Models/LayoutCustomization.swift` (파일 상단에 추가)
- Test: `MoaPlusKeyboardTests/LayoutCustomizationTests.swift`

- [ ] **Step 1-1: 실패하는 테스트 작성**

`MoaPlusKeyboardTests/LayoutCustomizationTests.swift` 파일 맨 아래(class 닫는 `}` 직전)에 추가:

```swift
    // MARK: - PunctuationSlots

    func testPunctuationSlotsDefaultKorean() {
        let slots = PunctuationSlots.defaultKorean
        XCTAssertEqual(slots.tap, ".")
        XCTAssertEqual(slots.left, "?")
        XCTAssertEqual(slots.right, "!")
        XCTAssertEqual(slots.up, ",")
        XCTAssertEqual(slots.down, ".")
    }

    func testPunctuationSlotsDefaultEnglish() {
        let slots = PunctuationSlots.defaultEnglish
        XCTAssertEqual(slots.tap, ".")
        XCTAssertEqual(slots.left, "?")
        XCTAssertEqual(slots.right, "!")
        XCTAssertEqual(slots.up, ",")
        XCTAssertEqual(slots.down, ".")
    }

    func testPunctuationSlotsCodableRoundTrip() throws {
        let original = PunctuationSlots(tap: "👍", left: "ㅎㅎ", right: "", up: "ok", down: ":)")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PunctuationSlots.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testPunctuationSlotsEmptySlotPreserved() throws {
        let original = PunctuationSlots(tap: ".", left: "", right: "!", up: "", down: ".")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PunctuationSlots.self, from: data)
        XCTAssertEqual(decoded.left, "")
        XCTAssertEqual(decoded.up, "")
    }
```

- [ ] **Step 1-2: 테스트 실패 확인**

Xcode `Cmd+U`로 `LayoutCustomizationTests` 실행. Expected: 컴파일 에러 (`PunctuationSlots` 미정의).

- [ ] **Step 1-3: 구현**

`MoaPlusKeyboard/Models/LayoutCustomization.swift` 파일 상단 `import Foundation` 아래, `enum SlotAPreset` 위에 추가:

```swift
/// 긋기 펑크 키의 5개 슬롯 (탭 + 4방향). 빈 문자열("")은 비활성을 의미.
struct PunctuationSlots: Codable, Equatable {
    var tap: String
    var left: String
    var right: String
    var up: String
    var down: String

    static let defaultKorean = PunctuationSlots(
        tap: ".", left: "?", right: "!", up: ",", down: "."
    )
    static let defaultEnglish = PunctuationSlots(
        tap: ".", left: "?", right: "!", up: ",", down: "."
    )
}
```

- [ ] **Step 1-4: 빌드 검증**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 1-5: 테스트 통과 확인 (Xcode `Cmd+U`)**

Expected: 4개 신규 테스트 PASS.

- [ ] **Step 1-6: 커밋**

```bash
git add MoaPlusKeyboard/Models/LayoutCustomization.swift MoaPlusKeyboardTests/LayoutCustomizationTests.swift
git commit -m "feat: add PunctuationSlots model with Korean/English defaults"
```

---

## Task 2: `LayoutCustomization` 신규 필드 + 마이그레이션

**Files:**
- Modify: `MoaPlusKeyboard/Models/LayoutCustomization.swift`
- Test: `MoaPlusKeyboardTests/LayoutCustomizationTests.swift`

- [ ] **Step 2-1: 실패하는 테스트 작성**

`MoaPlusKeyboardTests/LayoutCustomizationTests.swift` 끝에 추가:

```swift
    // MARK: - Punctuation enable/slots fields

    func testDefaultPunctuationEnableFlags() {
        let layout = LayoutCustomization()
        XCTAssertTrue(layout.koreanPunctuationEnabled, "한글은 기존 동작 유지 — 기본 ON")
        XCTAssertFalse(layout.englishPunctuationEnabled, "영문은 신규 기능 — 기본 OFF로 regression 방지")
        XCTAssertFalse(layout.slotARightColumnTopAsPunctuation, "A1 # 자리 옵션 기본 OFF")
    }

    func testDefaultPunctuationSlots() {
        let layout = LayoutCustomization()
        XCTAssertEqual(layout.koreanPunctuationSlots, .defaultKorean)
        XCTAssertEqual(layout.englishPunctuationSlots, .defaultEnglish)
    }

    func testLegacyDataMigratesPunctuationFields() throws {
        // v1.4 사용자의 디스크 데이터에는 신규 필드가 없음 → 기본값으로 채워져야 함
        let legacyJSON = #"{"slotA":"vowel","slotB":"punctuation","slotC":["~","^",";","*"]}"#
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertTrue(decoded.koreanPunctuationEnabled)
        XCTAssertFalse(decoded.englishPunctuationEnabled)
        XCTAssertFalse(decoded.slotARightColumnTopAsPunctuation)
        XCTAssertEqual(decoded.koreanPunctuationSlots, .defaultKorean)
        XCTAssertEqual(decoded.englishPunctuationSlots, .defaultEnglish)
    }

    func testNewFieldsCodableRoundTrip() throws {
        var original = LayoutCustomization()
        original.englishPunctuationEnabled = true
        original.koreanPunctuationEnabled = false
        original.slotARightColumnTopAsPunctuation = true
        original.englishPunctuationSlots = PunctuationSlots(tap: "👍", left: "", right: "?", up: ",", down: ".")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutCustomization.self, from: data)
        XCTAssertEqual(decoded, original)
    }
```

- [ ] **Step 2-2: 테스트 실패 확인 (`Cmd+U`)**

Expected: 컴파일 에러 (`koreanPunctuationEnabled` 등 미정의).

- [ ] **Step 2-3: 구현 — 필드 추가**

`MoaPlusKeyboard/Models/LayoutCustomization.swift`의 `struct LayoutCustomization` 안, `slotC` 필드 아래에 추가:

```swift
    var slotC: [String] = LayoutCustomization.defaultSlotC

    // MARK: - Punctuation key (v1.5)

    /// 한글 자판 function row의 긋기 펑크 키 활성화. 기본 ON (기존 동작 유지).
    var koreanPunctuationEnabled: Bool = true
    /// 영문 자판 function row의 긋기 펑크 키 활성화. 기본 OFF — ON 시 스페이스 폭이 줄어듦.
    var englishPunctuationEnabled: Bool = false
    /// A1 (vowel) 프리셋 우측 col 6 row 0 (`#` 자리)을 긋기 펑크 키로 교체. 한글 슬롯 데이터 공유.
    var slotARightColumnTopAsPunctuation: Bool = false
    /// 한글 모드 펑크 키 슬롯.
    var koreanPunctuationSlots: PunctuationSlots = .defaultKorean
    /// 영문 모드 펑크 키 슬롯.
    var englishPunctuationSlots: PunctuationSlots = .defaultEnglish
```

- [ ] **Step 2-4: `init(from:)` 마이그레이션 추가**

같은 파일 `init(from decoder: Decoder) throws` 안, 마지막 `slotC = Self.normalizeSlotC(raw)` 라인 다음에 추가:

```swift
        koreanPunctuationEnabled = try c.decodeIfPresent(Bool.self, forKey: .koreanPunctuationEnabled) ?? true
        englishPunctuationEnabled = try c.decodeIfPresent(Bool.self, forKey: .englishPunctuationEnabled) ?? false
        slotARightColumnTopAsPunctuation = try c.decodeIfPresent(Bool.self, forKey: .slotARightColumnTopAsPunctuation) ?? false
        koreanPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .koreanPunctuationSlots) ?? .defaultKorean
        englishPunctuationSlots = try c.decodeIfPresent(PunctuationSlots.self, forKey: .englishPunctuationSlots) ?? .defaultEnglish
```

- [ ] **Step 2-5: `CodingKeys`에 신규 케이스 추가**

같은 파일 `private enum CodingKeys`:

```swift
    private enum CodingKeys: String, CodingKey {
        case slotA, slotABackspaceSwap, slotARightColumn, slotB, slotC
        case koreanPunctuationEnabled, englishPunctuationEnabled, slotARightColumnTopAsPunctuation
        case koreanPunctuationSlots, englishPunctuationSlots
    }
```

- [ ] **Step 2-6: 빌드 검증**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 2-7: 테스트 통과 (`Cmd+U`)**

Expected: 4개 신규 테스트 PASS + 기존 테스트 모두 PASS (regression 없음).

- [ ] **Step 2-8: 커밋**

```bash
git add MoaPlusKeyboard/Models/LayoutCustomization.swift MoaPlusKeyboardTests/LayoutCustomizationTests.swift
git commit -m "feat: add punctuation enable/slots fields to LayoutCustomization with legacy migration"
```

---

## Task 3: `PunctuationSwipeKey` 일반화 (슬롯 주입 + 빈 슬롯 가드 + 폰트 자동축소)

**Files:**
- Modify: `MoaPlusKeyboard/Views/FunctionRowView.swift:315-371` (struct PunctuationSwipeKey 본체)

이 단계는 SwiftUI View라 단위 테스트가 어렵다. 시그니처 변경 + 내부 로직 변경 + 수동 미리보기 검증으로 진행한다.

- [ ] **Step 3-1: `PunctuationSwipeKey` 본체 교체**

`MoaPlusKeyboard/Views/FunctionRowView.swift` line 312-371 (`// MARK: - Punctuation swipe key` 이하부터 그 다음 `// MARK: - Slot B vowel key` 이전까지) 통째로 교체:

```swift
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
```

- [ ] **Step 3-2: 같은 파일 호출부 임시 수정 (컴파일 통과용)**

같은 파일 `slotBKey(width:)` 함수 (line 154-172 부근) 안의 `case .punctuation:` 블록:

```swift
        case .punctuation:
            PunctuationSwipeKey(
                width: width,
                height: height,
                slots: KeyboardSettings.shared.layoutCustomization.koreanPunctuationSlots,
                onPunctuation: onPunctuation
            )
```

(Task 4에서 모드별 분기로 다시 손댐 — 지금은 컴파일 통과용 임시값.)

- [ ] **Step 3-3: 같은 파일 `#Preview` 블록 수정**

파일 맨 아래 `#Preview { ... }` 블록에서 `FunctionRowView(...)` 호출은 그대로 두되, 만약 직접 `PunctuationSwipeKey(...)`를 호출하는 코드가 있으면 `slots: .defaultKorean` 인자 추가. (line 533-573 검토: 현재는 `FunctionRowView`만 호출 — 변경 불필요.)

- [ ] **Step 3-4: 빌드 검증**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 3-5: 커밋**

```bash
git add MoaPlusKeyboard/Views/FunctionRowView.swift
git commit -m "refactor: inject PunctuationSlots into PunctuationSwipeKey with empty-slot guard"
```

---

## Task 4: `FunctionRowView` 모드별 분기 + 영문 펑크 키 활성화

**Files:**
- Modify: `MoaPlusKeyboard/Views/FunctionRowView.swift:36-48` (body 분기), `MoaPlusKeyboard/Views/FunctionRowView.swift:154-172` (slotBKey)

- [ ] **Step 4-1: body 분기 수정**

`MoaPlusKeyboard/Views/FunctionRowView.swift` line 36-48 (var body 블록) 교체:

```swift
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
        } else if !punctuationEnabledForMode || layoutCustomization.slotA == .fullPackage {
            // 펑크 키 OFF이거나 A3(fullPackage)면 긴 스페이스 레이아웃.
            longSpaceLayoutBody
        } else {
            defaultLayoutBody
        }
    }
```

- [ ] **Step 4-2: `slotBKey(width:)` 모드별 슬롯 주입**

같은 파일 `slotBKey(width:)` 함수의 `case .punctuation:` 블록을:

```swift
        case .punctuation:
            let slots = mode == .korean
                ? KeyboardSettings.shared.layoutCustomization.koreanPunctuationSlots
                : KeyboardSettings.shared.layoutCustomization.englishPunctuationSlots
            PunctuationSwipeKey(
                width: width,
                height: height,
                slots: slots,
                onPunctuation: onPunctuation
            )
```

- [ ] **Step 4-3: 빌드 검증**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 4-4: 수동 확인 (시뮬레이터)**

Xcode에서 시뮬레이터 실행:
- 한글 모드 → 펑크 키 그대로 표시 + 기존 동작 (regression 없음)
- 영문 모드 → 펑크 키 안 보임, 긴 스페이스 (영문 토글이 기본 OFF이므로)

- [ ] **Step 4-5: 커밋**

```bash
git add MoaPlusKeyboard/Views/FunctionRowView.swift
git commit -m "feat: gate punctuation key by mode-specific enable flag in FunctionRowView"
```

---

## Task 5: `ConsonantGridView` A1 # 자리 옵션 분기

**Files:**
- Modify: `MoaPlusKeyboard/Views/ConsonantGridView.swift`

- [ ] **Step 5-1: 현재 # 자리 렌더링 위치 파악**

ConsonantGridView 안에서 col 6 row 0 (`#` 심볼 토글) 키가 그려지는 곳을 찾는다.

Run: `grep -n '"#"\|symbolToggle\|toggleSymbol' MoaPlusKeyboard/Views/ConsonantGridView.swift`

이 파일은 사용자가 처음 본 적이 없으므로 grep 결과로 정확한 위치를 파악한 뒤, 해당 셀이 그려지는 분기(switch나 if)에 다음 패턴을 추가:

```swift
// A1 프리셋이고 사용자가 # 자리 → 펑크 키 옵션을 켰을 때 PunctuationSwipeKey 렌더링.
if layoutCustomization.slotA == .vowel
   && layoutCustomization.slotARightColumnTopAsPunctuation {
    PunctuationSwipeKey(
        width: sideWidth,         // col 6 셀 폭 변수명에 맞춰 조정
        height: cellHeight,       // row 높이 변수명에 맞춰 조정
        slots: KeyboardSettings.shared.layoutCustomization.koreanPunctuationSlots,
        onPunctuation: { onPunctuation($0) }
    )
} else {
    // 기존 # 버튼 렌더링 코드 (원본 유지)
}
```

- [ ] **Step 5-2: `onPunctuation` 콜백 경로 확인**

ConsonantGridView가 punct 입력을 ViewModel로 전달하는 콜백이 이미 있는지 확인. 없으면 부모(KeyboardView)에서 prop으로 받도록 시그니처 확장 필요. 패턴은 한글 모드 punct 키와 동일하게 KeyboardViewModel.handlePunctuation(_:) 호출 경로 재사용.

Run: `grep -n "onPunctuation\|handlePunctuation" MoaPlusKeyboard/Views/ConsonantGridView.swift MoaPlusKeyboard/Views/KeyboardView.swift MoaPlusKeyboard/ViewModels/KeyboardViewModel.swift`

- [ ] **Step 5-3: 콜백 누락 시 prop 추가**

ConsonantGridView struct에 `let onPunctuation: (String) -> Void` 추가, KeyboardView에서 ViewModel handlePunctuation 호출로 wire-up.

- [ ] **Step 5-4: 빌드 검증**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 5-5: 수동 확인**

설정에서 `slotARightColumnTopAsPunctuation = true` 강제 세팅한 뒤 (디버거 또는 임시 기본값 변경) 시뮬레이터에서:
- A1 프리셋 + 옵션 ON → # 자리에 펑크 키 등장
- 심볼 모드 진입은 function row `[!#1]` 토글로 가능한지 확인

이후 임시 값 원복.

- [ ] **Step 5-6: 커밋**

```bash
git add MoaPlusKeyboard/Views/ConsonantGridView.swift MoaPlusKeyboard/Views/KeyboardView.swift
git commit -m "feat: option to replace # key with punctuation swipe key in A1 preset"
```

(KeyboardView.swift는 wire-up 필요 시에만 stage.)

---

## Task 6: `LayoutCustomizationView` 설정 UI 추가

**Files:**
- Modify: `MoaPlus/Settings/LayoutCustomizationView.swift`

- [ ] **Step 6-1: 현재 파일 구조 파악**

Run: `grep -n "Section\|Toggle\|@State\|@Published\|settings\." MoaPlus/Settings/LayoutCustomizationView.swift | head -50`

기존 섹션 패턴을 따라 신규 섹션 추가. `KeyboardSettings.shared.layoutCustomization` 바인딩 패턴 그대로 사용.

- [ ] **Step 6-2: 신규 섹션 추가**

기존 마지막 Section 뒤(또는 적절한 위치)에 추가:

```swift
            // MARK: - 긋기 펑크 키 (v1.5)

            Section("긋기 펑크 키 — 한글 자판") {
                Toggle("사용 (function row 우측)", isOn: Binding(
                    get: { KeyboardSettings.shared.layoutCustomization.koreanPunctuationEnabled },
                    set: { newValue in
                        var lc = KeyboardSettings.shared.layoutCustomization
                        lc.koreanPunctuationEnabled = newValue
                        KeyboardSettings.shared.layoutCustomization = lc
                    }
                ))

                if KeyboardSettings.shared.layoutCustomization.slotA == .vowel {
                    Toggle("A1 # 자리에도 표시", isOn: Binding(
                        get: { KeyboardSettings.shared.layoutCustomization.slotARightColumnTopAsPunctuation },
                        set: { newValue in
                            var lc = KeyboardSettings.shared.layoutCustomization
                            lc.slotARightColumnTopAsPunctuation = newValue
                            KeyboardSettings.shared.layoutCustomization = lc
                        }
                    ))
                }

                PunctuationSlotsEditor(
                    slots: Binding(
                        get: { KeyboardSettings.shared.layoutCustomization.koreanPunctuationSlots },
                        set: { newValue in
                            var lc = KeyboardSettings.shared.layoutCustomization
                            lc.koreanPunctuationSlots = newValue
                            KeyboardSettings.shared.layoutCustomization = lc
                        }
                    ),
                    defaults: .defaultKorean,
                    isEnabled: KeyboardSettings.shared.layoutCustomization.koreanPunctuationEnabled
                )
            }

            Section("긋기 펑크 키 — 영문 자판") {
                Toggle("사용 (스페이스 폭이 줄어듭니다)", isOn: Binding(
                    get: { KeyboardSettings.shared.layoutCustomization.englishPunctuationEnabled },
                    set: { newValue in
                        var lc = KeyboardSettings.shared.layoutCustomization
                        lc.englishPunctuationEnabled = newValue
                        KeyboardSettings.shared.layoutCustomization = lc
                    }
                ))

                PunctuationSlotsEditor(
                    slots: Binding(
                        get: { KeyboardSettings.shared.layoutCustomization.englishPunctuationSlots },
                        set: { newValue in
                            var lc = KeyboardSettings.shared.layoutCustomization
                            lc.englishPunctuationSlots = newValue
                            KeyboardSettings.shared.layoutCustomization = lc
                        }
                    ),
                    defaults: .defaultEnglish,
                    isEnabled: KeyboardSettings.shared.layoutCustomization.englishPunctuationEnabled
                )
            }
```

- [ ] **Step 6-3: `PunctuationSlotsEditor` 서브뷰 추가**

같은 파일 끝(File-scope, 다른 struct 옆)에 추가:

```swift
private struct PunctuationSlotsEditor: View {
    @Binding var slots: PunctuationSlots
    let defaults: PunctuationSlots
    let isEnabled: Bool

    var body: some View {
        Group {
            // 라이브 미리보기
            HStack {
                Text("미리보기")
                Spacer()
                preview
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemFill))
                    )
            }

            slotRow(label: "탭",     binding: $slots.tap,   placeholder: defaults.tap)
            slotRow(label: "← 왼",   binding: $slots.left,  placeholder: defaults.left)
            slotRow(label: "→ 오",   binding: $slots.right, placeholder: defaults.right)
            slotRow(label: "↑ 위",   binding: $slots.up,    placeholder: defaults.up)
            slotRow(label: "↓ 아래", binding: $slots.down,  placeholder: defaults.down)

            Button("기본값으로 되돌리기") {
                slots = defaults
            }
            .foregroundColor(.accentColor)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
    }

    private var preview: some View {
        VStack(spacing: 1) {
            previewHint(slots.up)
            HStack(spacing: 4) {
                previewHint(slots.left)
                Text(slots.tap.isEmpty ? " " : slots.tap)
                    .font(.system(size: previewMainSize(slots.tap), weight: .medium))
                previewHint(slots.right)
            }
            previewHint(slots.down)
        }
    }

    @ViewBuilder
    private func previewHint(_ text: String) -> some View {
        if text.isEmpty {
            Text(" ").font(.system(size: 9)).foregroundColor(.clear)
        } else {
            Text(text).font(.system(size: previewHintSize(text))).foregroundColor(.secondary)
        }
    }

    private func previewMainSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 16
        case 2:    return 12
        default:   return 10
        }
    }
    private func previewHintSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 9
        case 2:    return 8
        default:   return 7
        }
    }

    private func slotRow(label: String, binding: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label).frame(width: 56, alignment: .leading)
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
```

- [ ] **Step 6-4: 타겟 멤버십 확인**

`PunctuationSlots`는 `LayoutCustomization.swift` 안에 정의돼 있고 그 파일이 이미 메인 앱 + 익스텐션 양쪽 멤버이므로 추가 작업 불필요. 확인:

Run: `ruby -e "require 'xcodeproj'; p=Xcodeproj::Project.open('MoaPlus.xcodeproj'); p.targets.each { |t| puts t.name+': '+t.source_build_phase.files.map{|f|f.file_ref.path}.grep(/LayoutCustomization/).join(',') }"`

`MoaPlus` 와 `MoaPlusKeyboard` 양쪽에 `LayoutCustomization.swift`가 보여야 함. 만약 한쪽만 있으면:

Run: `ruby scripts/add_target_membership.rb MoaPlusKeyboard/Models/LayoutCustomization.swift`

- [ ] **Step 6-5: 빌드 검증**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet`
Expected: BUILD SUCCEEDED

- [ ] **Step 6-6: 수동 확인 (시뮬레이터)**

- 설정 → 레이아웃 → 긋기 펑크 키 섹션 두 개 등장
- 영문 토글 ON → 영문 모드 키보드에서 펑크 키 등장, 스페이스 폭 감소
- 한글 토글 OFF → 한글 모드 펑크 키 사라짐, 긴 스페이스
- 슬롯 텍스트필드에 임의 문자열 입력 → 미리보기 즉시 반영 + 키보드에도 반영
- 빈 슬롯 → 미리보기에서 글자 숨김 + 해당 방향 드래그 시 입력 안 됨
- "기본값으로 되돌리기" → 5개 슬롯 모두 기본값 복귀

- [ ] **Step 6-7: 커밋**

```bash
git add MoaPlus/Settings/LayoutCustomizationView.swift MoaPlus.xcodeproj/project.pbxproj
git commit -m "feat: add punctuation key settings UI (per-mode toggles + slot editors)"
```

---

## Task 7: 최종 검증

- [ ] **Step 7-1: 전체 빌드**

Run: `xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16' build -quiet 2>&1 | tail -20`
Expected: BUILD SUCCEEDED, warnings 0개 또는 기존 수준 유지.

- [ ] **Step 7-2: 전체 단위 테스트 (Xcode `Cmd+U`)**

Expected: 모든 테스트 PASS. 신규 8개 (Task 1: 4개, Task 2: 4개) 포함.

- [ ] **Step 7-3: 실기기 또는 시뮬레이터 풀 시나리오 검증**

다음을 모두 통과해야 함:

1. **Regression**: 기존 한글 모드 펑크 키 동작 (tap=. ←=? →=! ↑=, ↓=.) 그대로
2. **Regression**: 기존 영문 모드 (긴 스페이스) 그대로
3. **신규**: 영문 토글 ON → 펑크 키 등장, 5방향 입력 동작
4. **신규**: 한글/영문 슬롯 각각 독립 커스텀 (한쪽 변경이 다른 쪽에 영향 X)
5. **신규**: 빈 슬롯 → 해당 방향 입력 안 됨, 미리보기 글자 hidden
6. **신규**: 자유 텍스트 (이모지 "👍", 한글 "ㅎㅎ", 다중 문자 "...") 입력 시 정상 삽입
7. **신규**: A1 # 자리 옵션 ON → # 버튼이 펑크 키로 교체, 심볼 모드는 function row `[!#1]`로 진입 가능
8. **App Group 동기화**: 메인 앱에서 슬롯 변경 → 키보드 익스텐션에 즉시 반영
9. **미확정 한글 commit**: "안녕" 입력 중 ㄴ 마지막에서 펑크 키 → "녕." 형태로 정상 확정
10. **첫 시작 모달**: `firstLaunchModalShown` 영향 없음 (신규 필드는 first-launch 흐름 무관)

- [ ] **Step 7-4: 변경 파일 최종 확인**

Run: `git log main..HEAD --stat`
Expected: 6개 commit, 변경 파일이 spec의 영향 범위(LayoutCustomization.swift, FunctionRowView.swift, ConsonantGridView.swift, KeyboardView.swift 옵션, LayoutCustomizationView.swift, LayoutCustomizationTests.swift, project.pbxproj)와 일치.

- [ ] **Step 7-5: 모든 검증 통과 시 작업 종료**

이 시점에서 plan은 모두 완료. `/ultraqa`로 넘어가 검증 사이클 진행.

---

## 작업 흐름 요약

```
Task 1 (data model)  →  Task 2 (migration)  →  Task 3 (view)  →
Task 4 (function row)  →  Task 5 (grid option)  →
Task 6 (settings UI)  →  Task 7 (verify)
```

각 task는 독립 커밋 단위. Task 5는 ConsonantGridView 내부 구조 파악이 필요해서 가장 불확실성이 높음(grep 결과에 따라 분기 위치 결정). 나머지는 spec과 1:1 매핑.

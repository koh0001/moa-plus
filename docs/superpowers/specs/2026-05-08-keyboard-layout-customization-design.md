# 키보드 레이아웃 커스터마이즈 + 설정 IA 통일 — 설계 문서

- 날짜: 2026-05-08 (v3 — 설정 IA 풀 통일 결정 후 개정)
- 대상 버전: v1.4 (build 7)
- 동기:
  - App Store 1.2 리뷰 다수 — 1.1 무모음 레이아웃 선호 + 백스페이스 위치 변경 부담 + 스페이스바 옆 키 용도 변경 요청
  - 기존 설정 IA 의 9 가지 일관성 문제 — "외형" 명명 충돌, 백스페이스 설정 분산, "보조 입력" 추상적 이름, 단일 항목 섹션 등

## v3 변경 요약 (UX 풀 통일 추가)

| 항목 | v2 | v3 |
|---|---|---|
| 레이아웃 커스터마이즈 | InputSettingsView 안 deep nested | **메인 → 키보드 → 레이아웃 (2 단)** |
| sideKeyWidthRatio 슬라이더 | InputSettingsView 의 "레이아웃" 섹션 | **레이아웃 페이지로 통합** |
| 백스페이스 속도/단어삭제 | FeedbackSettingsView | **새 BackspaceSettingsView** |
| 괄호 자동 닫기 | SecondaryInputSettingsView | **새 InputBehaviorSettingsView** |
| 스페이스 드래그 커서 | InputSettingsView | **InputBehaviorSettingsView** |
| 제스처 미리보기 (디버그) | InputSettingsView 디버그 섹션 | **GestureSettingsView 안에 흡수** |
| 튜토리얼/타이핑 연습 진입 | 홈 화면만 | **새 HelpView 에서도 진입** |
| SettingsMainView 구조 | 4 섹션 (입력/생산성/외형/null) | **6 항목 평면 (키보드/외형/반응/단축어/도움말/앱정보)** |

## v2 변경 요약 (autoplan CEO 검토 반영)

| 항목 | v1 | v2 |
|---|---|---|
| 슬롯 A 프리셋 | A1 (모음) / A2 (1.1 특수문자) / A3 (풀 패키지) | **A1 + A2 (2 프리셋)** — A3 제거 |
| A1 의 백스페이스 위치 | 고정 (row 1 col 6) | **swap 토글 추가** (row 1 col 6 ↔ row 3 col 6 with ㆍ) |
| 슬롯 B | A3 일 때 자동 비활성 | 항상 활성 (A3 제거되었으므로) |
| 슬롯 C | 1단계 포함 | **유지** — 1단계 포함 |
| 새 추가 | — | **첫 실행 모달** (한국어 "클래식/모던" + 이미지) |
| 새 추가 | — | **설정 화면에 슬롯 시각 표시** (mini keyboard preview 와 슬롯 하이라이트) |
| 추가 검토 | — | Telemetry: **미수집 결정** |

## 동기 (Why)

1.2 부터 우측 컬럼(col 6)에 천지인 모음 키(ㅣ/ㅡ/ㆍ)와 백스페이스가 들어가면서 1.1 사용자들이 두 가지를 잃었다:
- 백스페이스가 row 1 col 6 으로 위치 이동 → 익숙하던 손가락 위치 변경 부담
- 1.1 의 깔끔한 무모음 레이아웃 (자음 스와이프만으로 모음 입력) 손실

리뷰에서 명시된 요청:
- 레이아웃 형태 선택 (현재 / 1.1 클래식)
- 백스페이스 위치 토글
- 스페이스바 옆 키의 사용자 정의 (현재 ".") 활용도 ↑

## 핵심 결정

### 1. "슬롯" 모델

키보드를 **3 개의 커스터마이즈 가능 슬롯**으로 정의:

| 슬롯 | 영역 | 셀 수 |
|---|---|---|
| **A** | 우측 컬럼 (col 6) | 4 (row 0~3) |
| **B** | 스페이스바 옆 키 (펑크션 행) | 1 (5방향 동작) |
| **C** | 좌측 컬럼 (col 0) | 4 (row 0~3) |

자음 배치 (col 1~5) 는 **본 변경 범위 밖** (v3 이후로 미룸).

### 2. 슬롯별 프리셋

#### 슬롯 A — 2 프리셋 + 1 토글

##### A1. 모음 (기본, 현재 1.3 동작)
```
~  ㅃ ㅉ ㄸ ㄲ ㅆ  #
^  ㅂ ㅈ ㄷ ㄱ ㅅ  ⌫    ← row 1 col 6 = 백스페이스 (기본)
;  ㅁ ㄴ ㅇ ㄹ ㅎ  ㅣ
*  ㅋ ㅌ ㅊ ㅍ  ㅡ ㆍ    ← row 3 col 6 = ㆍ (점 모음, 기본)
```

##### A1 의 백스페이스 swap 토글 (신규)
사용자가 토글하면 백스페이스 ↔ ㆍ 위치가 교환:
```
~  ㅃ ㅉ ㄸ ㄲ ㅆ  #
^  ㅂ ㅈ ㄷ ㄱ ㅅ  ㆍ    ← swap: row 1 col 6 = ㆍ
;  ㅁ ㄴ ㅇ ㄹ ㅎ  ㅣ
*  ㅋ ㅌ ㅊ ㅍ  ㅡ ⌫    ← swap: row 3 col 6 = 백스페이스
```
**의도**: 1.1 사용자는 백스페이스가 아래쪽에 있던 게 익숙. 모음 키는 유지하되 백스페이스만 1.1 위치로 옮길 수 있게.

##### A2. 1.1 특수문자
```
~  ㅃ ㅉ ㄸ ㄲ ㅆ  !
^  ㅂ ㅈ ㄷ ㄱ ㅅ  ?
;  ㅁ ㄴ ㅇ ㄹ ㅎ  .
*  ㅋ ㅌ ㅊ ㅍ  [⌫⌫ wide]    ← row 3 col 5+6 = 가로 백스페이스
```
무모음 — 모음 입력은 자음 키 스와이프 또는 슬롯 B 의 모음 키 (B1).

##### ~~A3. 풀 패키지~~ — **제거**
v1 검토에서 silent override 문제 (슬롯 A 가 슬롯 B 를 자동 비활성) 로 제거.

#### 슬롯 B — 2 프리셋

| 프리셋 | 동작 |
|---|---|
| **B2 특수문자 (기본)** | tap=`.` ←=`?` →=`!` ↑=`,` ↓=`.` (현재 1.3 동작 유지) |
| **B1 모음 키** | tap=`ㆍ`, 8방향 드래그 = 자음 키 드래그와 동일한 단일 모음 매핑 (합성 X) |

A3 가 제거되었으므로 슬롯 B 는 항상 독립적으로 동작.

#### 슬롯 C — 셀 단위 사용자 매핑

- 프리셋 선택 개념 없음
- 4 셀 (row 0~3) 각각 사용자가 자유 매핑
- 기본값: `~` `^` `;` `*` (현재 1.3 동작)
- 셀당 최소 1 자 강제 (빈 문자열 금지 → 레이아웃 밀림 방지)
- 셀당 최대 4 자 권장 (UI 표시 고려)

### 3. 기본값 + 마이그레이션

| 슬롯 | 새 사용자 default | 1.3 사용자 마이그레이션 |
|---|---|---|
| A 프리셋 | A1 모음 | 자동 (변화 없음) |
| A swap 토글 | OFF (백스페이스 위쪽) | 자동 |
| B 프리셋 | B2 특수문자 | 자동 (변화 없음) |
| C 셀 | `~^;*` | 자동 (변화 없음) |

→ **1.3 사용자는 업데이트 후 동작 변화 0**.

### 4. 첫 실행 모달 (신규)

업데이트 후 첫 실행 시 1 회 표시:

```
   ⌨️
   키보드 모드를 선택하세요
   v1.4 부터 키보드 레이아웃을 선택할 수 있습니다.
   이전 1.1 레이아웃을 좋아하셨나요?

   [모던 (현재)]  ← 모던 레이아웃 미니 스크린샷 이미지
   [클래식 1.1]   ← 클래식 레이아웃 미니 스크린샷 이미지

   언제든 설정에서 변경 가능
```

- "모던 (현재)" 선택 → A1 + B2 + C 기본값 (변화 없음)
- "클래식 1.1" 선택 → A2 + B1 + C 기본값 + A1 swap 토글 OFF
- 모달 dismiss 또는 "나중에" → 기본값 유지 (모던)
- App Group UserDefaults 에 `firstLaunchModalShown = true` 저장. 재표시 안 함.
- "설정 → 앱 정보 → 첫 실행 모달 다시 보기" 버튼으로 재표시 가능 (옵션).

### 5. 설정 화면 — 슬롯 시각 표시 (신규)

기존 라디오 버튼 위에 **mini keyboard preview** + **슬롯 하이라이트** 추가. 사용자가 "슬롯 A" 라는 추상 용어를 듣고 어디인지 즉시 알 수 있게.

```
┌─ 레이아웃 커스터마이즈 ────────────┐
│  [현재 키보드 미리보기]              │
│  ┌──────────────────────────────┐  │
│  │ [mini KeyboardView render]    │  │
│  │ 슬롯 A 영역 = 우측 컬럼 강조    │  │
│  │ 슬롯 B 영역 = 스페이스 옆 강조  │  │
│  │ 슬롯 C 영역 = 좌측 컬럼 강조    │  │
│  └──────────────────────────────┘  │
│  ▾ 우측 컬럼 (슬롯 A) [⊕ 위치 표시] │
│    ◯ 모음 (현재)                    │
│    ◯ 1.1 특수문자                   │
│    ☑ 백스페이스 ↔ ㆍ 위치 swap     │  (A1 일 때만)
│  ▾ 스페이스 옆 키 (슬롯 B)          │
│    ...                              │
│  ▾ 좌측 컬럼 (슬롯 C)               │
│    ...                              │
└─────────────────────────────────────┘
```

상단 "현재 키보드 미리보기" 는 라이브 렌더 (`KeyboardPreviewView` 재사용). 사용자가 슬롯 A/B/C 섹션 헤더를 탭하면 해당 슬롯이 미리보기에서 시각적으로 강조 (테두리 또는 배경 하이라이트).

### 6. 설정 IA 풀 통일 (v3 신규)

5 가지 통일 원칙:
1. **한 동작 = 한 위치** — 백스페이스 관련 모든 설정은 한 페이지. 레이아웃 모든 결정은 한 페이지.
2. **카테고리는 사용자 멘탈 모델** — "보조 입력" 같은 추상적 명칭 금지.
3. **헤더/풋터 일관성** — 모든 Section 은 헤더 + 의도 명확한 풋터 (1~2줄).
4. **핵심 가치 ≤ 2 단** — 자주 쓰는 설정 (레이아웃, 테마) 메인에서 2 탭 안.
5. **라이브 프리뷰 표준** — 키보드 모양/색을 바꾸는 모든 페이지는 상단 KeyboardPreviewView.

#### 새 IA

```
설정 (메인)
├── ⌨ 키보드 (KeyboardSettingsView, 신규)
│   ├── 레이아웃 (LayoutCustomizationView, +sideKeyWidthRatio 통합)
│   ├── 제스처 (GestureSettingsView, +제스처 미리보기 토글)
│   ├── 롱프레스 (LongPressSettingsView, 기존 SecondaryInputSettingsView 이름변경 + 괄호/커서 분리)
│   ├── 백스페이스 (BackspaceSettingsView, 신규 — 속도+단어삭제 통합)
│   ├── 입력 동작 (InputBehaviorSettingsView, 신규 — 괄호 자동닫기 + 스페이스 드래그)
├── 🎨 외형 (AppearanceSettingsView, 그대로)
├── 🎵 반응 (FeedbackSettingsView, 백스페이스 항목 제거)
├── ⚡ 단축어 (AbbreviationSettingsView, 그대로)
├── ❓ 도움말 (HelpView, 신규 — 튜토리얼 다시보기 + 타이핑 연습 진입)
├── ℹ 앱 정보 (AboutView, 그대로)
```

#### 항목 이동 매트릭스

| 설정 항목 | 현재 위치 | 새 위치 |
|---|---|---|
| 레이아웃 커스터마이즈 (신규) | — | 키보드 → 레이아웃 |
| 좌우 특수키 크기 (sideKeyWidthRatio) | 입력 → 모아키 입력 → 레이아웃 섹션 | **키보드 → 레이아웃 (LayoutCustomizationView)** |
| 긋기 입력 (제스처) | 입력 → 모아키 입력 → 제스처 섹션 | 키보드 → 제스처 |
| 제스처 미리보기 (디버그) | 입력 → 모아키 입력 → 디버그 섹션 | **키보드 → 제스처 안 한 섹션** |
| 스페이스 드래그 커서 이동 | 입력 → 모아키 입력 → 커서 제어 | **키보드 → 입력 동작** |
| 보조 힌트 표시 | 입력 → 보조 입력 | 키보드 → 롱프레스 |
| 롱프레스 속도 | 입력 → 보조 입력 | 키보드 → 롱프레스 |
| 키 매핑 (보조) | 입력 → 보조 입력 | 키보드 → 롱프레스 |
| 괄호 자동 닫기 | 입력 → 보조 입력 | **키보드 → 입력 동작** |
| 백스페이스 속도 | 반응 (Feedback) | **키보드 → 백스페이스** |
| 단어 단위 삭제 | 반응 (Feedback) | **키보드 → 백스페이스** |
| 햅틱 | 반응 | 반응 (그대로) |
| 사운드 | 반응 | 반응 (그대로) |
| 단축어 | 생산성 → 단축어 | **단축어 (메인 직속)** |
| 튜토리얼 다시 보기 | 없음 | **도움말 (신규)** |
| 타이핑 연습 진입 | 홈 화면만 | **도움말 (메인에서도 진입)** |

#### SettingsMainView 새 구조

```swift
List {
    Section {
        NavigationLink(destination: KeyboardSettingsView()) { Label("키보드", systemImage: "keyboard") }
        NavigationLink(destination: AppearanceSettingsView()) { Label("외형", systemImage: "paintbrush") }
        NavigationLink(destination: FeedbackSettingsView()) { Label("반응", systemImage: "waveform") }
        NavigationLink(destination: AbbreviationSettingsView()) { Label("단축어", systemImage: "text.badge.plus") }
    }
    Section {
        NavigationLink(destination: HelpView()) { Label("도움말", systemImage: "questionmark.circle") }
        NavigationLink(destination: AboutView()) { Label("앱 정보", systemImage: "info.circle") }
    }
}
.navigationTitle("설정")
```

#### 마이그레이션

- App Group UserDefaults 키 변경 0 — 모든 기존 키 (sideKeyWidthRatio, backspaceSpeed, autoBracketEnabled 등) 그대로. UI binding 위치만 이동.
- 기존 `InputSettingsView` / `SecondaryInputSettingsView` 는 새 통합 페이지로 대체 후 삭제.
- 기존 `FeedbackSettingsView` 는 백스페이스 섹션만 제거 (햅틱/사운드 유지).

## 데이터 모델

```swift
// MoaPlusKeyboard/Models/LayoutCustomization.swift (신규)

enum SlotAPreset: String, Codable, CaseIterable {
    case vowel        // A1 — 모음 (기본)
    case classic11    // A2 — 1.1 특수문자
}

enum SlotBPreset: String, Codable, CaseIterable {
    case punctuation  // B2 — 특수문자 (기본)
    case vowelKey     // B1 — 모음 키 (8방향)
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
        while result.count < 4 {
            result.append(defaultSlotC[result.count])
        }
        return Array(result)
    }

    private enum CodingKeys: String, CodingKey {
        case slotA, slotABackspaceSwap, slotB, slotC
    }
}

// 첫 실행 모달
extension KeyboardSettings.Keys {
    static let firstLaunchModalShown = "firstLaunchModalShown"
}
```

### KeyContent 신규 케이스

```swift
enum KeyContent: Equatable {
    // 기존 케이스 유지
    case consonant(Choseong)
    case symbol(String)
    case backspace
    case vowelPrimitive(VowelPrimitiveType)
    case functional(FunctionalKeyType)
    case systemSwitch
    case quickPunctuation(String)

    // 신규 (A2 만)
    case backspaceWide       // row 3 의 가로 2칸 ⌫
}
```

A3 가 제거되었으므로 `slotBVowelKey` / `slotBPunctuation` (col 6 임베드) 케이스 불필요. 슬롯 B 는 펑크션 행에서만 동작.

## 레이아웃 렌더링

### KeyboardMetrics

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
        return [
            [leftCol[0], .consonant(.ㅃ), .consonant(.ㅉ), .consonant(.ㄸ), .consonant(.ㄲ), .consonant(.ㅆ), .symbol("!")],
            [leftCol[1], .consonant(.ㅂ), .consonant(.ㅈ), .consonant(.ㄷ), .consonant(.ㄱ), .consonant(.ㅅ), .symbol("?")],
            [leftCol[2], .consonant(.ㅁ), .consonant(.ㄴ), .consonant(.ㅇ), .consonant(.ㄹ), .consonant(.ㅎ), .symbol(".")],
            [leftCol[3], .consonant(.ㅋ), .consonant(.ㅌ), .consonant(.ㅊ), .consonant(.ㅍ), .backspaceWide],
        ]
    }
}
```

### KeyboardSettings 변경

```swift
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
```

## UI 디자인

### 진입 경로

`설정 → 입력 (모아키 입력) → 레이아웃 커스터마이즈` (신규 NavigationLink).

InputSettingsView 의 기존 "레이아웃" 섹션 (좌우 특수키 크기 슬라이더) 위에 새 섹션 추가:

```swift
Section {
    NavigationLink(destination: LayoutCustomizationView()) {
        Label("레이아웃 커스터마이즈", systemImage: "rectangle.3.group")
    }
} footer: {
    Text("우측/좌측 컬럼 키와 스페이스 옆 키를 사용자 정의합니다.")
}
```

진입 후 LayoutCustomizationView 의 구조 (4 섹션):

1. **현재 키보드 미리보기** — `KeyboardPreviewView` 재사용. 슬롯 변경 시 즉시 갱신. 슬롯 A/B/C 섹션 헤더 탭 시 해당 슬롯 영역 강조.
2. **우측 컬럼 (슬롯 A)** — 라디오 (모음 / 1.1 특수문자) + 토글 (백스페이스 ↔ ㆍ swap, A1 일 때만 활성)
3. **스페이스 옆 키 (슬롯 B)** — 라디오 (특수문자 / 모음 키)
4. **좌측 컬럼 (슬롯 C)** — 4 셀 텍스트 편집 (탭 시 alert) + 초기화 버튼

### 첫 실행 모달

`MoaPlus/ContentView.swift` 의 onAppear 에 체크 추가:

```swift
.onAppear {
    if !KeyboardSettings.shared.firstLaunchModalShown {
        showFirstLaunchModal = true
    }
}
.sheet(isPresented: $showFirstLaunchModal) {
    FirstLaunchLayoutModalView()  // 신규
}
```

`FirstLaunchLayoutModalView` 구조:
- 큰 키보드 아이콘 + "키보드 모드를 선택하세요" 제목
- 안내문 (한국어)
- 두 옵션 (각각 mini KeyboardView 미리보기 이미지 + 라벨):
  - "모던 (현재)" → A1 / B2 / C 기본값
  - "클래식 1.1" → A2 / B1 / C 기본값
- "나중에" 버튼 (dismiss without selection)
- dismiss 시 `firstLaunchModalShown = true` 저장

## 슬롯 동작 상세

### B1 모음 키 동작
`slotBVowelKey` 는 자음 키와 동일한 GestureAnalyzer + VowelResolver 호출하되 자음 prefix 없이 모음만 출력:
- tap (드래그 임계값 미달) → `ㆍ` 입력 (HangulComposer.combineDot 경유)
- 드래그 → VowelResolver.resolve(directions:) 결과의 모음만 입력
- 멀티 스트로크 합성은 호출 안 함 (단일 스트로크만)

### Long-press number 매핑
- A1: 기존 `longPressNumbers` 유지
- A1 swap = ON: row 1 col 6 = ㆍ (long-press 없음), row 3 col 6 = ⌫ (long-press 없음)
- A2: col 6 의 키들이 ! ? . / wide ⌫ — long-press number 의미 없음 (nil)

## 테스트

기존 단위 테스트 영향 없음 (`HangulComposer` / cursor / shift / vowel drag).

신규 테스트:
- `LayoutCustomizationTests` — Codable 직렬화, default 값, swap 토글 효과
- `KeyboardMetricsLayoutTests` — A1/A1-swap/A2 각각의 `koreanLayout(_:)` 결과 키 위치 검증
- `KeyboardSettingsLayoutTests` — App Group 저장/로드 round-trip
- `FirstLaunchModalTests` — 첫 실행 시 모달 표시, 선택 시 layoutCustomization 정확히 적용

수동 QA:
- A1 / A1-swap / A2 전환 → 키보드 즉시 반영
- 슬롯 C 셀 편집 → 즉시 반영, 빈 입력 시 alert 거부
- 첫 실행 모달 → 두 옵션 선택 후 layoutCustomization 정확히 적용
- 슬롯 시각 표시 — 섹션 헤더 탭 시 미리보기 강조 정상

## 범위 외 (Out of scope)

- 자음 배치 (col 1~5) 사용자 정의 → v3
- 영문 모드 / 심볼 모드 레이아웃 커스터마이즈 → 현재 대상 아님
- col 0/6 의 long-press 패턴 사용자 정의 → 별도 SecondaryKeyAction 시스템 영역
- 함수 행 (123, 한, ⏎) 위치 변경 → v3
- Telemetry / preset usage 측정 → v1.5 이후 검토
- A3 풀 패키지 (col 6 에 모든 키 박는 macro) → 사용 시나리오 빈약, 영구 보류

## 마이그레이션 노트

- `LayoutCustomization` 의 default 값이 1.3 동작과 100% 일치 → 마이그레이션 코드 0 줄
- 기존 사용자가 첫 실행 시 디스크에 키 없으면 `LayoutCustomization()` 생성 → save() → 이후 정상 흐름
- `firstLaunchModalShown` default = false → 1.3 사용자 업데이트 후 첫 실행 시 모달 표시
- Codable 디코딩 실패 시 `try?` 패턴 (기존 themeSettings 와 동일)

## 의문점 / 후속 결정

1. **슬롯 시각 표시의 강조 스타일** — 테두리 색? 배경 색? 라이브 애니메이션? 디자인 단계에서 결정.
2. **첫 실행 모달의 미니 이미지** — 정적 PNG 자산 vs 라이브 KeyboardView 캡처. 라이브 캡처가 테마 반영 가능하지만 비용 ↑.
3. **슬롯 C 셀의 편집 상한 (현재 4자 권장)** — UI 폭 측정 후 결정.
4. **첫 실행 모달 dismiss 후 재표시 메커니즘** — "앱 정보" 메뉴에 버튼 vs 안 둠. 사용자가 모달 보고 싶을 일이 거의 없으면 안 두는 게 깔끔.

---

## 다음 단계

`writing-plans` 스킬로 구현 계획 (TDD 단위 분해 + 작업 순서 + 위험 부분) 을 v2 spec 에 맞게 재작성. 기존 `docs/superpowers/plans/2026-05-08-keyboard-layout-customization.md` 를 동일 파일에 덮어쓰기 (16 → ~14 task 로 축소 예상).

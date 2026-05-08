# 키보드 레이아웃 커스터마이즈 — 설계 문서

- 날짜: 2026-05-08
- 대상 버전: v1.4 (build 7)
- 동기: App Store 1.2 리뷰 다수 — 1.1 무모음 레이아웃 선호 + 백스페이스 위치 변경 부담 + 스페이스바 옆 키 용도 변경 요청

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

#### 슬롯 A — 3 프리셋

```
A1. 모음 (기본, 현재 1.3)            A2. 1.1 특수문자                   A3. col 6 풀 패키지
~  ㅃ ㅉ ㄸ ㄲ ㅆ  #                 ~  ㅃ ㅉ ㄸ ㄲ ㅆ  !               ~  ㅃ ㅉ ㄸ ㄲ ㅆ  #
^  ㅂ ㅈ ㄷ ㄱ ㅅ  ⌫                 ^  ㅂ ㅈ ㄷ ㄱ ㅅ  ?               ^  ㅂ ㅈ ㄷ ㄱ ㅅ  [B1 모음]
;  ㅁ ㄴ ㅇ ㄹ ㅎ  ㅣ                 ;  ㅁ ㄴ ㅇ ㄹ ㅎ  .               ;  ㅁ ㄴ ㅇ ㄹ ㅎ  [B2 특수문자]
*  ㅋ ㅌ ㅊ ㅍ  ㅡ ㆍ                 *  ㅋ ㅌ ㅊ ㅍ  [⌫⌫ wide]         *  ㅋ ㅌ ㅊ ㅍ  [⌫⌫ wide]
```

A2/A3 의 row 3 백스페이스 = `col 5 + col 6` 가로 2칸 ("엔터처럼 길게").

**A3 ≠ 단순 프리셋** — 슬롯 B 자동 비활성 + 펑크션 행에서 B 키 제거 + 스페이스바 길어짐.

#### 슬롯 B — 2 프리셋

| 프리셋 | 동작 |
|---|---|
| **B2 특수문자 (기본)** | tap=`.` ←=`?` →=`!` ↑=`,` ↓=`.` (현재 1.3 동작 유지) |
| **B1 모음 키** | tap=`ㆍ`, 8방향 드래그 = 자음 키 드래그와 동일한 단일 모음 매핑 (합성 X) |

A3 일 때 슬롯 B 자체가 사라지므로 B1/B2 설정은 무의미.

#### 슬롯 C — 셀 단위 사용자 매핑

- 프리셋 선택 개념 없음
- 4 셀 (row 0~3) 각각 사용자가 자유 매핑
- 기본값: `~` `^` `;` `*` (현재 1.3 동작)
- 셀당 최소 1 자 강제 (빈 문자열 금지 → 레이아웃 밀림 방지)
- 셀당 최대 4 자 권장 (UI 표시 고려)

### 3. 기본값 + 마이그레이션

| 슬롯 | 새 사용자 default | 1.3 사용자 마이그레이션 |
|---|---|---|
| A | A1 모음 | 자동 (변화 없음) |
| B | B2 특수문자 | 자동 (변화 없음) |
| C | `~^;*` | 자동 (변화 없음) |

→ **1.3 사용자는 업데이트 후 동작 변화 0**. 1.1 스타일을 원하는 사용자만 설정에서 슬롯 A → A2, B → B1 으로 전환 (혹은 A → A3 풀 패키지).

## 데이터 모델

```swift
// MoaPlusKeyboard/Models/LayoutCustomization.swift (신규)

enum SlotAPreset: String, Codable, CaseIterable {
    case vowel        // A1 — 모음 (기본)
    case classic11    // A2 — 1.1 특수문자
    case fullPackage  // A3 — col 6 풀 패키지
}

enum SlotBPreset: String, Codable, CaseIterable {
    case punctuation  // B2 — 특수문자 (기본)
    case vowelKey     // B1 — 모음 키 (8방향)
}

struct LayoutCustomization: Codable, Equatable {
    var slotA: SlotAPreset = .vowel
    var slotB: SlotBPreset = .punctuation
    var slotC: [String] = ["~", "^", ";", "*"]

    /// A3 일 때 슬롯 B 효과 무시
    var effectiveSlotB: SlotBPreset? {
        slotA == .fullPackage ? nil : slotB
    }
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

    // 신규
    case backspaceWide       // row 3 의 가로 2칸 ⌫
    case slotBVowelKey       // A3 의 col 6 row 1 (B1 동작)
    case slotBPunctuation    // A3 의 col 6 row 2 (B2 동작)
}
```

### KeyboardSettings 변경

```swift
@Published var layoutCustomization: LayoutCustomization = LayoutCustomization() {
    didSet {
        guard !isLoading else { return }
        save(layoutCustomization, key: Keys.layoutCustomization)
    }
}
```

`Keys.layoutCustomization = "layoutCustomization"` 신규. App Group `group.com.moaki.keyboard` UserDefaults 에 JSON 직렬화. 기존 `themeSettings` 패턴 그대로.

## 레이아웃 렌더링

### KeyboardMetrics

`koreanLayout` 을 static 상수에서 함수로 변경:

```swift
static func koreanLayout(_ layout: LayoutCustomization) -> [[KeyContent]] {
    let leftCol = layout.slotC.map { KeyContent.symbol($0) }
    switch layout.slotA {
    case .vowel:        return /* 현재 그대로, col 0 = leftCol */
    case .classic11:    return /* col 6 = !, ?, ., backspaceWide */
    case .fullPackage:  return /* col 6 = #, slotBVowelKey, slotBPunctuation, backspaceWide */
    }
}
```

### Wide backspace 렌더링

`columnCount(for: row, mode:)` 가 row 3 에 대해 6 반환 (col 0~4 + wide bksp 한 칸). `keyWidth` 함수에 `.backspaceWide` 분기 추가하여 `2 * centerKeyWidth + spacing` 폭 계산.

### 펑크션 행

```swift
static func functionRowKeys(mode: KeyboardMode, layout: LayoutCustomization) -> [FunctionKey] {
    if mode == .korean && layout.slotA == .fullPackage {
        return [.symbolToggle, .letterToggle, .space, .returnKey]   // long-space
    }
    return [.symbolToggle, .letterToggle, .space, .slotBKey, .returnKey]
}
```

`SpaceKeyView` 폭 계산은 남은 공간 채우는 방식이라 자동 길어짐.

## UI 디자인

### 진입 경로

`설정 → 입력 → 레이아웃 커스터마이즈` (신규 NavigationLink). InputSettingsView 한 줄 추가.

### 레이아웃 커스터마이즈 화면

단일 화면 + 라이브 프리뷰. 섹션 구성:

```
┌─────────────────────────────┐
│  ‹ 입력  레이아웃 커스터마이즈    │
├─────────────────────────────┤
│  미리보기                       │
│  [실제 KeyboardView 렌더링]    │  ← layoutCustomization 변화 시 즉시 갱신
├─────────────────────────────┤
│  우측 컬럼 (슬롯 A)               │
│  ◉ 모음 (현재)                  │
│  ○ 1.1 특수문자                 │
│  ○ 풀 패키지 (스페이스 옆 비활성)  │
├─────────────────────────────┤
│  스페이스 옆 키 (슬롯 B)          │
│  ◉ 특수문자 (현재)              │  ← A3 일 때 disabled
│  ○ 모음 키                     │
├─────────────────────────────┤
│  좌측 컬럼 (슬롯 C)               │
│  셀 매핑  [ ~ ][ ^ ][ ; ][ * ]   │  ← 셀 탭 → UIAlertController
│  [기본값으로 초기화]              │
└─────────────────────────────┘
```

라이브 프리뷰는 기존 `Appearance preview` 패턴 (KeyboardView 직접 렌더) 재사용.

## 슬롯 동작 상세

### B1 모음 키 동작

`slotBVowelKey` 는 자음 키와 동일한 GestureAnalyzer + VowelResolver 호출하되 자음 prefix 없이 모음만 출력:
- tap (드래그 임계값 미달) → `ㆍ` 입력 (HangulComposer.combineDot 경유)
- 드래그 → VowelResolver.resolve(directions:) 결과의 모음만 입력
- 멀티 스트로크 합성은 호출 안 함 (단일 스트로크만)

### A3 의 backspaceWide

A2/A3 모두 row 3 의 backspaceWide 사용. 동일한 KeyContent 케이스 + 동일한 keyWidth 처리. backspace 동작은 기존 `.backspace` 와 동일 (`viewModel.beginBackspacePress` / `endBackspacePress`).

### Long-press number 매핑

- A1: 기존 `longPressNumbers` 유지
- A2/A3: col 6 의 키들이 ! ? . / B1 / B2 / # 등 — long-press number 의미 없음. col 6 long-press 매핑 nil.
- col 1~5 의 자음 long-press number 는 모든 프리셋에서 동일.

## 테스트

기존 단위 테스트 영향 없음 (`HangulComposer` / cursor / shift / vowel drag).

신규 테스트:
- `LayoutCustomizationTests` — Codable 직렬화, default 값
- `KeyboardMetricsLayoutTests` — A1/A2/A3 각각의 `koreanLayout(_:)` 결과 키 위치 검증
- `KeyboardSettingsLayoutTests` — App Group 저장/로드 round-trip

수동 QA:
- A1/A2/A3 전환 → 키보드 즉시 반영
- A3 선택 → 슬롯 B 옵션 disabled, 스페이스 길어짐 확인
- C 셀 편집 → 즉시 반영, 빈 입력 시 alert 거부

## 범위 외 (Out of scope)

- 자음 배치 (col 1~5) 사용자 정의 → v3
- 영문 모드 / 심볼 모드 레이아웃 커스터마이즈 → 현재 대상 아님
- col 0/6 의 long-press 패턴 사용자 정의 → 별도 SecondaryKeyAction 시스템 영역
- 함수 행 (123, 한, ⏎) 위치 변경 → v3

## 마이그레이션 노트

- `LayoutCustomization` 의 default 값이 1.3 동작과 100% 일치 → 마이그레이션 코드 0 줄
- 기존 사용자가 첫 실행 시 디스크에 키 없으면 `LayoutCustomization()` 생성 → save() → 이후 정상 흐름
- Codable 디코딩 실패 (예: 키 손상) 시 `try?` 패턴으로 nil → default 값 사용 (기존 themeSettings 와 동일 fallback)

## 의문점 / 후속 결정

1. **슬롯 C 셀의 편집 상한 (현재 4자 권장)** — UI 폭 측정 후 결정
2. **A3 일 때 슬롯 C 의 매핑이 `~ ^ ; *` 아닌 사용자 정의일 경우 충돌 없는지** — 슬롯 A 와 슬롯 C 는 col 0 / col 6 으로 직교라 충돌 없음 (확인됨)
3. **롱프레스 (long-press) 가 슬롯 B 키에 작동할지** — 현재 펑크션 행 키들은 long-press 없음. 신규 슬롯 B 키도 동일 (no long-press)

---

## 다음 단계

`writing-plans` 스킬로 구현 계획 (TDD 단위 분해 + 작업 순서 + 위험 부분) 을 별도 문서로 작성.

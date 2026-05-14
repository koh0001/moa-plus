# 영문 자판 긋기 펑크 키 + 슬롯 커스터마이즈 디자인 스펙

- **작성일**: 2026-05-15
- **상태**: 디자인 승인 대기
- **관련 모듈**: `MoaPlusKeyboard` (Views, Models, Utilities), `MoaPlus/Settings/LayoutCustomizationView`

## 1. 배경 & 목표

현재 한글 모드 function row에는 `[123/한글] [한/영] [space] [긋기 펑크] [⏎]` 구조로
긋기 펑크 키가 존재하지만, 영문 모드는 `longSpaceLayoutBody`로 분기돼
긋기 펑크 키가 빠지고 스페이스가 그 폭을 흡수한다 (`FunctionRowView.swift:39-47`).

또한 한글 모드 긋기 펑크 키의 5개 슬롯 — tap=`.`, ←=`?`, →=`!`, ↑=`,`, ↓=`.` —
은 `PunctuationSwipeKey` 내부에 **하드코딩**돼 있어 사용자가 바꿀 수 없다.

### 사용자 요구사항

1. 영문 자판 스페이스 옆에도 긋기 펑크 키 추가 (설정 토글 ON/OFF)
2. 각 슬롯에 들어가는 내용을 **자유 텍스트**로 커스텀 가능 (제한 없음)
3. 한글/영문 각각 독립 토글, 빈 슬롯은 무동작 (tap fallback 없음)
4. 한글 자판 A1 프리셋의 col 6 row 0 (기본 `#` 자리)에도 옵션으로 긋기 펑크 키 적용 가능

## 2. 데이터 모델

### 2.1 신규 타입 `PunctuationSlots`

```swift
struct PunctuationSlots: Codable, Equatable {
    var tap: String
    var left: String
    var right: String
    var up: String
    var down: String

    /// 빈 문자열("") = 비활성. 해당 방향 드래그/탭은 입력 무시.
    static let defaultKorean = PunctuationSlots(tap: ".", left: "?", right: "!", up: ",", down: ".")
    static let defaultEnglish = PunctuationSlots(tap: ".", left: "?", right: "!", up: ",", down: ".")
}
```

### 2.2 `LayoutCustomization` 확장

기존 필드는 유지하고 다음을 추가:

```swift
var koreanPunctuationEnabled: Bool = true          // 기존 동작 유지 (regression 없음)
var englishPunctuationEnabled: Bool = false        // 신규 — 기본 OFF
var koreanPunctuationSlots: PunctuationSlots = .defaultKorean
var englishPunctuationSlots: PunctuationSlots = .defaultEnglish
var slotARightColumnTopAsPunctuation: Bool = false // A1 # 자리 옵션
```

### 2.3 Codable 마이그레이션

`LayoutCustomization.init(from:)`의 `decodeIfPresent` 패턴을 그대로 따른다:

- 기존 사용자: 모든 신규 필드가 기본값으로 채워짐
- `koreanPunctuationSlots` 기본값이 현재 하드코딩 동작과 동일 → 동작 변화 없음
- `englishPunctuationEnabled = false` → 영문 모드 동작 변화 없음

## 3. 렌더링 변경

### 3.1 `PunctuationSwipeKey` 일반화

현재 시그니처 (FunctionRowView.swift:315):

```swift
struct PunctuationSwipeKey: View {
    let width: CGFloat
    let height: CGFloat
    let onPunctuation: (String) -> Void
    // ... 5문자 하드코딩
}
```

변경 후:

```swift
struct PunctuationSwipeKey: View {
    let width: CGFloat
    let height: CGFloat
    let slots: PunctuationSlots         // 신규
    let onPunctuation: (String) -> Void
}
```

내부 변경:

- 미리보기 텍스트 = `slots.tap/left/right/up/down`
- 빈 슬롯은 해당 위치 Text를 hidden (투명) 처리
- 미리보기 폰트 자동 축소: 1자=16pt, 2자=12pt, 3자+=10pt (탭 슬롯 기준)
- 드래그/탭 핸들러에서 빈 문자열이면 `onPunctuation` 호출 안 함

### 3.2 `FunctionRowView` 분기 수정

현재 line 39-47 분기를 다음으로 교체:

```swift
private var punctuationEnabledForMode: Bool {
    if mode.isSymbol { return false }              // 심볼 모드는 스코프 밖
    return mode == .korean
        ? layoutCustomization.koreanPunctuationEnabled
        : layoutCustomization.englishPunctuationEnabled
}

var body: some View {
    if useBimanualLayout {
        bimanualLayoutBody
    } else if !punctuationEnabledForMode || layoutCustomization.slotA == .fullPackage {
        longSpaceLayoutBody
    } else {
        defaultLayoutBody
    }
}
```

`slotBKey(width:)`의 `.punctuation` 케이스는 모드에 따라 슬롯 데이터를 주입:

```swift
case .punctuation:
    let slots = mode == .korean
        ? KeyboardSettings.shared.layoutCustomization.koreanPunctuationSlots
        : KeyboardSettings.shared.layoutCustomization.englishPunctuationSlots
    PunctuationSwipeKey(width: width, height: height, slots: slots, onPunctuation: onPunctuation)
```

### 3.3 `ConsonantGridView` A1 # 자리 옵션

`slotA == .vowel && slotARightColumnTopAsPunctuation == true`일 때
col 6 row 0의 `#` (심볼 토글) 버튼을 `PunctuationSwipeKey`로 교체.
한글 슬롯 데이터(`koreanPunctuationSlots`)를 공유한다.

심볼 모드 진입은 function row의 `[!#1]` 토글로 가능하므로 접근성 손실 없음.

## 4. 입력 흐름

`KeyboardViewModel.onPunctuation(_:)` 경로는 그대로 유지:

1. `commitCurrent()` — 미확정 한글 확정
2. `flushCommittedText()`
3. `proxy.insertText(symbol)`
4. 햅틱 트리거

자유 텍스트("ㅎㅎ", "👍", "..." 등)도 단일 `insertText` 호출로 처리.
`autoBracketEnabled`는 펑크 슬롯엔 적용하지 않음 (사용자 의도 그대로 출력).

## 5. 설정 UI (`LayoutCustomizationView`)

신규 섹션 "**긋기 펑크 키**":

### 한글 자판 블록

- 토글: `사용 (function row 우측)` → `koreanPunctuationEnabled`
- 토글: `A1 # 자리에도 표시` → `slotARightColumnTopAsPunctuation` (slotA == .vowel일 때만 노출)
- 라이브 미리보기: 실제 키 모양 (3행 십자가 레이아웃)
- 5개 텍스트필드 (tap/←/→/↑/↓), placeholder = 기본값
- "기본값으로 되돌리기" 버튼

### 영문 자판 블록

- 토글: `사용 (스페이스 폭이 줄어듭니다)` → `englishPunctuationEnabled`
- 라이브 미리보기
- 5개 텍스트필드
- "기본값으로 되돌리기" 버튼

### UX 디테일

- 토글 OFF면 텍스트필드 영역 비활성(dim) 또는 접힘
- 빈 슬롯은 미리보기에서 글자 숨김 (사용자가 빈 슬롯 효과 즉시 확인)
- 입력 길이 무제한 수용. 너무 길면 "키에 표시되지 않을 수 있습니다" hint
- `KeyboardSettings`의 App Group 경유라 키보드 익스텐션이 darwin notification 받아 즉시 반영

## 6. 테스트 계획

### 단위 테스트 (`MoaPlusKeyboardTests`)

- `PunctuationSlots` Codable round-trip
- `LayoutCustomization` legacy data 디코딩 → 신규 필드 모두 기본값
- 빈 슬롯 가드 — `PunctuationSwipeKey` 콜백이 빈 슬롯에선 호출되지 않음

### 수동 검증 (실기기)

- 영문 토글 OFF → 기존처럼 긴 스페이스 (regression 없음)
- 영문 토글 ON → 스페이스 폭 감소 + 펑크 키 등장 + 5방향 정상 동작
- A1 # 자리 옵션 ON → # 버튼이 펑크 키로 교체. 심볼 진입은 `[!#1]` 토글로 확인
- 한글 슬롯 변경 시 function row와 A1 # 자리 양쪽에 즉시 반영 (App Group 동기화)
- 자유 텍스트 입력 (이모지, 한글, 다중 문자) 시 정상 삽입 + 미확정 한글 commit

## 7. 영향 받는 파일

- `MoaPlusKeyboard/Models/LayoutCustomization.swift` — 필드 + 마이그레이션
- `MoaPlusKeyboard/Views/FunctionRowView.swift` — 분기 수정 + `PunctuationSwipeKey` 시그니처
- `MoaPlusKeyboard/Views/ConsonantGridView.swift` — A1 # 자리 옵션 분기
- `MoaPlus/Settings/LayoutCustomizationView.swift` — 신규 섹션 UI
- `MoaPlusKeyboardTests/` — Codable + 빈 슬롯 테스트
- `scripts/add_target_membership.rb` — `LayoutCustomization.swift` 기존 멤버십 유지 (변경 없음)

## 8. 명시적으로 하지 않는 것 (YAGNI)

- 심볼 모드(`!#1`) 펑크 키 — 심볼 자판에 부호가 이미 모두 존재
- 8방향 (↖↗↙↘) 지원 — 현재 4방향+탭이 검증된 UX
- 슬롯별 햅틱/사운드 커스텀 — `HapticManager` 동작 그대로
- A2(classic11) `slotARightColumn`을 펑크 키로 교체 — 사용자 요청 범위 밖

## 9. 마이그레이션 & 호환성

- 기존 v1.4 사용자: `decodeIfPresent` 폴백으로 모든 신규 필드 기본값 채워짐
- 한글 모드 동작 = 변경 전과 픽셀/입력 모두 동일 (기본 슬롯 = 하드코딩 값)
- 영문 모드 동작 = 토글 OFF이므로 변경 전과 동일
- App Group ID 변경 없음

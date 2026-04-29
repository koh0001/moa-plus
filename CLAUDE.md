# 모아+ (Moa+) - iOS 제스처 한글 키보드

제스처 기반 한글 입력 iOS 커스텀 키보드 앱.
모아키 방식 입력을 iOS에서 구현하고, 천지인 모음 합성/약어 확장/테마/롱프레스 보조입력/영문 QWERTY 등 생산성 기능을 확장한다.

> 원본: [ios-moaki](https://github.com/vkehfdl1/ios-moaki) by Jeffrey (Dongkyu) Kim (MIT License)

## 프로젝트 구조

```
moa-plus/
├── MoaPlus/                           # 메인 앱 (홈 + 설정 + 튜토리얼 + 연습)
│   ├── MoaPlusApp.swift               # @main 진입점
│   ├── ContentView.swift              # 홈 화면 (딥블루 그라디언트)
│   ├── Settings/
│   │   ├── SettingsMainView.swift
│   │   ├── InputSettingsView.swift           # 레이아웃/커서 제어/긋기 진입점
│   │   ├── GestureSettingsView.swift         # 긋기 통합 설정 (각도/길이/방향/열별 보정)
│   │   ├── GestureTestView.swift             # 라이브 시각화 테스트 (production resolver 사용)
│   │   ├── SecondaryInputSettingsView.swift  # 롱프레스 매핑 편집/힌트/딜레이
│   │   ├── AbbreviationSettingsView.swift    # 단축어 CRUD
│   │   ├── AppearanceSettingsView.swift      # 테마/커스텀 색상/배경 이미지/키 투명도
│   │   ├── FeedbackSettingsView.swift        # 햅틱/사운드/백스페이스 속도/단어 삭제
│   │   └── AboutView.swift                   # 크레딧/라이선스/링크
│   ├── Practice/
│   │   ├── TypingPracticeView.swift          # 타이핑 연습 화면
│   │   └── TypingPracticeData.swift          # 33개 연습 항목 (천지인/영문/커서)
│   └── Tutorial/                      # 8단계 튜토리얼 (딥블루 테마)
│
├── MoaPlusKeyboard/                   # 키보드 익스텐션
│   ├── KeyboardViewController.swift   # UIKit 진입점 (260pt 고정 높이)
│   ├── Engine/
│   │   ├── HangulComposer.swift       # 한글 조합 상태머신 (6 cases: empty/choseong/choseongJungseong/complete/standaloneVowel/dotPending)
│   │   ├── GestureAnalyzer.swift      # 제스처 방향 분석 (설정 연동, 열별 보정)
│   │   ├── VowelResolver.swift        # 방향→모음 변환 (커스텀 대각선 매핑)
│   │   └── AbbreviationEngine.swift   # Trie 기반 약어 확장 + backspace 복원 + resetBuffer
│   ├── Models/
│   │   ├── HangulJamo.swift           # 초/중/종성 enum (한글 멤버명: .ㄱ .ㅏ 등, Jungseong.ㆍ 포함)
│   │   ├── GestureDirection.swift     # 8방향 enum
│   │   ├── VowelPattern.swift         # 21개 모음 패턴 + PatternTrie (멀티 스트로크)
│   │   ├── SwipeProfile.swift         # 긋기 프리셋 + DirectionSector + DiagonalMapping
│   │   ├── ColumnGestureOverride.swift
│   │   ├── KeyboardMode.swift         # korean/english/symbolFromKorean/symbolFromEnglish 모드
│   │   ├── SecondaryKeyAction.swift   # 키별 롱프레스 매핑 (한글 자음 + 영문 숫자)
│   │   ├── ShortcutExpansion.swift    # 약어 데이터 + Store
│   │   └── ThemeSettings.swift        # 테마/CodableColor/ButtonTheme + resolved 색상
│   ├── ViewModels/
│   │   └── KeyboardViewModel.swift    # 입력 흐름 총괄 + 모드/Shift/커서 관리
│   ├── Views/
│   │   ├── KeyboardView.swift         # 메인 키보드 + 롱프레스 팝업 오버레이
│   │   ├── ConsonantGridView.swift    # 자음/모음/영문 그리드 (모드 분기)
│   │   ├── ConsonantKeyView.swift     # 개별 키 (테마/힌트/사이드/모음 미리보기/Shift 대문자)
│   │   ├── FunctionRowView.swift      # 하단 기능키 (한/영 + 긋기 + space drag)
│   │   ├── GestureOverlayView.swift   # 제스처 시각화
│   │   └── AbbreviationCandidateView.swift  # 약어 후보 바
│   └── Utilities/
│       ├── HangulConstants.swift      # composeSyllable (.ㆍ 가드)
│       ├── KeyboardMetrics.swift      # 한글/영문/심볼 layout + 모드별 keyWidth/centerKeyWidth
│       ├── KeyboardSettings.swift     # App Group 싱글톤 (isLoading 가드)
│       ├── GestureSettings.swift
│       ├── HapticManager.swift        # 설정을 매번 직접 읽음 (캐시 없음)
│       └── BackgroundImageManager.swift
│
├── MoaPlusKeyboardTests/             # 유닛 테스트 (HangulComposer + Cursor + Shift + VowelDrag)
├── scripts/
│   └── add_target_membership.rb       # xcodeproj 자동 멤버십 추가 (메인 앱 ↔ 익스텐션)
└── docs/                             # 개발 문서
```

## 핵심 아키텍처

```
┌──────────────────────────────────────────────────┐
│ MoaPlus (메인 앱)                                  │
│   ContentView → 튜토리얼 / 설정 / 연습              │
│   ├── GestureTestView → production resolver       │
│   └── ↕ App Group (group.com.moaki.keyboard)     │
├──────────────────────────────────────────────────┤
│ MoaPlusKeyboard (키보드 익스텐션)                    │
│                                                  │
│   KeyboardViewController (UIKit)                 │
│        ↓                                         │
│   KeyboardView (SwiftUI) — mode-aware            │
│        ↓                                         │
│   KeyboardViewModel                              │
│        ├── keyboardMode: KeyboardMode (4 cases)  │
│        ├── shiftState: ShiftState                │
│        ├── HangulComposer (6-state machine)      │
│        │   └── dotPending → 천지인 누적            │
│        ├── GestureAnalyzer (방향 분석)             │
│        ├── VowelResolver (모음 trie)              │
│        └── AbbreviationEngine + resetBuffer       │
│              ↓                                   │
│   HapticManager → AudioToolbox → 출력             │
└──────────────────────────────────────────────────┘
```

## 빌드 및 테스트

```bash
# Xcode에서 열기
open MoaPlus.xcodeproj

# 빌드 (시뮬레이터)
xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16'

# 단위 테스트는 Xcode에서 Cmd+U 실행 (CLI test scheme TEST_HOST 미수리)
```

실기기: `Cmd + R` → 아이폰에서 설정 → 키보드 → 새 키보드 추가 → 모아+

## 주의사항

### 필수 규칙
- `insertText()` 호출 전 `flushCommittedText()`로 확정 텍스트 획득 필수
- `KeyboardSettings.loadAll()`은 `isLoading` 플래그로 didSet 재저장을 방지 — 새 설정 추가 시 반드시 가드 포함
- App Group ID는 `group.com.moaki.keyboard` — 변경하면 기존 사용자 설정 소실
- `Jungseong` enum 멤버명은 한글 (`Jungseong.ㅏ`, `Jungseong.ㅣ`, `Jungseong.ㆍ` 포함)
- 신규 enum 케이스 추가 시 exhaustive switch 모두 점검 (`HangulComposer.State`, `KeyboardMode`, `FunctionalKeyType` 등)
- 익스텐션 핵심 파일 메인 앱 타겟에도 멤버십 추가 — `scripts/add_target_membership.rb` 사용 (Engine/, Models/, Utilities/ 일부)

### 아키텍처 제약
- iOS 키보드 익스텐션 메모리 한계 ~30MB
- `KeyboardViewController`는 UIKit, 나머지는 SwiftUI
- 롱프레스 팝업은 KeyboardView 최상위 ZStack에서 렌더링 (z-order 클리핑 방지)
- `HapticManager`는 `KeyboardSettings.shared.themeSettings`를 computed property로 매번 읽음
- 클릭 사운드는 `AudioServicesPlaySystemSound(1104)` 사용 (`playInputClick`은 익스텐션에서 불안정)
- `clickSoundEnabled`는 ThemeSettings 밖에 독립 Bool로 저장 (Codable 디코딩 실패 방지)
- Timer는 `[weak self]` + `RunLoop.main.add(forMode: .common)` 필수 (UI scroll lockup 방지)
- Combine sink (GestureTestModel 등)는 `[weak self]` 필수
- iOS 키보드 익스텐션 marked text 미지원 → `updateComposingText`가 delete+insert로 시뮬레이션. 커서 이동 전 `commitCurrent()` 필수

### 모드 시스템
```swift
enum KeyboardMode {
    case korean              // 한글 입력 (자음+8방향 + 천지인 키)
    case english             // 영문 QWERTY (4행: 숫자/qwe/asd/shift+zxc+⌫)
    case symbolFromKorean    // 심볼 (123) — 한글 모드에서 진입
    case symbolFromEnglish   // 심볼 (123) — 영문 모드에서 진입
}
// toggleSymbol() — 123 ↔ letter
// toggleLetter() — 한↔영 (심볼 모드에서 누르면 letter로 복귀)

enum ShiftState {
    case off, on, locked
}
// 영문 모드에서만 활성. tap=on(single), double-tap=locked(caps)
// 한 글자 입력 후 .on → .off 자동 release
```

### HangulComposer State (6 cases)
```swift
enum State: Equatable {
    case empty
    case choseong(Choseong)
    case choseongJungseong(Choseong, Jungseong)
    case complete(Choseong, Jungseong, Jongseong)
    case standaloneVowel(Jungseong)              // 자음 없는 모음 (이모티콘 ㅜㅜ + 천지인 합성용)
    case dotPending(choseong: Choseong?, dotCount: Int)  // ㆍ 누적 (1-2 dots, 3-stroke 천지인)
}
```

### 한글 레이아웃 (7-col × 4-row, 모든 row 동일 폭)
```
| col 0 | col 1 | col 2 | col 3 | col 4 | col 5 | col 6     |
|-------|-------|-------|-------|-------|-------|-----------|
|  ~    |  ㅃ   |  ㅉ   |  ㄸ   |  ㄲ   |  ㅆ   |  #        |
|  ^    |  ㅂ   |  ㅈ   |  ㄷ   |  ㄱ   |  ㅅ   |  ⌫       |
|  ;    |  ㅁ   |  ㄴ   |  ㅇ   |  ㄹ   |  ㅎ   |  ㅣ       |
|  *    |  ㅋ   |  ㅌ   |  ㅊ   |  ㅍ   |  ㅡ   |  ㆍ       |
```
- col 0 = sideWidth (sideKeyWidthRatio × centerKeyWidth, 기본 0.7)
- col 6 = sideWidth × 1.3 (그리드 정렬용 통일 폭)
- centerKeyWidth = (totalWidth - 8×spacing) / (sideRatio×2.3 + 5)
- 가운데 정렬 (좌우 마진 ~4pt at iPhone 14)

### 영문 레이아웃 (10-col × 4-row)
```
Row 0: 1 2 3 4 5 6 7 8 9 0       (10키, 롱탭→ ! @ # $ % ^ & * ( ))
Row 1: q w e r t y u i o p       (10키)
Row 2: a s d f g h j k l         (9키, 우측 1슬롯 여백)
Row 3: ⇧ z x c v b n m ⌫        (9키, shift+letter+backspace)
```
- 모든 키 균등 폭 (centerKeyWidth = availableWidth / 10)
- letter 키는 일반 색상, 숫자/shift/⌫ 는 functionKey 색상
- Shift on/locked 시 letter 키 표시 대문자 (ConsonantKeyView)

### Function Row
`[123/한글] [한/영] [space (drag→커서)] [긋기 펑크] [⏎]`
- 긋기 펑크: tap=`.`, ←=`?`, →=`!`, ↑=`,`, ↓=`.`
- Space 드래그: 8pt 임계값, 12pt/step → `moveCursor(by:)` (commitCurrent + abbreviation reset 후 proxy 커서 이동)

### 천지인 합성 규칙
**단독 키 입력:**
- ㅣ tap = ㅣ
- ㅡ tap = ㅡ
- ㆍ tap = ㆍ (pending, 다음 입력 대기)

**모음 키 4방향 드래그 (single):**
| 키 | ← | → | ↑ | ↓ |
|----|----|----|----|----|
| ㅣ | ㅓ | ㅏ | ㅕ | ㅑ |
| ㅡ | ㅛ | ㅠ | ㅗ | ㅜ |

**멀티 스트로크 (3 directions):**
| ㅡ 패턴 | 결과 | ㅣ 패턴 | 결과 |
|---------|------|---------|------|
| ↑→ | ㅘ | ←→ | ㅔ |
| ↑→← | ㅙ | →← | ㅐ |
| ↑← | ㅚ | ↑→ | ㅖ |
| ↓← | ㅝ | ↓→ | ㅒ |
| ↓←→ | ㅞ | | |
| ↓→ | ㅟ | | |

**천지인 누적 합성 (HangulComposer.combineVowels):**
```
ㅣ + ㆍ = ㅏ        ㆍ + ㅣ = ㅓ        ㆍ + ㅡ = ㅗ        ㅡ + ㆍ = ㅜ
ㅏ + ㅣ = ㅐ        ㅓ + ㅣ = ㅔ        ㅑ + ㅣ = ㅒ        ㅕ + ㅣ = ㅖ
ㅏ + ㆍ = ㅑ        ㅓ + ㆍ = ㅕ        ㅗ + ㆍ = ㅛ        ㅜ + ㆍ = ㅠ
ㅗ + ㅏ = ㅘ        ㅗ + ㅐ = ㅙ        ㅗ + ㅣ = ㅚ
ㅜ + ㅓ = ㅝ        ㅜ + ㅔ = ㅞ        ㅜ + ㅣ = ㅟ
ㅡ + ㅣ = ㅢ        ㅘ + ㅣ = ㅙ        ㅝ + ㅣ = ㅞ
```

**dotPending (3-stroke ㆍ 시작):**
- ㆍ + ㆍ = pending(2)
- ㆍ + ㆍ + ㅣ = ㅕ
- ㆍ + ㆍ + ㅡ = ㅛ
- ㅇ + ㆍ + ㆍ + ㅣ = 여 (자음 + dotPending 누적 → 합성)

### 백스페이스 동작
- `.choseongJungseong` (받침 없음) → `.empty` (글자 전체 삭제. "이"→빈)
- `.complete` (받침 있음) → 받침만 제거 (한→하)
- `.dotPending` → ㆍ 카운트 1단계 감소
- `.standaloneVowel` → empty (글자 전체 삭제)

### 설정 시스템
```
KeyboardSettings (싱글톤, App Group UserDefaults, ObservableObject)
├── gestureSettings: GestureSettings        (프로필 + 열별 보정)
├── themeSettings: ThemeSettings            (테마/투명도/햅틱)
│   └── resolvedKeyBackground/KeyText/FunctionKeyBackground (커스텀 vs 프리셋)
├── secondaryKeyActions: [SecondaryKeyAction]  (한글 자음 19키 + 영문 숫자 10키)
├── shortcutExpansionStore: ShortcutExpansionStore
├── clickSoundEnabled: Bool                 (독립 저장)
├── longPressDelay: Double                  (0.2~1.0초)
├── sideKeyWidthRatio: Double               (0.15~1.0, 기본 0.7 정사각)
├── cursorMoveBySpaceDragEnabled: Bool      (Space 드래그 커서 이동, 기본 ON)
├── autoBracketEnabled: Bool
├── wordDeleteEnabled: Bool
├── wordDeleteDelay: Double
├── backspaceSpeed: Int                     (0=느림, 1=보통, 2=빠름)
├── showGesturePreview: Bool
├── showSecondaryHints: Bool
├── showDetailedHints: Bool
└── hintSize: Int                           (0=작게, 1=보통, 2=크게)
```

### 대각선 모음 매핑 (기본값)
```
↖ ↗ = ㅣ,  ↙ ↘ = ㅡ  (설정에서 변경 가능)
```
모음 제스처 전체 표: [README.md](README.md) 참조

### 커서 이동 / 약어 리셋 패턴
```swift
func moveCursor(by offset: Int) {
    commitCurrent()                     // 미확정 글자 freeze
    abbreviationEngine.resetBuffer()    // stale trie state 제거
    delegate?.moveCursor(by: offset)    // proxy.adjustTextPosition
}
```

### 신규 입력 추가 시 체크리스트
1. `HangulComposer.State` 또는 `KeyContent` 새 케이스 추가했나? → 모든 `switch` exhaustive 점검
2. `KeyboardSettings`에 새 옵션 추가했나? → `isLoading` 가드 + `loadAll()` 로드 라인 + 디스크 저장 키 모두 추가
3. `Jungseong` 새 멤버 추가했나? → `Jungseong.allCases` 영향, `HangulConstants.composeSyllable` 가드 확인
4. 메인 앱(GestureTestView 등)에서 익스텐션 코드 사용? → `scripts/add_target_membership.rb`로 타겟 멤버십 추가
5. SwiftUI View가 무거운 클래스 인스턴스 보관? → `ObservableObject` wrapper + `@StateObject` 패턴 권장

## Bundle ID

| 타겟 | Bundle ID |
|------|-----------|
| 메인 앱 | `kr.koh0001.moa-plus` |
| 키보드 | `kr.koh0001.moa-plus.keyboard` |
| App Group | `group.com.moaki.keyboard` (변경 금지) |

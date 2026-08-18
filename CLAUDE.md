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
│   │   ├── SettingsMainView.swift            # 설정 루트 + .searchable (검색)
│   │   ├── SettingsCatalog.swift             # 검색 인덱스 + 증상 라우터 공용 카탈로그
│   │   ├── HelpView.swift                    # "이럴 때 어떻게 하나요" — 증상 → 설정 라우터
│   │   ├── KeyboardSettingsView.swift        # 키보드 설정 묶음 진입점
│   │   ├── LayoutCustomizationView.swift     # 레이아웃 프리셋/슬롯/4방향 모드/키 폭
│   │   ├── KeyboardSizeSettingsView.swift    # 높이 배율 + 지구본 토글 + 실시간 미리보기
│   │   ├── GestureSettingsView.swift         # 긋기 통합 설정 (입력 방식/각도/길이/열별 보정)
│   │   ├── GestureTestView.swift             # 라이브 시각화 테스트 (production resolver 사용)
│   │   ├── LongPressSettingsView.swift       # 롱프레스 매핑 편집/힌트/딜레이
│   │   ├── BackspaceSettingsView.swift       # 백스페이스 속도/단어 단위 삭제
│   │   ├── InputBehaviorSettingsView.swift   # 괄호 자동닫기/마침표/커서 드래그/모드 기억
│   │   ├── AbbreviationSettingsView.swift    # 단축어 CRUD
│   │   ├── AppearanceSettingsView.swift      # 테마/커스텀 색상/배경 이미지/키 투명도
│   │   ├── FeedbackSettingsView.swift        # 소리 · 진동 (햅틱/클릭 사운드)
│   │   ├── SpecialCharSettingsView.swift     # ⚠️ 도달 불가 고아 화면 + 문구 오류 (HANDOFF §5)
│   │   └── AboutView.swift                   # 크레딧/라이선스/링크
│   ├── Practice/
│   │   ├── TypingPracticeView.swift          # 타이핑 연습 화면
│   │   └── TypingPracticeData.swift          # 33개 연습 항목 (천지인/영문/커서)
│   └── Tutorial/                      # 8단계 튜토리얼 (딥블루 테마)
│
├── MoaPlusKeyboard/                   # 키보드 익스텐션
│   ├── KeyboardViewController.swift   # UIKit 진입점 (아이폰 260pt × keyboardHeightScale)
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
├── MoaPlusKeyboardTests/             # 유닛 테스트 23파일 (Composer/Gesture/Layout/Snapshot/SettingsCache + ViewModel: Cursor·CaretMove·Shift·VowelDrag·Abbreviation·Period·LongPress 등)
├── "MoaPlusUITests /"                # ⚠️ 폴더명 끝에 공백. CI 미편입 — 실행하려면 우회 필요 (HANDOFF §1-4)
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
xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17'

# CLI 테스트 실행 (MoaPlusKeyboardTests + MoaPlusUITests)
xcodebuild test \
  -project MoaPlus.xcodeproj \
  -scheme MoaPlus \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

실기기: `Cmd + R` → 아이폰에서 설정 → 키보드 → 새 키보드 추가 → 모아+

CI: `.github/workflows/ci.yml`이 main 브랜치 push/PR/수동 트리거 시 GitHub Hosted Runner(`macos-15`)에서 위 명령을 자동 실행한다. 시뮬레이터는 iPhone 17 Pro → 17 → 16 Pro → 16 순서로 폴백 선택한다.

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
- **햅틱은 키를 누르는 순간 울린다** (이슈 #23). 입력 확정(손 뗄 때)이 아니다 — 긋기 키보드는
  press→release 간격이 길어 확정 시점에 울리면 반응이 늦게 느껴진다. 그리드 키는
  `gestureStarted`, 슬롯B는 `slotBVowelGestureStarted` 가 `keyPressFeedback()` 을 부르고,
  기능행 키는 `EnvironmentValues.keyPressFeedback`(KeyboardView.swift 정의)으로 주입받는다.
  **입력 메서드(`inputConsonant`/`inputSpace`/`toggleLetterMode` 등)에 햅틱을 되살리지 말 것**
  — 키 하나에 진동 두 번이 된다 (`KeyboardViewModelHapticTimingTests` 가드).
  백스페이스만 예외로 `deleteBackward()` 안에 남아 있다(자동 반복 틱마다 울려야 함)
- 클릭 사운드는 `AudioServicesPlaySystemSound(1104)` 사용 (`playInputClick`은 익스텐션에서 불안정)
- `clickSoundEnabled`는 ThemeSettings 밖에 독립 Bool로 저장 (Codable 디코딩 실패 방지)
- Timer는 `[weak self]` + `RunLoop.main.add(forMode: .common)` 필수 (UI scroll lockup 방지)
- Combine sink (GestureTestModel 등)는 `[weak self]` 필수
- iOS 키보드 익스텐션 marked text 미지원 → `updateComposingText`가 delete+insert로 시뮬레이션. 커서 이동 전 `commitCurrent()` 필수
- 일부 호스트(SwiftUI `TextField` 등)는 커서 탭 시 `selectionDidChange`를 발화하지 않음 → `handleExternalCursorMove`만으로는 부족. 입력 시점 백스톱 `freezeComposerIfCaretMoved()`가 `inputConsonant`/`inputVowel`/`deleteBackward` 진입 시 `textBeforeCursor()`가 조합 글자로 끝나지 않으면 조합을 리셋 (필드 맨 앞 = before nil 포함). 단 before/after 컨텍스트가 둘 다 nil인 호스트(시큐어 필드, 컨텍스트 미구현 테스트 스텁)는 no-op — 이 백스톱을 우회하는 변경 시 v1.7.2 커서 탭 중복 삽입 버그 회귀 주의 (`KeyboardViewModelCaretMoveTests`)

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
`[🌐] [123/한글] [한/영] [space (drag→커서)] [긋기 펑크] [⏎]`
- 지구본(🌐): **iOS 26 아이폰에서는 시스템이 키보드 아래에 지구본 바를 직접 그려 `needsInputModeSwitchKey == false` → 우리 지구본 미표시**(중복 방지, 시뮬레이터 실측). 구버전 iOS/아이패드 등 `true` 인 환경에서만 나타남
- `showGlobeKey && viewModel.canSwitchInputMode` 일 때만 렌더 → `KeyboardViewModel.switchKeyboard()` → `advanceToNextInputMode()`. `needsInputModeSwitchKey`는 익스텐션만 읽을 수 있어 `KeyboardViewController`가 `viewDidLoad` + **`viewWillAppear` 매회** `viewModel.canSwitchInputMode`에 밀어넣는다(세션 중 키보드 추가 반영, 호스트 앱 미리보기 기본 true). 1회만 캡처하면 익스텐션 프로세스가 살아있는 동안 갱신 안 됨
- 기능행 4개 바디(default/longSpace/symbol/bimanual) 모두 자식 폭 합 == `effectiveTotalWidth` 여야 ⏎ 가 안 잘림. 자식 추가 시 간격 수도 함께 증가 — 지구본은 `globeReservedWidth`(폭+간격)를 **스페이스바에서만** 차감. 불변식은 `FunctionRowWidthTests` 가드
- 긋기 펑크: tap=`.`, ←=`?`, →=`!`, ↑=`,`, ↓=`.`
- Space 드래그: 8pt 임계값, 12pt/step → `moveCursor(by:)` (commitCurrent + abbreviation reset 후 proxy 커서 이동)
- Space 드래그 auto-repeat: 손가락이 바 폭의 **양끝 15%**(`edgeZoneFraction`, `value.location.x` 기준 — 절대 pt 아님, 작은 폰 대응) 구역에 들어가면 `SpaceCursorRepeater`(Timer, `[weak self]`+`RunLoop.common`) 가 그 방향으로 연속 이동. 가속 램프는 `KeyboardSettings.cursorRepeatSpeed`(0/1/2)→`cursorRepeatInterval`. 커서 상하(↑↓) 이동은 iOS 익스텐션 API 부재로 미지원(`adjustTextPosition(byCharacterOffset:)` = 가로 전용)
- 심볼 모드 전용 행: `[한글/ABC] [한/영] [#+= / 123] [space] [⏎]` — 페이지 토글이 **스페이스 왼쪽**(구 슬롯 B 위치), 긋기 펑크 대신 렌더

### 모음 키 동작 (`LayoutCustomization.vowelKeyBehavior`, v2.1.1 build 20 / 이슈 #25)
모음 키(`SlotBVowelKey`, 라벨 `ㅣㆍㅡ / 모음`)는 **두 곳**에 뜬다 — 스페이스 옆
슬롯 B(`slotB == .vowelKey`)와 확장형(`fullPackage`) 그리드 col 6 row 1 임베드.
확장형은 `slotB` 값과 무관하게 임베드하므로 동작 설정을 `SlotBPreset` 케이스로
넣으면 확장형에서 도달하지 못한다 — **반드시 별도 필드로 둘 것**.
- `.gestureMulti` (기본, 기존 동작) — tap=ㆍ + `GestureAnalyzer`/`VowelResolver`
  전체 파이프라인(8방향·멀티스트로크). **기본값을 바꾸지 말 것** — 업데이트만으로
  기존 사용자의 모음 키가 다른 자판이 된다 (`LayoutCustomizationTests` 가드)
- `.cheonjiin` (순정/삼성 모아키) — 분석기를 **아예 태우지 않고** 손 뗀 지점의
  **가로 순변위**만 본다: ← = ㅣ, → = ㅡ, 그 외(탭·↑·↓·임계 미만) = ㆍ.
  임계는 `swipeProfile.swipeLength.threshold(keyWidth:)` 재사용(기기 폭 비례).
  순정은 키 위에 `ㅣ · ㅡ` 3칸 팝업을 띄우고 손가락이 놓인 칸을 고르게 하는
  **선택기**라, 지나간 경로가 아니라 최종 위치가 결과다 — 획 시퀀스로 바꾸면
  "헤매다 가운데로 돌아오면 ㆍ" 가 깨진다 (`KeyboardViewModelCheonjiinVowelKeyTests`)
- 미리보기는 새 컴포넌트 없이 기존 `GestureOverlayView` 경로 재사용. 오버레이는
  `directions` 가 비면 그리지 않으므로 좌/우 확정 구간에서만 `[.left]`/`[.right]`
  한 획을 넣는다. 가운데(ㆍ)는 탭과 같은 상태 = 미리보기 없음
- 부수 효과: 순정 방식은 대각선을 안 쓰므로 `fourWayMode`(4방향 전용)와 공존한다.
  8방향 동작에서 클래식/확장형의 ㅣ/ㅡ 가 ↗/↘ 로만 들어와 막히던 제약이 사라진다

### 심볼 키패드 페이지 (2페이지)
- `KeyboardMetrics.symbolLayout(_:page:)` — page 0 = 숫자 + 상용 문장부호(왼쪽 열 `. , ' "`), page 1 = 괄호/통화/수학/타이포 기호. `symbolPageCount = 2`
- 상태: `KeyboardViewModel.symbolPage`(Int). `toggleSymbolPage()`가 `% symbolPageCount` 순환. 심볼 진입/이탈(`toggleSymbolMode`/`toggleLetterMode`) 시 항상 0 리셋
- 페이지 인지 리졸버: `activeLayout(for:layout:symbolPage:)` / `keyContent(...symbolPage:)` — 렌더(`KeyGridView.symbolPage`) + 탭(`handleSymbolModeTap`) + 롱프레스 모두 활성 페이지로 해석. 기존 2-arg 오버로드는 page 0 위임(하위호환)
- geometry(⌫ 위치/열 수)는 페이지 간 동일, 콘텐츠만 변경. classic11/fullPackage는 wide-⌫로 2셀 적어 `/`를 page 1에 배치(`°`·backtick 생략) — `/` 누락은 회귀이므로 `KeyboardMetricsLayoutTests.testSymbolPages_essentialCharsReachableForEveryPreset` 가드

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
ㅑ + ㆍ = ㅏ        ㅕ + ㆍ = ㅓ        ㅛ + ㆍ = ㅗ        ㅠ + ㆍ = ㅜ
ㅐ + ㆍ = ㅒ        ㅒ + ㆍ = ㅐ        ㅔ + ㆍ = ㅖ        ㅖ + ㆍ = ㅔ
  ↑ base↔y **6쌍 전부 무한 토글**. 반드시 쌍으로 유지할 것 — 반쪽만 있으면
  `combineVowels` 가 nil 을 돌려 ㆍ 연타가 조용히 끊기고 커밋된다("ㅑㆍ" 증상,
  실기기 제보 2026-08-18). 근거: ㅗ↔ㅛ·ㅜ↔ㅠ 영상 H2 / ㅐ↔ㅒ·ㅔ↔ㅖ adb 실측
  2026-08-14 / ㅏ↔ㅑ·ㅓ↔ㅕ 실기기 제보. 가드 `test_dotToggle_everyBaseYPairRoundTrips`
ㅗ + ㅏ = ㅘ        ㅗ + ㅐ = ㅙ        ㅗ + ㅣ = ㅚ
ㅜ + ㅓ = ㅝ        ㅜ + ㅔ = ㅞ        ㅜ + ㅣ = ㅟ
ㅚ + ㆍ = ㅘ        ㅟ + ㆍ = ㅝ        (순정 adb 실측 — ㅢ+ㆍ는 순정이 옛한글 ㅡㅏ를 만들어 재현 안 함)
ㅡ + ㅣ = ㅢ        ㅘ + ㅣ = ㅙ        ㅝ + ㅣ = ㅞ
```

**dotPending (3-stroke ㆍ 시작):**
- ㆍ + ㆍ = pending(2)
- ㆍ + ㆍ + ㅣ = ㅕ
- ㆍ + ㆍ + ㅡ = ㅛ
- ㅇ + ㆍ + ㆍ + ㅣ = 여 (자음 + dotPending 누적 → 합성)

### 백스페이스 동작 (순정 실측 v1.8.x — 자소 단위, 영상 G5)
- `.choseongJungseong` (받침 없음) → `.choseong` (중성만 삭제, 초성 남김. "가"→"ㄱ")
  - 중성은 천지인 획 되감기 없이 **통째** 삭제 ("개"→"ㄱ", ㅐ→ㅏ 아님)
- `.complete` (받침 있음) → 받침만 제거 (한→하). 겹받침은 뒤쪽부터 (값→갑)
- `.dotPending` → ㆍ 카운트 1단계 감소
- `.standaloneVowel` → empty (남길 초성이 없으므로)

### 설정 시스템
```
KeyboardSettings (싱글톤, App Group UserDefaults, ObservableObject)
├── gestureSettings: GestureSettings        (프로필 + 열별 보정)
├── themeSettings: ThemeSettings            (테마/투명도/햅틱)
│   └── resolvedKeyBackground/KeyText/FunctionKeyBackground (커스텀 vs 프리셋)
├── secondaryKeyActions: [SecondaryKeyAction]  (한글 자음 19키 + 영문 숫자 10키)
├── shortcutExpansionStore: ShortcutExpansionStore
├── abbreviationEnabled: Bool               (약어 확장 마스터 토글)
├── abbreviationUndoOnBackspaceEnabled: Bool (확장 직후 백스페이스 되돌리기, 기본 ON)
├── abbreviationKeepConfirmSpaceEnabled: Bool (확정 스페이스를 결과 뒤에 남길지, 기본 ON
│                                             — 기호·엔터는 설정 무관 항상 유지)
├── abbreviationTriggerPolicy: .safe/.free  (신규 트리거 등록 제한 — 메인 앱 검증 전용)
├── periodOnDoubleSpaceEnabled: Bool        (더블 스페이스 → 마침표)
├── layoutCustomization: LayoutCustomization (프리셋/슬롯/펑크 구성 + vowelKeyBehavior)
├── rememberLastKeyboardMode: Bool + lastKeyboardLetterMode: String (한/영 모드 복원)
├── clickSoundEnabled: Bool                 (독립 저장)
├── longPressDelay: Double                  (0.2~1.0초)
├── sideKeyWidthRatio: Double               (0.15~1.0, 기본 0.7 정사각)
├── keyboardHeightScale: Double             (0.85~1.35, 기본 1.0 — 기기 기본 높이에 곱함)
├── showGlobeKey: Bool                      (기능행 지구본 키, 기본 OFF)
├── consonantDiagonalDerivationEnabled: Bool (자음 대각선 진입 파생, 기본 OFF=순정 모아키)
├── cursorMoveBySpaceDragEnabled: Bool      (Space 드래그 커서 이동, 기본 ON)
├── cursorRepeatSpeed: Int                  (Space 드래그 양끝 연속 이동 속도, 0/1/2 기본 1)
├── autoBracketEnabled: Bool
├── wordDeleteEnabled: Bool
├── wordDeleteDelay: Double
├── backspaceSpeed: Int                     (0=느림, 1=보통, 2=빠름)
├── showGesturePreview: Bool
├── showSecondaryHints: Bool
├── showDetailedHints: Bool
└── hintSize: Int                           (0=작게, 1=보통, 2=크게)
```

### 순정 모아키 입력 스펙 (기준 — 2026-08 영상 실측으로 확정)
출처: `docs/moakey_ios_custom_docs/assets/03_gesture_angle_reference.png` + **관찰 영상 40편 판독**.
판독 전문(`docs/MOAKEY_VIDEO_FINDINGS.md`)과 작업 핸드오프(`docs/HANDOFF.md`)는 **로컬 보관
문서로 저장소에 추적되지 않는다** — 클론한 머신에는 없을 수 있다. 아래 요약이 실질적 기준이다.
- 자음 8방향 단독: `↑=ㅗ ↓=ㅜ →=ㅏ ←=ㅓ`, `↖↗=ㅣ`, `↙↘=ㅡ` (17회 예외 없음)
- 복합모음 **방향 조합**: `ㅘ=↑→` `ㅝ=↓←` `ㅚ=↑↓` `ㅟ=↓↑` `ㅐ=→←` `ㅔ=←→` `ㅛ=↑↓↑` `ㅠ=↓↑↓` `ㅑ=→←→` `ㅕ=←→←` `ㅙ=↑→←` `ㅞ=↓←→` + **자음 키에서도 `ㅒ=→←→←` `ㅖ=←→←→` 성립** + **세로 체인 `ㅘ=↑↓→` `ㅙ=↑↓→←` `ㅠ=↑↓↑↓`** (팝업 체인 고→괴→과→괘 실측)
- **첫 획 재해석 (v1.8.x 도입)**: 순정은 첫 대각선 획을 8방향 잠정 분류 후 **후속 획이 오면 실제 각도의 4방향으로 재해석**한다 — ↗ 왕복=ㅐ(리뷰 "ㅐ 방향 다름"의 원인이었음), ↖↘=ㅔ, ↙↑↓=ㅠ. 단 ↙↗/↘↖ 반전은 천지인 ㅡ+ㅣ=ㅢ 우선. 구현: `finalizeGestureDetailed()`의 firstStrokeCardinal + `VowelResolver` 2-pass(간선 수 비교, 동률=기존 해석). `MoakeyVideoVerifiedSpecTests` 가드 — **변경 시 순정 이탈 주의**
- 판정 모델(실측): 단일 획 방향 = net 변위 벡터(꼬리 레버리지 없음), 최소 획 길이 문턱(키폭의 ~0.3~0.45), turn ≥60° 분리 / ≤55° 흡수, 속도 무관(뗄 때까지 획 누적·즉시 재판정), 트라이 밖 획은 유효 최장 접두사로 무시
- **adb 정밀 측정 (2026-08-14, 갤럭시 S22+ 터치 주입)**: 되돌림 등록 하한 = **42px = 키 너비 150px의 28%** (41px 미등록/42px 등록, 진입 150/300px 무관 = 절대 임계 → `reversalThresholdRatio` 0.70), ㅓ/ㅣ 경계 = 22°/23° 사이(22.5° 정합), 첫 획 4방향 재해석 = 45° 옥탄트 정합(55~65° 정밀 입력은 수직 — S3 영상의 60°=수평은 수기 오차), ↘↖ 반전 = ㅢ 우선(50~65° 전부), ㅐ↔ㅒ·ㅔ↔ㅖ ㆍ토글 확증
- `resolveConsonantDiagonalVowel`(대각선 진입 후 천지인 파생)은 v1.7에 추가한 확장. **반전 획(↙↗=ㅢ)만 순정에도 존재**(트라이가 이미 처리) — 나머지 대각선+카디널 파생은 순정 미확인 + v1.7 오타 원인(리뷰 3건)이라 `consonantDiagonalDerivationEnabled` **기본 OFF 유지**
- 단독 대각선(↗=ㅣ ↘=ㅡ)은 트라이가 처리하므로 이 설정과 무관 — 클래식/확장형의 유일한 ㅣ/ㅡ 경로라 절대 깨면 안 됨

### 긋기 노이즈 처리 (GestureAnalyzer)
- `directionMagnitudes`는 획이 이어지는 동안 **실제 길이로 갱신**된다(`strokeOriginPoint` 기준). 등록 시점 변위만 담으면 모든 비율 판정이 임계값을 "직전 획 길이"로 착각한다
- 후행 노이즈 트림은 **절대 크기(`edgeNoiseCap`) + 직전 획 대비 비율(`trailingNoiseRatio` 0.4)** 를 함께 보고, 꼬리가 여러 조각일 수 있어 반복 제거. 절대 크기만 쓰면 ㅒ/ㅖ/ㅙ/ㅞ의 짧은 마지막 획이 잘려 얘→야, 왜→와 회귀 발생 (`GestureOverDetectionCharacterizationTests` 가드)

### 대각선 모음 매핑 (기본값)
```
↖ ↗ = ㅣ,  ↙ ↘ = ㅡ  (설정에서 변경 가능)
```
모음 제스처 전체 표: [README.md](README.md) 참조

### 약어(단축어) 트리거 매칭 규칙
- 구분자는 두 종류다. **경계 구분자**(`" "` `"\n"`)는 버퍼를 리셋하고, **내용 겸 확정
  구분자**(`.` `,` `!` `?` `;` `:`)는 버퍼에 누적되면서 확정 판정도 트리거한다. 덕분에
  `.ㅎㅌ` `ㅏ..` 같은 기호 트리거가 성립한다
- **트리거에 공백은 넣을 수 없다** — 스페이스가 확정 신호를 겸하면 짧은 트리거가 긴 트리거를
  가로채고(`ㅋ` vs `ㅋ ㅋ`) 삭제 개수 규칙이 갈라진다. 등록 UI에서 차단
- 매칭은 ①버퍼 전체 정확 매칭 → 실패 시 ②**최장 접미** 매칭 순. 접미 매칭은 **내용 구분자를
  포함한 트리거로 한정**한다. 이 제한을 풀면 평범한 `ㅎㅌ` 가 "안녕ㅎㅌ" 끝에서도 터져
  기존 사용자가 전부 깨진다 (`testExpansion_plainTrigger_doesNotFireMidWord` 가드)
- 지울 길이는 **매칭된 트리거** 기준이다. 버퍼 길이로 지우면 접미 매칭에서 앞 글자를 먹는다
- 확장 직전 `textBeforeCursor()` 가 트리거로 끝나는지 확인하고, 아니면 **확장을 포기**한다.
  델리게이트가 `Bool` 을 반환해 엔진이 되돌리기 상태를 세우지 않도록 한다 — 포기했는데
  엔진만 "확장함" 으로 남으면 사용자가 누른 구분자가 삼켜진다
- 확정 구분자를 결과 뒤에 남길지는 `abbreviationKeepConfirmSpaceEnabled` 가 정하는데
  **스페이스에만 적용**한다. 기호는 사용자가 의도한 문장부호, 엔터는 줄바꿈/전송이라 빼면
  입력을 삼키는 셈이다. 이 설정을 끄면 되돌리기 삭제 길이도 `replacement.count` 로 줄어야
  한다 — 안 넣은 구분자를 넣은 것으로 계산하면 앞 글자를 한 자 더 먹는다
  (`testBackspace_afterExpansionWithoutConfirmSpace_restoresTrigger` 가드)
- 등록 제한(`abbreviationTriggerPolicy`)은 **메인 앱 UI 전용**이다. 엔진에 길이 필터를 넣으면
  이미 등록된 1글자 단축어가 죽는다(소급 적용 없음)

### 커서 이동 / 약어 리셋 패턴
```swift
func moveCursor(by offset: Int) {
    guard offset != 0 else { return }
    commitCurrent()                     // 미확정 글자 freeze
    abbreviationEngine.resetBuffer()    // stale trie state 제거
    delegate?.moveCursor(by: offset)    // proxy.adjustTextPosition
}
```

### 신규 입력 추가 시 체크리스트
1. `HangulComposer.State` 또는 `KeyContent` 새 케이스 추가했나? → 모든 `switch` exhaustive 점검
2. `KeyboardSettings`에 새 옵션 추가했나? → `isLoading` 가드 + `loadAll()` 로드 라인 + 디스크 저장 키 모두 추가.
   **`loadAll()` 에서는 직접 대입하지 말고 `assign(\.foo, ...)` 헬퍼를 쓸 것** — 값이 같은데도
   재대입하면 `@Published` 가 발행돼 무관한 설정 하나에 키보드 트리 전체가 재구성된다
3. `Jungseong` 새 멤버 추가했나? → `Jungseong.allCases` 영향, `HangulConstants.composeSyllable` 가드 확인
4. 메인 앱(GestureTestView 등)에서 익스텐션 코드 사용? → `scripts/add_target_membership.rb`로 타겟 멤버십 추가
5. SwiftUI View가 무거운 클래스 인스턴스 보관? → `ObservableObject` wrapper + `@StateObject` 패턴 권장

## Bundle ID

| 타겟 | Bundle ID |
|------|-----------|
| 메인 앱 | `kr.koh0001.moa-plus` |
| 키보드 | `kr.koh0001.moa-plus.keyboard` |
| App Group | `group.com.moaki.keyboard` (변경 금지) |

## GBrain Configuration (configured by /setup-gbrain)
- Engine: pglite
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-05-08
- MCP registered: yes (user scope)
- Memory sync: full
- Current repo policy: read-write

## GBrain Search Guidance (configured by /sync-gbrain)
<!-- gstack-gbrain-search-guidance:start -->

GBrain is set up and synced on this machine. The agent should prefer gbrain
over Grep when the question is semantic or when you don't know the exact
identifier yet. Two indexed corpora available via the `gbrain` CLI:
- This repo's code (registered as `gstack-code-<repo>` source).
- `~/.gstack/` curated memory (registered as `gstack-brain-<user>` source via
  the existing federation pipeline).

Prefer gbrain when:
- "Where is X handled?" / semantic intent, no exact string yet:
    `gbrain search "<terms>"` or `gbrain query "<question>"`
- "Where is symbol Y defined?" / symbol-based code questions:
    `gbrain code-def <symbol>` or `gbrain code-refs <symbol>`
- "What calls Y?" / "What does Y depend on?":
    `gbrain code-callers <symbol>` / `gbrain code-callees <symbol>`
- "What did we decide last time?" / past plans, retros, learnings:
    `gbrain search "<terms>" --source gstack-brain-<user>`

Grep is still right for known exact strings, regex, multiline patterns, and
file globs. The brain auto-syncs incrementally on every gstack skill start.
Run `/sync-gbrain` to force-refresh, `/sync-gbrain --full` for full reindex.



## Vault 자동 캡처

Vault 경로: `/Users/koh/vault` (additionalDirectories 등록 필요)

### 기록 조건
다음이 발생하면 즉시 `vault/inbox/`에 노트를 남길 것:
- 기술 선택이 확정됐을 때 (A 대신 B를 쓰기로 함 + 이유)
- 30분 이상 막힌 문제가 해결됐을 때 (증상 → 원인 → 해법)
- 환경/인프라 사실이 새로 확인됐을 때 (포트, 경로, 제약)
- 다른 프로젝트에도 적용될 패턴을 발견했을 때

### 기록 방식
- 파일명: `inbox/YYYY-MM-DD-주제.md`
- frontmatter에 `source: auto`, `status: draft` 필수
- 20줄 이내. 결정/원인/해법만. 과정 서술 금지
- 작성 후 `→ vault 기록: <파일명>` 한 줄만 알리고 작업 계속

### 금지
- `inbox/` 외의 폴더에 직접 쓰지 말 것
- 세션당 최대 3개. 초과 시 기존 노트에 병합
- 확신이 없거나 아직 검증 안 된 것은 기록하지 말 것
<!-- gstack-gbrain-search-guidance:end -->

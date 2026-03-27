# 모아키 (Moaki) - iOS 한글 키보드

제스처 기반 한글 입력 iOS 커스텀 키보드 앱.
갤럭시 원본 양손 모아키 사용감을 iOS에서 복원하고, 약어 확장/특수문자 레이어/테마 등 생산성 기능을 확장한다.

## 프로젝트 구조

```
ios-moaki-custom/
├── ios-moaki/                          # 메인 앱 (설정 + 튜토리얼)
│   ├── ios_moakiApp.swift              # @main 진입점
│   ├── ContentView.swift               # 설정 안내 + 튜토리얼 + 설정 진입
│   ├── Settings/                       # 설정 앱 (6개 카테고리)
│   │   ├── SettingsMainView.swift      # 설정 메인 네비게이션
│   │   ├── InputSettingsView.swift     # 긋기 각도/길이/열별 보정
│   │   ├── SecondaryInputSettingsView.swift  # 보조 힌트/롱프레스 편집
│   │   ├── SpecialCharSettingsView.swift     # 특수문자 레이어 설정
│   │   ├── AbbreviationSettingsView.swift    # 단축어 관리 (CRUD)
│   │   ├── AppearanceSettingsView.swift      # 테마/배경/투명도
│   │   └── FeedbackSettingsView.swift        # 햅틱/사운드
│   └── Tutorial/                       # 튜토리얼 시스템
│
├── MoakiKeyboard/                      # 키보드 익스텐션
│   ├── KeyboardViewController.swift    # UIKit 진입점 (260pt 고정 높이)
│   ├── Engine/                         # 입력 엔진
│   │   ├── HangulComposer.swift        # 한글 조합 상태머신
│   │   ├── GestureAnalyzer.swift       # 제스처 방향 분석 (설정 연동)
│   │   ├── VowelResolver.swift         # 방향→모음 변환 (PatternTrie)
│   │   └── AbbreviationEngine.swift    # Trie 기반 약어 확장 엔진
│   ├── Models/                         # 데이터 모델
│   │   ├── HangulJamo.swift            # 초/중/종성 enum
│   │   ├── GestureDirection.swift      # 8방향 enum
│   │   ├── VowelPattern.swift          # 21개 모음 패턴 + PatternTrie
│   │   ├── SwipeProfile.swift          # 긋기 각도 프리셋 (양손/오른손/왼손/직접)
│   │   ├── ColumnGestureOverride.swift # 1~5열별 제스처 보정
│   │   ├── SecondaryKeyAction.swift    # 키별 롱프레스 매핑 (19키)
│   │   ├── ShortcutExpansion.swift     # 약어 확장 데이터 + Store
│   │   └── ThemeSettings.swift         # 테마/외형/햅틱 설정 + 5색상 테마
│   ├── ViewModels/                     # 뷰모델
│   │   └── KeyboardViewModel.swift     # 입력 흐름 총괄 (KeyboardView에서 분리)
│   ├── Views/                          # SwiftUI 뷰
│   │   ├── KeyboardView.swift          # 메인 키보드 (레이어 전환 + 후보 바)
│   │   ├── ConsonantGridView.swift     # 자음 그리드 (보조 힌트 전달)
│   │   ├── ConsonantKeyView.swift      # 개별 키 (테마 색상 + 힌트 라벨)
│   │   ├── FunctionRowView.swift       # 하단 기능키 (기본/양손 모아키 레이아웃)
│   │   ├── GestureOverlayView.swift    # 제스처 방향 시각화
│   │   ├── SpecialCharacterLayerView.swift  # 특수문자 레이어 (4 카테고리)
│   │   └── AbbreviationCandidateView.swift  # 약어 후보 바
│   ├── Utilities/                      # 유틸리티
│   │   ├── HangulConstants.swift       # 유니코드 조합 공식
│   │   ├── KeyboardMetrics.swift       # 키 배치/그리드 + 양손 모아키 레이아웃
│   │   ├── KeyboardSettings.swift      # App Group 기반 통합 설정 (싱글톤)
│   │   ├── GestureSettings.swift       # 제스처 통합 설정 (프로필+열별 보정)
│   │   ├── HapticManager.swift         # 이벤트별 햅틱 관리
│   │   └── BackgroundImageManager.swift # 배경 이미지 관리
│   └── Info.plist                      # 키보드 서비스 설정
│
├── MoakiKeyboardTests/                 # 유닛 테스트 (57+ 케이스)
│   ├── HangulComposerTests.swift
│   ├── GestureAnalyzerTests.swift
│   ├── VowelResolverTests.swift
│   └── KeyboardViewModelLongPressTests.swift
│
└── docs/moakey_ios_custom_docs/        # 기획/설계 문서
    ├── 09_개발계획_통합문서.md           # 메인 개발 기준 문서
    └── 10_빌드_및_설치_가이드.md         # Xcode + iPhone 설정 가이드
```

## 핵심 아키텍처

### 전체 데이터 흐름

```
┌────────────────────────────────────────────────────────────────┐
│ ios-moaki (메인 앱)                                             │
│   ContentView → 튜토리얼 / 설정(SettingsMainView)               │
│        ↕ App Group (group.com.moaki.keyboard)                  │
├────────────────────────────────────────────────────────────────┤
│ MoakiKeyboard (키보드 익스텐션)                                  │
│                                                                │
│   KeyboardViewController (UIKit)                               │
│        │                                                       │
│        ▼                                                       │
│   KeyboardView (SwiftUI) ◄── SpecialCharacterLayerView         │
│        │                  ◄── AbbreviationCandidateView         │
│        ▼                                                       │
│   KeyboardViewModel ◄── KeyboardSettings (App Group 공유)       │
│        │    │    │                                              │
│        ▼    ▼    ▼                                              │
│   Hangul  Gesture  Abbreviation                                │
│   Composer Analyzer  Engine                                    │
│        │    │    │                                              │
│        ▼    ▼    ▼                                              │
│   ComposerAction → HapticManager → 텍스트 출력                  │
└────────────────────────────────────────────────────────────────┘
```

### HangulComposer 상태

- `empty`: 입력 없음
- `choseong(초성)`: 자음만 입력됨
- `choseongJungseong(초성, 중성)`: 자음+모음
- `complete(초성, 중성, 종성)`: 완성된 글자

### ComposerAction

- `.none`: 변화 없음
- `.update`: 조합 중인 글자 갱신 (markedText 업데이트)
- `.commit`: 글자 확정 (composedText → insertText)
- `.delete`: 삭제 동작
- `.commitAndUpdate`: 이전 글자 확정 + 새 조합 시작
- `.commitAndCommit`: 이전 글자 + 현재 글자 모두 확정

**중요**: `.commit*` 액션 발생 시 `composer.flushCommittedText()`로 확정된 텍스트를 가져와 `delegate?.insertText()`로 출력해야 함

### 제스처 엔진 설정 흐름

```
KeyboardSettings.shared.gestureSettings (App Group 공유)
    ├── swipeProfile (양손/오른손/왼손/직접설정 프리셋)
    │       └── swipeLength (짧게/보통/길게 → pt threshold)
    └── columnOverrides[1..5] (열별 보정값)
            ├── rotationOffsetDeg (각도 회전)
            ├── verticalIWidthDelta (ㅣ 인식 폭)
            ├── horizontalEuWidthDelta (ㅡ 인식 폭)
            └── outwardDistanceMultiplier (바깥쪽 거리)

GestureAnalyzer.gestureStarted() 에서:
    1. settings = KeyboardSettings.shared.gestureSettings  (매 제스처마다 최신 설정 로드)
    2. columnId = KeyboardMetrics.columnIndex(for: consonant)  (열별 보정 적용)
```

### 약어 확장 흐름

```
문자 입력 → AbbreviationEngine.processCharacter/processComposedText
    → 버퍼 축적 → delimiter 입력 시 Trie 검색
    → 매칭 시: onDelimiter → 자동 치환 / suggestion → 후보 바 표시
    → 치환 직후 backspace 1회 → 원문 복원
```

### 설정 공유 구조

```
KeyboardSettings (싱글톤)
    ├── gestureSettings: GestureSettings      (제스처 전체)
    ├── themeSettings: ThemeSettings           (테마/햅틱)
    ├── secondaryKeyActions: [SecondaryKeyAction]  (롱프레스 매핑)
    ├── shortcutExpansionStore: ShortcutExpansionStore  (약어)
    ├── showGesturePreview: Bool
    ├── showSecondaryHints: Bool
    └── hintSize: Int (0=작게, 1=보통, 2=크게)

저장: App Group UserDefaults (group.com.moaki.keyboard)
직렬화: Codable JSON 인코딩
로딩: init()에서 loadAll() (isLoading 플래그로 didSet 재저장 방지)
```

## 모음 제스처 규칙

자음 키 위에서 드래그하여 모음 입력:

### 대각선 정규화
왼쪽 대각선만 수직 방향으로 정규화됨:
- ↖ → ↑ (ㅗ)
- ↙ → ↓ (ㅜ)

오른쪽 대각선은 별도 모음:
- ↗ → ㅣ
- ↘ → ㅡ

### 기본 모음

| 방향 | 모음 |
|------|------|
| → | ㅏ |
| ← | ㅓ |
| ↑ (또는 ↖) | ㅗ |
| ↓ (또는 ↙) | ㅜ |
| ↘ | ㅡ |
| ↗ | ㅣ |

### Y-모음 (왕복 제스처)

| 방향 | 모음 |
|------|------|
| ↑↓↑ | ㅛ |
| ↓↑↓ | ㅠ |
| →←→ | ㅑ |
| ←→← | ㅕ |

### 복합 모음

| 방향 | 모음 |
|------|------|
| ↑→ | ㅘ |
| ↑→← | ㅙ |
| ↓← | ㅝ |
| ↓→← | ㅞ |
| ↑↓ | ㅚ |
| ↓↑ | ㅟ |
| →← | ㅐ |
| →←→← | ㅒ |
| ←→ | ㅔ |
| ←→←→ | ㅖ |
| ↘↖ 또는 ↘↑ | ㅢ |

## KeyContent 키 타입

```swift
enum KeyContent {
    case consonant(Choseong)              // 자음 키
    case symbol(String)                   // 기호 키
    case backspace                        // 삭제 키
    case vowelPrimitive(VowelPrimitiveType) // 모음 프리미티브 (ㆍ/ㅣ/ㅡ)
    case functional(FunctionalKeyType)    // 기능 키 (모드전환/스페이스/엔터 등)
    case systemSwitch                     // 시스템 키보드 전환 (🌐)
    case quickPunctuation(String)         // 빠른 문장부호
}
```

## 빌드 및 테스트

```bash
# 빌드
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 16'

# 테스트
xcodebuild test -scheme MoakiKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 16'

# 전체 앱 빌드
xcodebuild -scheme ios-moaki -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 키보드 테스트 방법

1. 시뮬레이터에서 앱 실행
2. 설정 → 일반 → 키보드 → 키보드 → 새 키보드 추가 → MoakiKeyboard
3. 메모 앱에서 키보드 전환 (🌐 버튼)

실기기 설치 시 `docs/moakey_ios_custom_docs/10_빌드_및_설치_가이드.md` 참조.

## 주의사항

- iOS 키보드 익스텐션은 제한된 메모리에서 동작 (~30MB)
- `KeyboardViewController`는 UIKit, 나머지는 SwiftUI
- 테마 색상은 `KeyboardSettings.shared.themeSettings.buttonTheme` 에서 가져옴
- `insertText()` 호출 전 `flushCommittedText()`로 확정 텍스트 획득 필수
- 설정 공유는 App Group (`group.com.moaki.keyboard`) 필요 — Xcode에서 양쪽 타겟에 설정
- `HapticManager`는 매번 `KeyboardSettings.shared.themeSettings`를 직접 읽음 (캐시 없음)
- `KeyboardSettings.loadAll()`은 `isLoading` 플래그로 didSet 재저장을 방지

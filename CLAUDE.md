# 모아+ (Moa+) - iOS 제스처 한글 키보드

제스처 기반 한글 입력 iOS 커스텀 키보드 앱.
모아키 방식 입력을 iOS에서 구현하고, 약어 확장/테마/롱프레스 보조입력 등 생산성 기능을 확장한다.

> 원본: [ios-moaki](https://github.com/vkehfdl1/ios-moaki) by Jeffrey (Dongkyu) Kim (MIT License)

## 프로젝트 구조

```
moa-plus/
├── MoaPlus/                           # 메인 앱 (홈 + 설정 + 튜토리얼)
│   ├── MoaPlusApp.swift               # @main 진입점
│   ├── ContentView.swift              # 홈 화면 (딥블루 그라디언트)
│   ├── Settings/                      # 설정 (5개 카테고리 + 앱 정보)
│   │   ├── SettingsMainView.swift
│   │   ├── InputSettingsView.swift    # 긋기 각도/길이/방향 매핑/열별 보정/사이드키 크기
│   │   ├── SecondaryInputSettingsView.swift  # 롱프레스 매핑 편집/힌트/딜레이
│   │   ├── AbbreviationSettingsView.swift    # 단축어 CRUD
│   │   ├── AppearanceSettingsView.swift      # 테마/커스텀 색상/배경 이미지/키 투명도
│   │   ├── FeedbackSettingsView.swift        # 햅틱/사운드/백스페이스 속도/단어 삭제
│   │   └── AboutView.swift                   # 크레딧/라이선스/링크
│   └── Tutorial/                      # 8단계 튜토리얼 (딥블루 테마)
│
├── MoaPlusKeyboard/                   # 키보드 익스텐션
│   ├── KeyboardViewController.swift   # UIKit 진입점 (260pt 고정 높이)
│   ├── Engine/
│   │   ├── HangulComposer.swift       # 한글 조합 상태머신
│   │   ├── GestureAnalyzer.swift      # 제스처 방향 분석 (설정 연동, 열별 보정)
│   │   ├── VowelResolver.swift        # 방향→모음 변환 (커스텀 대각선 매핑)
│   │   └── AbbreviationEngine.swift   # Trie 기반 약어 확장 + backspace 복원
│   ├── Models/
│   │   ├── HangulJamo.swift           # 초/중/종성 enum (한글 멤버명: .ㄱ .ㅏ 등)
│   │   ├── GestureDirection.swift     # 8방향 enum
│   │   ├── VowelPattern.swift         # 21개 모음 패턴 + PatternTrie
│   │   ├── SwipeProfile.swift         # 긋기 프리셋 + DirectionSector + DiagonalMapping
│   │   ├── ColumnGestureOverride.swift
│   │   ├── SecondaryKeyAction.swift   # 키별 롱프레스 매핑 (19키)
│   │   ├── ShortcutExpansion.swift    # 약어 데이터 + Store
│   │   └── ThemeSettings.swift        # 테마/CodableColor/ButtonTheme + resolved 색상
│   ├── ViewModels/
│   │   └── KeyboardViewModel.swift    # 입력 흐름 총괄
│   ├── Views/
│   │   ├── KeyboardView.swift         # 메인 키보드 + 롱프레스 팝업 오버레이
│   │   ├── ConsonantGridView.swift    # 자음 그리드
│   │   ├── ConsonantKeyView.swift     # 개별 키 (테마/힌트/사이드키 구분)
│   │   ├── FunctionRowView.swift      # 하단 기능키
│   │   ├── GestureOverlayView.swift   # 제스처 시각화
│   │   └── AbbreviationCandidateView.swift  # 약어 후보 바 (복수 후보)
│   └── Utilities/
│       ├── HangulConstants.swift
│       ├── KeyboardMetrics.swift      # 키 배치 + symbolWidthRatio(설정 연동)
│       ├── KeyboardSettings.swift     # App Group 싱글톤 (isLoading 가드)
│       ├── GestureSettings.swift
│       ├── HapticManager.swift        # 설정을 매번 직접 읽음 (캐시 없음)
│       └── BackgroundImageManager.swift
│
├── MoaPlusKeyboardTests/             # 유닛 테스트 (57+ 케이스)
└── docs/                             # 개발 문서
```

## 핵심 아키텍처

```
┌──────────────────────────────────────────────┐
│ MoaPlus (메인 앱)                              │
│   ContentView → 튜토리얼 / 설정                 │
│        ↕ App Group (group.com.moaki.keyboard) │
├──────────────────────────────────────────────┤
│ MoaPlusKeyboard (키보드 익스텐션)                │
│                                              │
│   KeyboardViewController (UIKit)             │
│        ↓                                     │
│   KeyboardView (SwiftUI)                     │
│        ↓                                     │
│   KeyboardViewModel                          │
│        ├── HangulComposer (조합 상태머신)      │
│        ├── GestureAnalyzer (방향 분석)         │
│        ├── VowelResolver (모음 매핑)           │
│        └── AbbreviationEngine (약어 확장)      │
│              ↓                               │
│   HapticManager → AudioToolbox → 출력         │
└──────────────────────────────────────────────┘
```

## 빌드 및 테스트

```bash
# Xcode에서 열기
open MoaPlus.xcodeproj

# 빌드 (시뮬레이터)
xcodebuild -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 16'

# 테스트
xcodebuild test -scheme MoaPlusKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

실기기: `Cmd + R` → 아이폰에서 설정 → 키보드 → 새 키보드 추가 → 모아+

## 주의사항

### 필수 규칙
- `insertText()` 호출 전 `flushCommittedText()`로 확정 텍스트 획득 필수
- `KeyboardSettings.loadAll()`은 `isLoading` 플래그로 didSet 재저장을 방지 — 새 설정 추가 시 반드시 가드 포함
- App Group ID는 `group.com.moaki.keyboard` — 변경하면 기존 사용자 설정 소실
- `Jungseong` enum 멤버명은 한글 (`Jungseong.ㅏ`, `Jungseong.ㅣ` 등)

### 아키텍처 제약
- iOS 키보드 익스텐션 메모리 한계 ~30MB
- `KeyboardViewController`는 UIKit, 나머지는 SwiftUI
- 롱프레스 팝업은 KeyboardView 최상위 ZStack에서 렌더링 (z-order 클리핑 방지)
- `HapticManager`는 `KeyboardSettings.shared.themeSettings`를 computed property로 매번 읽음
- 클릭 사운드는 `AudioServicesPlaySystemSound(1104)` 사용 (`playInputClick`은 익스텐션에서 불안정)
- `clickSoundEnabled`는 ThemeSettings 밖에 독립 Bool로 저장 (Codable 디코딩 실패 방지)

### 설정 시스템
```
KeyboardSettings (싱글톤, App Group UserDefaults)
├── gestureSettings: GestureSettings        (프로필 + 열별 보정)
├── themeSettings: ThemeSettings            (테마/투명도/햅틱)
│   └── resolvedKeyBackground/KeyText/FunctionKeyBackground (커스텀 vs 프리셋)
├── secondaryKeyActions: [SecondaryKeyAction]
├── shortcutExpansionStore: ShortcutExpansionStore
├── clickSoundEnabled: Bool                 (독립 저장)
├── longPressDelay: Double                  (0.2~1.0초)
├── sideKeyWidthRatio: Double               (0.15~0.5)
├── wordDeleteEnabled: Bool
├── wordDeleteDelay: Double
├── backspaceSpeed: Int                     (0=느림, 1=보통, 2=빠름)
├── showGesturePreview: Bool
├── showSecondaryHints: Bool
└── hintSize: Int                           (0=작게, 1=보통, 2=크게)
```

### 대각선 모음 매핑 (기본값)
```
↖ ↗ = ㅣ,  ↙ ↘ = ㅡ  (설정에서 변경 가능)
```
모음 제스처 전체 표: [README.md](README.md) 참조

## Bundle ID

| 타겟 | Bundle ID |
|------|-----------|
| 메인 앱 | `kr.koh0001.moa-plus` |
| 키보드 | `kr.koh0001.moa-plus.keyboard` |
| App Group | `group.com.moaki.keyboard` (변경 금지) |

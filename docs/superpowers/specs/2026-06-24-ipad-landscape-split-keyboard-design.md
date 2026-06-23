# iPad 동적 높이 + 가로 좌우 분리 키보드 (T6)

> 작성: 2026-06-24 / 브랜치 `ci/cli-test-and-actions` / 피드백 4

## 목표

아이패드에서 키보드를 쓸 만하게 만든다.
1. **동적 높이** — 현재 260pt 고정을 아이패드에서 화면에 맞게 키운다.
2. **가로 좌우 분리** — 아이패드 가로에서 좌=숫자패드, 우=모아키 그리드로 분리(핵심).

## 범위 / 비범위

**범위**
- 아이패드 세로: 높이만 확대(단일 그리드, 분리 없음).
- 아이패드 가로: 좌우 분리 레이아웃 + 확대 높이.
- 숫자패드 좌/우 위치 사용자 설정.

**비범위 (명시)**
- **아이폰은 한 줄도 건드리지 않는다** — 세로/가로 모두 현행 260pt·기존 레이아웃 유지.
- 아이패드 세로 분리 없음(폭이 좁아 분리 부적합).
- 그리드 폭 캡 없음 — 아이패드에서 키가 넓어지는 건 제스처 타겟에 오히려 유리.
- Stage Manager / Slide Over / 플로팅 키보드 특수 대응 없음(런타임 bounds 기반이라 자연 적응).

## 핵심 원칙: 아이패드 전용 하드 게이트

모든 신규 동작은 `traitCollection.userInterfaceIdiom == .pad` 안에서만 분기한다.
- 아이폰: `KeyboardMetrics.keyboardHeight` = 260 상수 유지, 분리 레이아웃 분기 진입 불가.
- 회귀 위험 0 보장. iPhone 경로 byte-for-byte 불변.

## 설계

### 1. 동적 높이 — 런타임 실측 기반 (모델 무관 정확)

`UIScreen.main.bounds`(point)에서 `short = min(w,h)`, `long = max(w,h)` 추출.

```
iPhone           : 260 (현행 상수)
iPad 세로        : clamp(long  × 0.30, 310, 400)
iPad 가로        : clamp(short × 0.44, 320, 420)
```

키 높이는 기존 식 `keyHeight(for: H) = (H − functionRowHeight − keySpacing×(gridRows+2)) / gridRows = (H − 68) / 4` 를 그대로 따른다.

검증 표 (계산 결과 → 키 높이):

| 기기 (point) | 세로 H → 키 | 가로 H → 키 |
|---|---|---|
| iPad mini 6 (744×1133) | 340 → 68pt | 327 → 65pt |
| iPad 10세대 (820×1180) | 354 → 71pt | 361 → 73pt |
| iPad Air/Pro 11" (834×1194) | 358 → 72pt | 367 → 75pt |
| iPad Pro/Air 13" (1024×1366) | 400(clamp) → 83pt | 420(clamp) → 88pt |

→ 키 65~88pt로 Apple iPad 키 수준. 계수(0.30 / 0.44 / clamp)는 `KeyboardMetrics` 한 곳 상수로 모은다.

**구현**
- `KeyboardMetrics.keyboardHeight(idiom:isLandscape:screenShort:screenLong:)` 함수 신설(또는 `keyboardHeight(for traitCollection:bounds:)`).
- `KeyboardViewController`: `viewDidLoad` / `viewWillAppear`에서 이 함수로 `heightConstraint.constant` 설정.
- `viewWillTransition(to:with:)` 오버라이드 → 회전 시 높이 재계산·갱신(coordinator.animate 안에서). 기존 키 스케일(`keyHeight(for:)`)이 늘어난 높이를 자동 반영.

### 2. 방향/기기 판정 → 분리 결정

- `isPad`: 컨트롤러의 `traitCollection.userInterfaceIdiom == .pad`. SwiftUI로 전달(KeyboardView init 파라미터 또는 ViewModel/Environment).
- 가로 판정: 익스텐션에서 `UIDevice.orientation` 불안정 → SwiftUI `GeometryReader`의 `geometry.size.width > geometry.size.height` 사용.
- **분리 조건** = `isPad && width > height`.
  - 아이패드 세로(`w ≤ h`) → 단일 그리드(확대).
  - 아이폰 → 항상 단일 그리드(기존).

### 3. 분리 레이아웃 뷰 (iPad 가로 전용)

`KeyboardView.body` 안에서 분리 조건이면 분리 레이아웃을 렌더(아니면 기존 VStack).

```
[분리 레이아웃]
 ├─ HStack(spacing)
 │   ├─ NumberPadView   (폭 ~31%)   ← 설정에 따라 좌/우
 │   └─ KeyGridView(모아키, 7×4)  (폭 ~69%)
 └─ FunctionRowView (전체 폭 공유)
```

- 좌우 순서는 `numberPadSide` 설정(`.left` 기본).
- 모아키 = 기존 `KeyGridView` 재사용 — 콜백/제스처/테마 그대로.
- `centerKeyWidth`는 모아키 패널 폭(≈ totalWidth×0.69) 기준으로 계산.
- 추상화 바·롱프레스 팝업 등 기존 오버레이는 ZStack 최상위 유지.

### 4. NumberPadView (신규)

- 3열 × 4행: `1 2 3 / 4 5 6 / 7 8 9 / . 0 ⌫`.
- 키 탭 → 기존 입력 재사용: 숫자/`.` → `viewModel.inputSymbol("1")` 등, `⌫` → `viewModel.deleteBackward()`(또는 backspace press 핸들러).
- 테마(`ConsonantKeyView`와 동일 색/투명도) 적용. 키 크기 = 패널 폭/3, 행 높이 = 키 그리드와 정렬.
- 햅틱/사운드는 기존 입력 경로가 처리.

### 5. 설정 — 숫자패드 좌/우

- `LayoutCustomization`에 `numberPadSide: NumberPadSide`(enum `.left` / `.right`, 기본 `.left`).
- `Codable` `decodeIfPresent` 가드 동반 — 기존 설정 디코딩 실패→전체 리셋 방지(CLAUDE.md 규칙).
- 설정 UI: `LayoutCustomizationView`(또는 `InputSettingsView`)에 토글/세그먼트 "iPad 가로 숫자패드 위치: 좌 / 우". (iPad에서만 의미 있으나 노출은 무방 — 안내 문구로 보조)
- App Group 영속.

## 테스트

**유닛 (`KeyboardMetricsLayoutTests` 등)**
- `keyboardHeight` 매트릭스: iPhone=260 불변, iPad 세로/가로 위 표 값(경계·clamp 포함).
- 분리 판정 술어: `isPad && w>h` true/false 케이스.
- `numberPadSide` round-trip 영속 + 구버전 JSON `decodeIfPresent` 호환.
- `NumberPadView` 키 탭 → `inputSymbol`/`deleteBackward` 호출(ViewModel 스파이 또는 composingText 검증).
- **iPhone 회귀 가드**: idiom=.phone일 때 keyboardHeight 260, 분리 미진입.

**수동 (iPad 시뮬레이터, 사용자 실기기 없음 → 시뮬레이터 필수)**
- iPad 세로/가로 회전 시 높이 갱신.
- 좌/우 설정 전환 반영.

## 신규/수정 파일

- 신규: `MoaPlusKeyboard/Views/NumberPadView.swift`, `MoaPlusKeyboard/Views/iPadSplitKeyboardView.swift`(또는 KeyboardView 내 분기).
- 수정: `KeyboardMetrics.swift`(높이 함수), `KeyboardViewController.swift`(idiom 전달 + viewWillTransition), `KeyboardView.swift`(분리 분기), `LayoutCustomization`(numberPadSide), 설정 뷰.
- 멤버십: 신규 익스텐션 UI 파일은 메인 앱이 직접 참조 안 하면 추가 불필요. `LayoutCustomization`은 이미 공유.

## 미해결/추후

- 아이폰 가로 높이 축소(이번 비범위).
- 아이패드 세로 분리(부적합 판단, 비범위).
- 그리드 폭 캡(키가 너무 넓으면 추후 옵션).

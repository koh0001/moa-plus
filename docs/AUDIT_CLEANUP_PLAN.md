# Moaki Custom — Post-launch Audit Cleanup Plan

생성: 2026-05-06 / 직전 fix: ㅗ→ㅘ 오인식 (data-driven sectors + directionChangeThreshold 분리, 105/105 green) / 입력: architect 전수 점검 + 5열 ↗→ㅣ 사용자 보고

## Step 0 — 범위 도전 (Scope Challenge)

**무엇이 이미 부분/전체로 풀려있나**
- 직전 PR 에서 sector 데이터 모델은 이미 데이터 기반으로 통합됨 (`GestureDirection.from(vector:sectors:rotationOffset:threshold:)`)
- `ColumnGestureOverride` 가 컬럼별 회전·iDelta·euDelta·directionChangeThresholdDelta 까지 들고 있음 — 데이터 모델은 ready
- `KeyboardSettings` 가 16개 `@Published` 필드로 호스트 ↔ 키보드 동기화 시도 중 (단, 알림 채널 끊김)

**최소 변경 범위**
- C1, C2: 호스트↔키보드 신뢰성 (데이터 손실 방지). **반드시 처리**.
- C3: 직전 fix 가 만든 dead-feature 즉시 노출.
- M1: 빌드 깨짐 잠재 (test target bundle id).
- H1, H2, H3: dead field/init param 제거 — 회귀 위험 거의 없는 청소.
- H4: `directionChangeThreshold` 단일 진실 정리.
- H5: 약어 글로벌 토글.
- H6: 약어 over-delete 안전성.
- 5열 ↗→ㅣ: default override 균형 재조정 + 회귀 테스트.
- C4: 검증 필요 (코드 흐름 추가 확인).
- 그 외 M2, M3, M6, M7: 작은 청소.

**8 파일 / 2 클래스 임계 검사**
이 plan 은 ~10 파일 손댐. 단 모두 읽기 쉬운 단일 의도(거짓말 UI 제거 / dead 정리 / 토글 추가). 8 임계는 형식적으로 넘지만 모두 같은 audit 결과를 따라가는 일관 작업이므로 단일 PR 로 묶음 정당화 가능.

**검색 (Layer 1/2)**
- App Group cross-process notification → iOS 내장 `UserDefaults.didChangeNotification` 또는 `CFNotificationCenter` darwin notification (Layer 1).
- `applicationWillEnterForeground` + `viewWillAppear` 의 차이는 익히 알려진 함정. iOS 14+ 에서 keyboard ext 라이프사이클 = `viewWillAppear` 이 비신뢰 → darwin notification 선호.

**Distribution check** — 키보드 extension 은 호스트 앱에 임베드되어 같은 IPA 로 배포. 신규 인프라 없음.

**완전성 (Boil the Lake)** — AI 비용 거의 0 인 만큼 dead field 5개 (H1+H2+H3) 한꺼번에 제거. UI 토글 (H5) 도 같은 PR.

---

## 구현 순서 (의존성 그래프)

```
[회색지대 검증 0번] App Group provisioning 실 상태 — 사용자가 Xcode 에서 확인
        │
        ▼
[Phase 1] C1: KeyboardSettings.init fallback 정책 — 결정 후 진행
        │
        ▼  (C1 fallback 형태가 C2 의 경고 UX 결정에 영향)
[Phase 2] C2: cross-process 변경 알림 (darwin notification) + loadAll batch
        │
        ▼  (병렬 가능)
[Phase 3] M1: test target bundle id 통일                ← 별도 lane
[Phase 4] C3: directionChangeThresholdDelta UI 노출      ← 별도 lane
[Phase 5] 5열 ↗→ㅣ default override 재조정 + 회귀 테스트  ← 별도 lane
        │
        ▼
[Phase 6] H3 → H1 → H2: dead init param + dead field 5개 제거 (한 PR 안에서 일괄)
[Phase 7] H4: directionChangeThreshold 단일 진실 정리
[Phase 8] H5: 약어 글로벌 ON/OFF 토글 + processCharacter/processBackspace 가드
[Phase 9] H6: 약어 over-delete 안전화 — fallback 루프 제거
[Phase 10] C4: space-drag 토글 게이트 위치 검증 + 필요시 수정
[Phase 11] M2, M3, M6, M7 소소 청소
[Phase 12] 회색지대 검증 (3, 4, 5) — Instruments / 시나리오 테스트
```

병렬 가능 lanes:
- Lane A: Phase 1→2 (settings 동기화 신뢰성)
- Lane B: Phase 3 (bundle id) — 독립
- Lane C: Phase 4 (UI 슬라이더) — 독립, 이전 PR 의 데이터 모델만 사용
- Lane D: Phase 5 (5열 fix) — Engine 만 손댐
- 합류: Lane B/C/D 끝나면 Phase 6 부터 sequential

---

## 의존성 / 영향 관계

| 단계 | 의존 | 영향 |
|---|---|---|
| 회색지대-0 | — | C1 fallback 정책의 형태를 바꿈 |
| C1 | 회색지대-0 결정 | C2 의 경고 UX |
| C2 | C1 | M2 (loadAll batch) 동시 처리 |
| M1 | — | 빌드 / 테스트 서명 안정 |
| C3 | 직전 PR 의 `directionChangeThresholdDelta` 필드 | 사용자 self-tune 가능 |
| Phase 5 (5열) | 직전 PR 의 sector 모델 | 회귀 테스트 추가 필요 (직전 PR 테스트와 충돌 X) |
| H3/H1/H2 | — | API 단순화. 테스트 init param 변경 동반 |
| H4 | H3 결정에 따른 단일 진실 위치 | 마이그레이션 필요 시 별도 |
| H5 | — | 약어 동작 옵트아웃 가능 |
| H6 | H5 후가 안전 (글로벌 OFF 시 진입 자체 차단) | 데이터 손실 위험 제거 |
| C4 | 코드 추가 검증 | 토글 OFF 사용자 회귀 |
| M2 | C2 와 묶임 | redraw 빈도 |
| M3 | — | 사용자 reset 신뢰 |

---

## 결정 게이트 (사용자 입력 필요 — D1~D5)

이 5개가 답해지기 전까지 phase 1·4·5·7·8 진행 불가.

### D1 — C1 의 침묵 fallback 처리 정책
**ELI10**: 키보드가 호스트 앱과 설정을 공유하려면 둘 다 같은 "App Group" 이라는 공유 컨테이너에 합의해야 한다. 코드는 이 컨테이너가 막히면 기본 컨테이너로 슬쩍 떨어지는데, 그러면 호스트 앱의 설정이 키보드에 0% 반영된다. 진단 로그도 안 찍히니 누구도 모른다.
- **A) UI 가시 경고** (recommended) — fallback 발동 시 호스트 앱 진입 시 1회 alert "App Group 설정이 잘못됐습니다. 재설치 필요" + Console 에러 로그. 사용자가 즉시 알게 됨.
  - ✅ release 빌드에서도 작동, 진짜 문제 발생 시 사용자가 행동 가능
  - ✅ 재설치만으로 해결되는 경우가 대부분 — 명확한 가이드 제공 가능
  - ❌ 정상 동작 사용자에게도 1회 sanity check 코드가 추가됨 (오버헤드 미미)
- **B) `assertionFailure` + 디버그 로그**
  - ✅ 개발 빌드에서 즉시 멈춰서 잡힘
  - ❌ release 빌드에선 silent 그대로 — 정식 발매 앱에서 무용지물
- **C) silent 유지, 진단 로그만 추가**
  - ✅ 사용자 경험 변화 0
  - ❌ 본 문제 그대로
- **추천**: A. 정식 발매 앱이라 release 에서도 작동해야 하고, 사용자가 영문 모르고 별 1점 리뷰 다는 케이스 봉쇄.

### D2 — C3 의 UI 슬라이더 위치
**ELI10**: 직전 PR 에서 컬럼별 "두 번째 stroke 등록 거리" 보정값을 추가했는데 사용자가 조절할 슬라이더가 어디에도 없다. 어디에 둘까?
- **A) `ColumnCorrectionDetailView` 내부, 기존 회전·iDelta·euDelta 와 같은 줄** (recommended)
  - ✅ 컬럼 보정 모델이 한 화면에 모임 — 발견성 높음
  - ✅ 직전 PR 의 데이터 구조와 1:1 매핑
  - ❌ 컬럼 보정 화면이 더 길어짐
- **B) `InputSettingsView` 의 별도 "Advanced" 섹션 (글로벌 1개 + 컬럼별 5개)**
  - ✅ 글로벌 default 와 함께 이해할 수 있음
  - ❌ 컬럼 보정과 분리됨 — 사용자 혼란 가능
- **추천**: A. 데이터 모델 자체가 column override 안에 있고, 실제 효과도 컬럼별로 나타남.

### D3 — H4 의 `directionChangeThreshold` 단일 진실
**ELI10**: 같은 개념이 4 곳에 있다 — `KeyboardMetrics` (정적 default), `GestureSettings` (사용자 저장), `GestureAnalyzer.init` 인자, `ColumnGestureOverride` delta. 어디를 진짜 정답으로 두고 나머지 정리할까?
- **A) `GestureSettings.directionChangeThreshold` (글로벌) + `ColumnGestureOverride.directionChangeThresholdDelta` (per-column delta) 만 남김. `KeyboardMetrics` 상수는 단지 default 초기값으로만 참조. `GestureAnalyzer.init` 의 인자는 테스트 전용(`directionChangeThreshold: CGFloat?`) 으로 유지** (recommended)
  - ✅ 직전 PR 의 변경과 정합 — 추가 마이그레이션 불필요
  - ✅ 사용자 변경/컬럼 보정/테스트 override 가 명확히 분리
  - ❌ 4 곳이 완전히 1 곳으로 줄지 않음 (3 곳)
- **B) 모든 사용을 `GestureSettings` 로 모음. test override 도 settings 인스턴스 주입으로**
  - ✅ 진짜 단일 진실
  - ❌ 모든 테스트가 `GestureSettings` 빌더 거쳐야 함 — 회귀 위험
- **추천**: A. 직전 PR 과 정합하고 테스트 부담 적음.

### D4 — H5 약어 글로벌 ON/OFF 위치
**ELI10**: 약어 기능을 통째로 끌 토글이 없다. 사용자는 trigger 다 지워야 끌 수 있다.
- **A) `AbbreviationSettingsView` 화면 최상단 토글** (recommended)
  - ✅ 약어 화면 들어가서 OFF — 직관적
  - ✅ trigger 데이터는 보존, 다음에 재활성화 가능
  - ❌ 약어 화면 1번 진입 필요
- **B) `InputSettingsView` 의 "Advanced" 섹션**
  - ✅ 모든 토글이 한 화면에
  - ❌ 약어 화면과 분리 — 사용자가 약어 끄려고 약어 화면 갔다가 못 찾음
- **추천**: A.

### D5 — 5열 ↗→ㅣ fix 방향
**ELI10**: 5열에서 ↗ 그어서 ㅣ 의도였는데 ㅘ 가 나오는 케이스. 원인 추정: col 5 의 default rotation -5° 가 sector 를 시계방향 5° 회전 → ↗ 상한이 ~65.5° 로 깎임 → 70°+ 의 가파른 ↗ 가 ↑ 영역으로 빠짐 → 끝 휨이 두 번째 stroke → ㅘ.
- **A) default override 균형 조정** (recommended) — col 5 rotation 을 -5° → -3° 또는 0° 로 완화 + iDelta 를 3° → 5° 로 확장. col 1 도 대칭으로 조정. 회귀 테스트 (col 5 의 78° 벡터가 ↗ 로 분류되는지) 추가.
  - ✅ 한 줄 변경 + 테스트 1~2개. 회귀 위험 최소
  - ✅ 사용자가 더 튜닝하고 싶으면 D2 의 UI 로 추가 조정 가능
  - ❌ 다른 컬럼 사용자 손맛에 미세 영향 (방향성: ↗ 더 잘 잡히는 쪽)
- **B) sector 우선순위 변경 (cardinal-first)**
  - ✅ ↑/↓ 가 더 우선 — 정수직 의도 보호
  - ❌ 직전 PR 의 다이아고날-우선 정책 뒤집음 — 다른 회귀 위험 큼
- **C) UI 만 노출, default 는 그대로** (사용자 self-tune 만 의존)
  - ✅ 다른 컬럼 영향 0
  - ❌ default 가 안 좋은 채로 출시된 사용자는 그대로 ㅘ 오인식
- **추천**: A. 정식 발매 앱이라 default 가 정답에 가까워야 한다.

---

## 단계별 실행 상세

### Phase 1 — C1: KeyboardSettings.init fallback 처리 (D1 후)
**파일**: `MoaPlusKeyboard/Utilities/KeyboardSettings.swift:136-142`
**변경**:
- App Group container 검증 헬퍼 `appGroupSanityCheck()` 추가 (호스트 앱 init 1회).
- D1=A 라면: 호스트 앱 진입 시 `UserDefaults(suiteName:)` 가 nil 이면 alert + Console.error.
- 키보드 ext 측은 nil fallback 시 NSLog 1회 + 1회만.

**테스트**: unit 으로는 nil 시뮬 어렵다. `KeyboardSettings.init(suiteName:)` 인자화하고 mock 으로 검증.

**회귀 위험**: 정상 사용자 첫 진입 1회 sanity check (overhead 미미).

### Phase 2 — C2: cross-process 변경 알림 + loadAll batch
**파일**: `KeyboardViewController.swift:43-54`, `KeyboardSettings.swift:148-167`
**변경**:
- 호스트 앱이 `KeyboardSettings` 변경 시 `CFNotificationCenterPostNotification(.darwin)` post.
- 키보드 ext 는 `viewDidLoad` 에서 darwin notification observer 등록 → callback 에서 `loadAll()`.
- `loadAll()` 안: 16개 backing store 직접 세팅 후 `objectWillChange.send()` 1회만.

**테스트**: `KeyboardSettingsCrossProcessTests` (XCTestExpectation + notification). 단, 두 프로세스 분리 어려우므로 같은 프로세스 내 두 인스턴스 동기화로 시뮬.

**회귀 위험**: notification 폭주 시 `loadAll` 호출 폭주. throttle (코드 비슷한 시점 0.1s 합치기) 권장.

### Phase 3 — M1: test target bundle id 통일
**파일**: `MoaPlus.xcodeproj/project.pbxproj` (line 875, 897 부근)
**변경**: `kr.flomi.app.MoaPlusKeyboardTests` / `kr.flomi.app.MoaPlusTests` → `kr.koh0001.MoaPlusKeyboardTests` / `kr.koh0001.MoaPlusTests`.
**테스트**: `xcodebuild test -scheme MoaPlus` 통과 확인.
**회귀 위험**: Xcode 자동서명 cache 꼬일 수 있음 — DerivedData clean 권장.

### Phase 4 — C3: directionChangeThresholdDelta UI 노출 (D2 후)
**파일**: `MoaPlus/Settings/ColumnCorrectionDetailView.swift` (또는 `InputSettingsView.swift` 의 컬럼 detail 부분)
**변경**: 슬라이더 추가 (-5 ~ +15 pt, step 1, default 0). 라벨 "방향 전환 거리 보정". 변경 즉시 `KeyboardSettings.shared.gestureSettings.columnOverrides[i].directionChangeThresholdDelta` 업데이트.
**테스트**: snapshot 또는 수동.
**회귀 위험**: 0.

### Phase 5 — 5열 ↗→ㅣ default override 재조정 (D5 후)
**파일**: `MoaPlusKeyboard/Models/ColumnGestureOverride.swift:24-35`
**변경 (D5=A 가정)**:
- col 1: rotationOffsetDeg `5.0` → `3.0`, verticalIWidthDelta `3.0` → `5.0`
- col 5: rotationOffsetDeg `-5.0` → `-3.0`, verticalIWidthDelta `3.0` → `5.0`
**테스트**: `GestureAnalyzerTests` 에 케이스 2개 추가.
- col 5 + threshold=20 + 78° 벡터 → ↗ 단일 stroke 로 분류 ([.upRight])
- col 1 + threshold=20 + 102° 벡터 → ↖ 단일 stroke 로 분류 ([.upLeft])
**회귀 위험**: 다른 컬럼에서 ㅗ→ㅘ 회귀 가능성. 직전 PR 의 회귀 테스트가 col 0 (no override) 케이스라 이 변경에 영향 안 받음. 그래도 col 4 케이스 추가 권장.

### Phase 6 — H3 → H1 → H2: dead 청소
**파일**: `KeyboardViewModel.swift:101-114`, `GestureSettings.swift:10-11, 23-24`
**변경**:
- `KeyboardViewModel.init(backspaceRepeatInterval:)` 인자 + stored property 제거. 모든 호출처 update.
- `GestureSettings.longPressDelayMs`, `movementToleranceForLongPress`, `leftEdgeOutwardDistanceMultiplier`, `rightEdgeOutwardDistanceMultiplier` 4개 필드 제거. `Codable` decode keepDecoding (unknown key skip 자동).

**테스트**: 기존 105 테스트 grin 유지.
**회귀 위험**: Codable migration — 기존 사용자 저장 settings 가 4개 필드 가진 채 저장되어 있을 수 있다. Swift `Codable` 의 default 는 알 수 없는 키 ignore — 안전.

### Phase 7 — H4: directionChangeThreshold 단일 진실 (D3 후)
**파일**: `KeyboardSettings.swift`, `GestureAnalyzer.swift`, `GestureSettings.swift`, `KeyboardMetrics.swift`
**변경 (D3=A 가정)**:
- `KeyboardMetrics.directionChangeThreshold` 는 const 그대로 (default 초기값으로만).
- `GestureSettings.directionChangeThreshold` 는 사용자 settings 의 단일 진실.
- `GestureAnalyzer` 의 `directionChangeThreshold` 인자는 deprecated 주석 + 테스트 전용 명시.
- 모든 production 경로가 `effectiveDirectionChangeThreshold` 통과하는지 검증.

**테스트**: 기존 그대로 + 정책 명시 주석.

### Phase 8 — H5: 약어 글로벌 토글 (D4 후)
**파일**: `KeyboardSettings.swift` (`@Published abbreviationEnabled: Bool = true`), `KeyboardViewModel.swift:341-351, 354-361`, `MoaPlus/Settings/AbbreviationSettingsView.swift`
**변경**:
- `KeyboardSettings.abbreviationEnabled` 추가.
- `processCharacter` / `processBackspace` 진입에서 `if !abbreviationEnabled { return false }` 가드.
- D4=A 라면 `AbbreviationSettingsView` 최상단에 토글 추가.

**테스트**: ON/OFF 양쪽 trigger 무시/동작.

### Phase 9 — H6: 약어 over-delete 안전화
**파일**: `KeyboardViewModel.swift:843-870`
**변경**: `before.hasSuffix(trigger)` 만 검사. fallback 루프 제거. trigger.count 만큼만 삭제.
**테스트**: trigger 의 일부 prefix 가 다른 단어와 겹치는 케이스 — 의도하지 않은 삭제 발생 안 해야 함.

### Phase 10 — C4: space-drag 토글 게이트 검증
**파일**: `MoaPlusKeyboard/Views/FunctionRowView.swift:315` 주변 전체 흐름
**변경**: `cursorMoveBySpaceDragEnabled` OFF 시 `didDrag` 임계값 비교 자체를 스킵. tap 처리 정상 보장.
**테스트**: 토글 OFF + 짧은 swipe 시 공백 입력되는지 (수동 또는 simulated touch sequence).
**회귀 위험**: 토글 ON 사용자 영향 없도록 분기만 추가.

### Phase 11 — 소소 청소 (M2/M3/M6/M7)
- M2: Phase 2 와 묶음 (`loadAll` batch).
- M3: `resetAll()` 에 누락된 9개 필드 추가.
- M6: `isSymbolMode` setter 의 `_ = newValue` 제거 (사용처 grep 후).
- M7: `deleteWord()` 의 magic 5 → no-op fallback.

### Phase 12 — 회색지대 검증

| 항목 | 검증 방법 | 사용자 액션 |
|---|---|---|
| 1. App Group 프로비저닝 | Xcode → MoaPlus / MoaPlusKeyboard 양쪽 Signing & Capabilities → App Groups 토글 모두 켜져있고 동일 ID? Apple Developer Portal 의 App Groups 등록? | 사용자가 Xcode 화면 보고 확인 |
| 2. test target bundle id 출처 | `git log --all -p -- MoaPlus.xcodeproj/project.pbxproj \| grep "kr.flomi.app"` | Phase 3 와 함께 |
| 3. 키보드 60MB 한도 | Instruments Allocations + 실 디바이스 | Phase 종료 후 별도 |
| 4. shift state 일관성 | 사용자 시나리오 4가지 — caps lock 켜고 한↔영 ↔ 기호 순회 | 사용자 수동 테스트 |
| 5. textDidChange composer reset | 카카오톡, iMessage, Slack 각 1회 long-press send button | 사용자 수동 테스트 |

---

## 회귀 위험 종합

| Phase | 위험 | 완화 |
|---|---|---|
| 1 | sanity check 가 정상 사용자 처음 진입 살짝 느려짐 | 1회 only, async |
| 2 | darwin notification 폭주 | throttle |
| 3 | Xcode 서명 cache | DerivedData clean 가이드 |
| 5 | 다른 컬럼 손맛 변화 | col 4 회귀 테스트 추가 |
| 6 | Codable migration | unknown key ignore 검증 |
| 8 | 약어 toggle 와 trigger 데이터 동기화 | 토글 OFF 후 ON 시 trigger 그대로 |

## NOT in scope

- iOS 60MB 메모리 압박 정밀 측정 (Instruments 작업) — Phase 12 회색지대 후 별도 PR
- shift state 시나리오 검증 — 사용자 수동 테스트 결과 보고 별도 PR
- 한국어 외 언어 번역 (`Localizable.strings` 부재) — Phase 2 별도 작업
- HangulComposer dotPending 시각 일관성 (architect L5) — 별도 PR

## What already exists (재사용)

- `GestureDirection.from(vector:sectors:rotationOffset:threshold:)` — 직전 PR 산물
- `GestureSettings.effectiveSwipeThreshold` / `effectiveDirectionChangeThreshold` — 직전 PR
- `ColumnGestureOverride.directionChangeThresholdDelta` — 직전 PR (UI 만 추가)
- `KeyboardSettings.objectWillChange` Combine sink — Phase 2 의 darwin notification observer 가 hook 가능
- `xcodebuild test` workflow — 105 테스트 그린

## TODOs

- [ ] (Phase 12) Instruments 메모리 측정
- [ ] (별도) HangulComposer L5 dotPending 시각 일관성 명시 테스트
- [ ] (별도) Localizable.strings 도입

## Decisions LOCKED-IN (2026-05-06)

| # | 결정 |
|---|---|
| D1 | A — UI 가시 경고 + Console error |
| D2 | A — ColumnCorrectionDetailView 안 (회전·iDelta·euDelta 옆) |
| D3 | A — GestureSettings + ColumnOverride 정답, KeyboardMetrics 는 default 초기값, Analyzer init 은 테스트 전용 |
| D4 | A — AbbreviationSettingsView 화면 최상단 토글 |
| D5 | A — col 5 rotation -5→-3, iDelta 3→5; col 1 대칭 (+5→+3, 3→5) + 회귀 테스트 |

## Execution log (live)

| Phase | 상태 | 결과 |
|---|---|---|
| Phase 3 (M1 bundle id) | ✅ | `kr.flomi.app.MoaPlusKeyboardTests` → `kr.koh0001.moa-plus.keyboard-tests` (pbxproj 2 곳) |
| Phase 4 (C3 UI 슬라이더) | ✅ | `ColumnCorrectionDetailView` 에 "방향 전환 거리 보정" 슬라이더 (-5~+15pt) 추가 |
| Phase 5 (5열 ↗→ㅣ) | ✅ | col 1/5 default override 조정 (rotation ±5→±3, iDelta 3→5) + 회귀 테스트 3개 |
| Phase 6 (H3/H1/H2 dead 정리) | ✅ | `KeyboardViewModel` init `backspaceRepeatInterval` 제거. `GestureSettings` 의 `longPressDelayMs`/`movementToleranceForLongPress`/`leftEdge*`/`rightEdge*` 4개 dead field 제거. `HapticManager.updateSettings` 빈 함수도 제거 (L2). |
| Phase 7 (H4 단일 진실) | 🟡 | 코드 정합 — 각 layer 의 책임 주석으로 명시. 추가 변경 없음. |
| Phase 8 (H5 약어 토글) | ✅ | `KeyboardSettings.abbreviationEnabled` 추가, `AbbreviationEngine.isEnabled` 게이트, 약어 화면 최상단 토글. M3 (resetAll 9개 필드 누락) 함께 fix. |
| Phase 9 (H6 over-delete) | ✅ | `shouldReplace` fallback 루프 제거. 정확히 trigger.count 의 1배 또는 2배만 삭제, 부분 suffix 삭제 안 함. |
| Phase 10 (C4 space-drag) | ✅ | 토글 OFF 일 때 `didDrag` 진입 자체 skip → onTap fallback 정상 작동. |
| Phase 11 (M6, M7) | ✅ | `isSymbolMode` 읽기전용으로 단순화. `deleteWord` magic 5 → no-op. |
| Phase 1+2 (C1+C2) | ✅ | (1) `KeyboardSettings.isUsingAppGroup` 플래그 + Console 경고 + 호스트 앱 시작 시 alert. (2) Darwin notification cross-process 동기화 + UserDefaults.didChangeNotification → 자동 broadcast + 0.1s coalesce. GZ-1 사용자 확인 끝 (Xcode + Portal 모두 OK). |
| Phase 12 (회색지대 검증 3-5) | ⏸️ | 사용자 수동 시나리오 (60MB / shift state / textDidChange) |
| Caps-lock 롱탭 (사용자 보고) | ✅ | 영문 shift 키 long-press 시 caps lock 토글. `lockShift()` 추가, `KeyView.onShiftLongPress` 콜백 + `startLongPressTimer` shift 분기, ConsonantGridView/KeyboardView callback 전파. |
| Swipe length 디바이스 적응 | ✅ | `SwipeLength.threshold(keyWidth:)` 로 변환 — short/normal/long = keyWidth × 0.24 / 0.40 / 0.60. 50pt 기준 12/20/30 동일, SE/Pro Max 자동 비례. `GestureAnalyzer.keyWidth` 프로퍼티 + `KeyboardViewModel.setCenterKeyWidth(_:)` + `KeyboardView` 의 `.onAppear`/`.onChange` 와이어링. 굿기 테스트는 `UIScreen.bounds.width` 기반 추정. |




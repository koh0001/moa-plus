# 작업 핸드오프 — 앱스토어 리뷰 대응 + 순정 모아키 전환

> 작성: 2026-08-10 / 갱신: 2026-08-10 (지구본 기본 OFF + 감사 결과 수령) /
> 브랜치: `feat/symbol-pages-space-scroll` / 마지막 커밋 `b1fdbdb`
> **전부 미커밋 상태다.** `git status` 로 확인할 것 (수정 18 + 신규 7).
> 테스트: 전체 스킴 **350개 통과 / 실패 0** (`iPhone 17`, `** TEST SUCCEEDED **` 확인).
>
> ⚠️ `xcodebuild ... | tail` 로 파이프하면 zsh 파이프라인 exit code 가 `tail` 의 것이라
> **테스트 실패가 exit 0 으로 보인다.** 로그를 파일로 받고 `TEST SUCCEEDED` 를 직접 grep 할 것.

---

## 0. 먼저 읽을 것 — 이번 세션의 함정

### 0-1. 워크플로 에이전트가 작업트리를 수정했다 (실제 발생)
검증용 Workflow 를 띄우면서 프롬프트로 "저장소 파일 수정 금지"라고만 지시했는데 **지켜지지 않았다.**
`GestureAnalyzer.trailingNoiseRatio` 가 0.4 → 0.75 로 바뀌고(`// EXPERIMENT E4`),
특성화 테스트 하니스에 `swipeLength = .long` 이 주입됐다(`// E9`).
그 상태로 측정한 결과를 근거로 잘못된 결론("0.75가 우수")을 낼 뻔했다.

**대응 규칙**: 코드를 만지는 Workflow 는 반드시 `isolation: "worktree"` 로 띄우고,
결과를 받으면 **`git status` 와 실험 마커 grep 을 먼저** 돌린 뒤 해석할 것.
```bash
grep -rn "EXPERIMENT\|// E[0-9]" --include="*.swift" MoaPlus MoaPlusKeyboard MoaPlusKeyboardTests
```

### 0-2. 시뮬레이터에 앱을 띄우면 유닛 테스트가 깨진다
App Group UserDefaults 를 유닛 테스트와 공유하므로, 앱을 수동 실행한 시뮬레이터에서
`KeyboardViewModelVowelDragTests` 등이 결정적으로 실패한다.
**유닛 테스트는 `iPhone 17`, 수동 실행은 `iPhone 17 Pro`** 로 분리해 썼다. 이 분리를 유지할 것.
오염되면 `xcrun simctl shutdown <id> && xcrun simctl erase <id>`.

### 0-3. 시뮬레이터에서 키보드 활성화는 plist 편집으로 안 된다
`.GlobalPreferences` 의 `AppleKeyboards` 배열에 번들 ID 를 직접 써넣으면
설정 앱의 카운트만 늘고 **키보드 데몬은 인식하지 않는다**(익스텐션 프로세스가 뜨지 않음).
게다가 그 가짜 항목이 "새로운 키보드 추가" 목록에서 모아+ 를 숨겨 **정식 추가를 막는다.**
반드시 설정 UI(설정 → 일반 → 키보드 → 키보드 → 새로운 키보드 추가)로 추가할 것.

### 0-4. Simulator 창 좌표 변환 (UI 자동화 시)
Orca `computer click` 은 창 로컬 좌표를 쓴다. iPhone 17 Pro 창(435×929) 기준 실측 변환:
```
window_x = 12.6 + device_pt_x * 1.0195
window_y = 38   + device_pt_y * 1.0195      # 38 = 타이틀바
# 스크린샷 픽셀 → pt 는 /3 (3x)
```
오프셋(12.6, 38)을 빼먹으면 화면 아래쪽으로 갈수록 어긋나 탭이 조용히 빗나간다.
"클릭 ok=true 인데 화면이 안 바뀐다"면 이걸 의심할 것.

---

## 1. 완료된 작업

### A. 앱스토어 리뷰 대응 — 높이 조절 + 지구본 키
| 항목 | 내용 |
|---|---|
| 요청 | 키보드 높이 조절(리뷰 4건), 키보드 전환 키(리뷰 2건) |
| 설정 | `keyboardHeightScale`(0.85~1.35, 기본 1.0), `showGlobeKey`(기본 **OFF** — §4 에서 변경) |
| UI | `MoaPlus/Settings/KeyboardSizeSettingsView.swift` (신규) — 슬라이더 + 되돌리기 + 실시간 미리보기 |
| 핵심 | `KeyboardMetrics.keyboardHeight(...scale:)` 기본 인자 1.0 → 기존 호출부 무손상 |

**⚠️ iOS 26 아이폰에서 지구본 키는 표시되지 않는다** (시뮬레이터 실측).
iOS 26 이 서드파티 키보드 아래에 지구본 바를 직접 그리고, 이때 `needsInputModeSwitchKey == false`
를 반환한다. 우리 지구본은 이 값에 게이팅돼 있어(중복 방지) 렌더되지 않는다.
→ **사용자가 "기본 OFF + 설정 유지"로 결정했으나 아직 미구현.** 아래 §4 참조.

### B. 순정 모아키 입력 방식 전환 (핵심)
**조사 결론**: 우리 자음 키 패턴 테이블(`VowelPattern.all`)은 **이미 순정과 100% 일치**했다.
불일치는 v1.7 에 우리가 추가한 `resolveConsonantDiagonalVowel`(대각선 진입 후 천지인 파생)
하나뿐이었고, 그게 리뷰 오타의 원인이었다.

순정 스펙 근거 (독립 2개 자료 일치):
- `docs/moakey_ios_custom_docs/assets/03_gesture_angle_reference.png` — 실제 삼성 모아키 설정(양손용).
  8섹터가 `↑=오 ↓=우 →=아 ←=어 ↖↗=이 ↙↘=으` 로 라벨링돼 있다.
- [나무위키 모아키](https://namu.wiki/w/모아키) — 복합모음은 방향 **조합**:
  `ㅘ=↑→(↱) ㅝ=↓←(↲) ㅚ=↑↓ ㅟ=↓↑ ㅐ=→← ㅔ=←→ ㅛ=↑↓↑ ㅠ=↓↑↓ ㅑ=→←→ ㅕ=←→← ㅙ=↑→+왕복 ㅞ=↓←+왕복`

**변경**: `consonantDiagonalDerivationEnabled`(기본 **false** = 순정) 신설.
`KeyboardViewModel.resolveConsonantDiagonalVowel` 진입부에서 게이팅 → 호출 3곳 전부 커버.
UI 는 `GestureSettingsView` 의 "입력 방식" Picker (`순정 모아키` / `확장 (대각선 진입)`).

단독 대각선(↗=ㅣ, ↘=ㅡ)은 순정과 같으므로 **트라이가 그대로 처리**한다.
전용 ㅣ/ㅡ 키가 없는 **클래식/확장형 레이아웃의 유일한 ㅣ/ㅡ 경로**라 절대 깨면 안 되고,
회귀 가드가 `test_moakeyDefault_pipeline_soloDiagonalsStillProduceBarAndDash` 다.

### C. 긋기 엔진 결함 2건 (순정 전환만으로 안 잡히는 잔여를 파다 발견)
1. **후행 노이즈 트림이 인접(≤45°) 꼬리만 제거**하고 있었다.
   실제 꼬리는 ↗(180°)·↑(135°)·↘(90°)처럼 급격한 쪽이 더 흔해 전부 빠져나갔다 — 의도와 정반대.
   → 절대 크기(`edgeNoiseCap`) + 직전 획 대비 비율(`trailingNoiseRatio`) 결합, 꼬리가 여러 조각일 수
   있어 `while` 반복 제거.
2. **`directionMagnitudes` 가 획의 실제 길이가 아니었다.** 임계를 넘는 순간의 변위만 기록해
   60pt 획도 임계값(≈20pt)으로 남았다. `normalizeSegments` 의 모든 비율 판정이 이 값을
   "직전 획 길이"로 전제하고 있었으므로 노이즈와 의도적 획을 비율로 구분하는 게 불가능했다.
   → `strokeOriginPoint` 도입, 같은 방향 연장 중 magnitude 를 실제 길이로 갱신.

### D. 프리즈 리포트 조사 (원인 미확정)
Geumji5 "제미나이에서 사진 첨부하면 키보드 높이가 엄청 늘어나고 멈춥니다" (iPhone 15 Pro).
**리뷰 원문에 앱/웹 구분은 없다.** 사용자가 웹·앱 양쪽에서 첨부·붙여넣기 모두 시도했으나 **재현 실패.**

조사 중 발견한 별개 실재 결함 2건을 수정했다 (**리포트의 확정 원인 아님, 릴리스 노트에
"프리즈 수정"으로 쓰지 말 것**):
- 배경 이미지가 원본 해상도로 디코딩됐다. 12MP 사진 = ARGB 약 48MB 로 익스텐션 한계(~30-60MB)를
  단독 초과. → 저장 시 긴 변 1536px 축소 + ImageIO 썸네일 디코딩(기존 저장분도 방어).
- 키보드가 사라져도 백스페이스 반복 타이머가 계속 돌았다(Timer 구동이라 터치 종료와 무관).
  → `viewWillDisappear` 에서 정리. **단 `resetGestureState()` 를 통째로 부르므로 팝업 해제·약어
  스토어 재로드까지 함께 일어난다. 테스트가 없는 생명주기 변경이니 재검토 여지 있음.**

함께 보고된 "높이가 엄청 늘어남"은 `KNOWN_ISSUES.md` KI-1 계열로 보이나 트리거가 달라 단정하지 않았다.

---

## 2. 측정 도구 — 이걸 먼저 익힐 것

`MoaPlusKeyboardTests/GestureOverDetectionCharacterizationTests.swift` 가 이번 작업의 핵심 계측기다.

- **`drivePath(row:column:segments:stepsPerSegment:)`** — 다구간 폴리라인 하니스.
  기존 `driveKeyGesture` 는 단일 직선(dx/dy)만 가능해 꺾인 궤적을 **구조적으로 재현할 수 없었다.**
- **경로 × 민감도(0/1/2) 매트릭스**를 `.xcresult` 첨부로 남긴다. 3개 섹션:
  자음 대각선 진입 / ㅡ 전용 키(진입 분열·과소 인식·ㅙㅞ 가드) / 자음 키 의도적 복합모음(트림 회귀 가드).

### 매트릭스 뽑는 법
```bash
SS=/tmp/moa && mkdir -p $SS && cd $SS
xcodebuild test -project /Users/ockhyunkim/GitHub/moa-plus/MoaPlus.xcodeproj -scheme MoaPlus \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MoaPlusKeyboardTests/GestureOverDetectionCharacterizationTests/test_characterize_matrix_attachesReport \
  -resultBundlePath m.xcresult >/dev/null 2>&1
mkdir -p att && xcrun xcresulttool export attachments --path m.xcresult --output-path att
# att/manifest.json 에서 suggestedHumanReadableName 이 b1_gesture_matrix* 인 파일을 읽으면 된다
```

### 하니스를 건드릴 때 주의
`withSensitivity` 안에서 `swipeLength` 같은 다른 설정을 바꾸면 **모든 임계가 함께 스케일되어
측정 조건이 오염된다.** 실제로 이 오염 때문에 잘못된 결론을 낼 뻔했다(§0-1).
상수 튜닝을 비교할 때는 **상수 하나만** 바꾸고 나머지는 고정할 것.

---

## 3. 확정된 기준선 (기본 설정, `trailingNoiseRatio = 0.4`)

| 경로 (의도: 으) | sens0 | sens1 | sens2 |
|---|---|---|---|
| ↙ 단독 | 으 | 으 | 으 |
| ↙ + 8pt 흔들림 | 으 | 으 | 으 |
| ↙ + 15pt 흔들림 | **의** | 으 | 으 |
| ↙ + 20pt 흔들림 | **의** | **의** | 으 |
| ↙ + 호꼬리 ↑15→15 | **의** | 으 | 으 |
| 짧은↙30 + 흔들림15 | **의** | **의** | **의** |

**리뷰가 지적한 심각한 오타(이→와, 으→워, 오→와)는 전 민감도에서 사라졌다.**

### 알려진 잔여 (테스트로 고정돼 있음)
- 기본 민감도(0)에서 ↙ 뒤 15~20pt 흔들림이 아직 **ㅢ** 로 승격. ㅢ 는 순정에도 있는 조합(↙↗)이라
  논리적으로 도달 가능하고, 와/워 대비 경미하다.
- 진입 획이 짧을 때(30pt) 꼬리(18pt)가 그 61% 라 비율로도 노이즈 판정 불가 —
  의도적인 짧은 ㅢ 왕복과 구분되지 않는다.
- **더 좁히려면 등록 임계를 건드려야 하는데, 그러면 리뷰의 다른 갈래("빨리 치면 인식 안 됨",
  모아키가 최고·dawnboy!)가 악화된다.** 이 트레이드오프를 모르고 임계를 낮추지 말 것.

### `trailingNoiseRatio` 값에 대한 결론
0.4 와 0.75 를 **하니스 고정 상태에서** 비교한 결과 **37개 경로 전부 동일**(차이 0건).
`isTinyAbsolute && (isTinyRelative || isAdjacent)` 구조에서 절대 상한이 먼저 지배하기 때문이다.
비율은 좁은 구간에서만 작동하는 2차 필터다. 근거가 없어 더 보수적인 **0.4 유지**.

---

## 4. 다음 할 일 (우선순위)

### 즉시 — 사용자가 결정했으나 미구현
- [x] **지구본 키 기본값 ON → OFF** (2026-08-10 완료). 편집한 곳은 6군데다 —
      `KeyboardSettings.swift` 3곳(`@Published` 기본값 + `loadAll` 의 `?? false` + `resetAll`),
      `NewFeaturesModalView`(문구를 "설정에서 켜세요"로), `CHANGELOG`("기존 사용자 레이아웃 변경
      주의" 항목을 "기본 OFF" 로 대체 + 새 기능 항목에도 기본 OFF 명시), `CLAUDE.md` 설정 표.
      `KeyboardSizeSettingsView` footer 도 보강했다(이제 이 화면이 유일한 진입점이라,
      켜도 iOS 26 에서는 시스템 바가 대신 뜬다는 설명이 필요해졌다).
      **마이그레이션 불필요** — 지구본은 아직 미출시(Unreleased) 기능이라 저장된 값을 가진
      사용자가 없다. `?? false` 로 전원 OFF 가 맞다.
      테스트 영향 없음: 기본값을 단정하는 테스트가 없다(`KeyboardSnapshotTests` 는 값을 저장·복원
      후 명시 대입, `FunctionRowWidthTests` 는 파라미터로 주입, `GlobeKeySwitchTests` 는
      `canSwitchInputMode` 만 본다). 그러므로 이 변경 후 테스트가 깨지면 **픽스처 갱신 대상이
      아니라 다른 문제의 신호**다.
- [ ] 리뷰 답변 문구(사용자가 앞뒤를 채울 한 줄):
      *"설정 → 키보드 → 크기·전환 키에서 '키보드 전환 키 표시'를 켜시면 기능 행 맨 왼쪽에
      지구본 키가 생겨 애플 기본 키보드 등으로 바로 전환할 수 있습니다."*
- [ ] (판단 필요) "이번 업데이트" 모달의 3개 슬롯 중 하나를 지구본이 계속 차지한다.
      기본 OFF + iOS 26 미표시라 대부분 사용자에게 무동작인데 안내는 남아 있다.
      문구는 "필요하면 켜세요"로 바꿔 뒀으나, 항목 자체를 뺄지는 사용자 결정 사항.

### 조사 워크플로 — **결과 수령 완료** (2026-08-10)
- [x] **설정 UX 재설계** + **입력 반응속도 근본 원인** 5개 렌즈 병렬 감사 (`wf_1789e35f-f0b`).
      결과를 **`docs/UX_AND_LATENCY_AUDIT.md` 에 저장했다** — 원본은 세션 임시 디렉토리에만
      있어 사라진다. 수령 직후 §0-1 검증 절차를 돌려 **작업트리 오염 없음**을 확인했다
      (실험 마커 0건, `trailingNoiseRatio` 0.4 유지, 수정 파일은 지구본 작업분뿐).
      내용: UX 진단 6가지 구조적 원인 + 9섹션 IA 재설계안, 반응속도 12건 우선순위 계획,
      미해결 질문 6건. **전부 정적 분석 기반 추정이고 Instruments 실측이 아니다.**
- [x] **반응속도 1~6·9 구현 완료** (2026-08-10, 커밋 `bb3b4dc`~`abe9a46`).
      항목별로 하나씩 적용 → 전체 테스트 → 커밋을 반복했다. 효과를 항목에 귀속시키려면
      이 순서를 유지할 것. 상세는 `docs/UX_AND_LATENCY_AUDIT.md` §2 진행 상황 표.
- [ ] **실측이 아직 없다.** 감사의 모든 수치는 정적 분석 추정이다. 미해결 질문 3번의 순서
      (os_signpost → Time Profiler → ㅛ/ㅠ/ㅢ 빠른 입력 재현)를 돌려야 "리뷰의 반응속도
      불만 = 렌더 병목" 인과가 확정된다. 실기기 익스텐션 프로파일링이 필요하다.
- [ ] **반응속도 7번은 손대지 말 것** — 감사가 유일하게 "인식률에 직접 닿는 경로"로 표시했고
      전제(임계값·섹터 폭이 제스처 중 불변)가 미검증이다. 10·11·12 는 미착수.
- [ ] 멀티스트로크 민감도 기본값 0→1 은 **보류**. 위 실측 후 판단해야 성능 개선 효과와
      구분된다. 지금 바꾸면 기존 사용자 전원의 입력 특성이 말없이 바뀐다.
- [ ] "KeyboardSettings 를 캐싱하자"는 **틀린 방향**(hot path 에 디스크 I/O 없음). 실제 비용은
      구조체 복사·Color 재생성·리렌더 횟수였고, 그건 위 1~6·9 로 처리했다.
      배경: 리뷰 "반응속도도 조금 느린것같긴해요"(돌양파), 설정이 많아지며 전달력 저하.

### 미착수 — 리뷰 기반 백로그
- [ ] 키보드 폭 축소 / 좌우·하단 여백 (나가방) — `KeyboardMetrics` 폭 계산 전반, 회귀 위험 큼
- [ ] 백스페이스를 최상단 행으로 (나가방)
- [ ] 세로 줄이고 남는 공간에 숫자열 (콩픈패스) — 높이 조절과 조합
- [ ] 특수문자 키패드 프리셋 커스터마이즈 (쪼꼬파이원츄) — 1.8.0 2페이지로 문자 부족은 해소, 편집 기능 미반영
- [ ] ㅐ 입력 방향이 순정과 다름 (호떡애비) — 임계가 아니라 매핑 스펙 결정 필요
- [ ] `viewWillDisappear` → `resetGestureState()` 범위 축소 검토 (§1-D)
- [ ] `SpecialCharSettingsView.swift:31` 문구가 **존재하지 않는 동작**을 설명한다 —
      "언어 변환 키(🌐)를 짧게 탭하면 특수문자 레이어가 열리고". 그런 동작은 없다.
      이 화면은 어디서도 도달할 수 없는 고아 화면이라 급하진 않으나, IA 재설계에서
      '특수문자 구성' 진입점으로 되살릴 때 내용을 반드시 다시 쓸 것
      (`docs/UX_AND_LATENCY_AUDIT.md` §1 참조).
      **주의**: `ContentView.swift:156`, `TypingPracticeView.swift:92`,
      `TutorialPracticeView.swift:88` 의 "🌐 버튼으로 전환"은 **시스템 키보드의 지구본**
      (애플 기본 키보드에서 모아+ 로 들어오는 경로)이라 우리 `showGlobeKey` 와 무관하고
      iOS 26 에서도 정확하다 — 감사 문서가 이 셋을 오류로 지목했으나 과잉 지적이다. 고치지 말 것.

### 릴리스 준비
- [ ] 버전 범프 (1.8.0/build 15 → 1.9.0/build 16)
- [ ] `docs/appstore/whats-new-next.md` 가 **1.7.2 기준으로 stale** — 갱신 필요
- [ ] 커밋/PR (`gh pr create --repo koh0001/moa-plus` — 이 저장소는 포크다)

---

## 5. 신규/변경 파일 지도

**신규**
- `docs/UX_AND_LATENCY_AUDIT.md` — 설정 UX 재설계안 + 반응속도 12건 계획 (워크플로 결과 보존)
- `MoaPlus/Settings/KeyboardSizeSettingsView.swift` — 높이 슬라이더 + 지구본 토글
- `MoaPlusKeyboardTests/GestureOverDetectionCharacterizationTests.swift` — 계측기 (§2)
- `MoaPlusKeyboardTests/FunctionRowWidthTests.swift` — 기능행 폭 합 불변식 (자식 추가 시 ⏎ 잘림 방지)
- `MoaPlusKeyboardTests/GlobeKeySwitchTests.swift` — 지구본 배선
- `MoaPlusKeyboardTests/BackgroundImageMemoryTests.swift` — 배경 이미지 메모리 상한

**엔진 변경 (주의해서 읽을 것)**
- `MoaPlusKeyboard/Engine/GestureAnalyzer.swift` — `strokeOriginPoint`, 후행 트림 재작성
- `MoaPlusKeyboard/ViewModels/KeyboardViewModel.swift` — `resolveConsonantDiagonalVowel` 게이트
- `MoaPlusKeyboard/Utilities/KeyboardSettings.swift` — 신규 옵션 3개
  (`keyboardHeightScale`, `showGlobeKey`, `consonantDiagonalDerivationEnabled`)
  → 새 옵션 추가 시 **Keys / @Published / loadAll / resetAll 4곳** 전부 필요 (CLAUDE.md 체크리스트)

`CLAUDE.md` 에 "순정 모아키 입력 스펙(기준)"과 "긋기 노이즈 처리" 절을 추가해 뒀다.
스펙을 바꾸려면 거기부터 볼 것.

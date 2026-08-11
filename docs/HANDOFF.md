# 작업 핸드오프

> 갱신: 2026-08-10 / 브랜치: `feat/symbol-pages-space-scroll` / **로컬 20 커밋, origin 에 미푸시**
> 워킹트리 클린. 직전 릴리스는 `b1fdbdb`(v1.8.0 문서화)이고 그 이후가 전부 이번 작업이다.
> 테스트: `MoaPlusKeyboardTests` 전체 통과 (`iPhone 17`).
> UI 테스트 `SettingsDiscoveryUITests` 8건 통과 (`iPhone 17 Pro`, CI 미편입).

---

## §0. 지금 할 일

### 1순위 — 순정 모아키 영상 판독 (사용자가 촬영해 옴)
사용자가 갤럭시에서 순정 모아키 입력을 녹화해 오기로 했다(2026-08-10 합의).
촬영 목록·설정은 **`docs/MOAKEY_RECORDING_GUIDE.md`** 에 있다.

받으면: `ffmpeg` 로 프레임 추출 → 궤적 판독 → `CLAUDE.md` 의 "순정 모아키 입력 스펙" 표와 대조
→ 차이 나는 항목을 `drivePath` 하니스(§3)로 재현·고정.

**영상에서 답을 얻으려는 핵심 두 가지:**
- **2차 입력의 방향 관대함** (가이드 D 섹션) — 사용자 관찰로는 순정이 후속 획 방향에 관대하다.
  우리는 후속 획에 **엄격**해서 "빨리 치면 인식 안 됨"이 나오고, **관대**하게 하면 손 떼며
  튕기는 꼬리를 획으로 먹어 '으'→'워'가 난다. 순정이 이 상충을 어떻게 푸는지가 최대 관심사다.
- **완성 글자 상태에서의 전이** (가이드 G 섹션) — `HangulComposer.complete` 이후 자음/모음
  입력을 순정이 어떻게 받는지(받침/새 글자/겹받침) 미확인이다.

**⚠️ 입력 스펙 관련 작업은 영상 수령 전까지 보류한다** — ㅐ 매핑(리뷰 호떡애비),
멀티스트로크 민감도 기본값 0→1, 긋기 임계 조정. 근거 없이 건드리면 되돌리기 어렵다.

판독 한계: 매핑 **규칙**은 영상으로 확정 가능하지만 **수치 임계값은 그대로 베낄 수 없다**
(좌표계·키 크기가 다름). 관찰은 규칙과 경향까지, 수치는 우리 엔진에서 재튜닝.

### 2순위 — 사용자 답변 대기 중인 결정
- [ ] **푸시 여부** — 로컬 20 커밋이 origin 에 없다. 이 핸드오프 문서 자체도 아직 로컬에만 있다.
      (이 브랜치 푸시만으로는 CI 가 돌지 않는다 — CI 는 fork main 으로의 PR 에서만 동작)
- [ ] **릴리스 범위** — 버전 범프(1.8.0/build 15 → 1.9.0/build 16),
      `docs/appstore/whats-new-next.md` 가 **1.7.2 기준으로 stale**, PR 생성
      (`gh pr create --repo koh0001/moa-plus` — 이 저장소는 포크다).
      영상 작업이 남아 있어 함께 묶을지 미정.
- [ ] "이번 업데이트" 모달의 3개 슬롯 중 하나를 지구본이 계속 차지한다. 기본 OFF + iOS 26
      미표시라 대부분 사용자에게 무동작인데 안내는 남아 있다. 문구는 "필요하면 켜세요"로
      바꿔 뒀으나 항목 자체를 뺄지는 제품 결정.
- [ ] 리뷰 답변 문구(사용자가 앞뒤를 채울 한 줄):
      *"설정 → 키보드 → 크기·전환 키에서 '키보드 전환 키 표시'를 켜시면 기능 행 맨 왼쪽에
      지구본 키가 생겨 애플 기본 키보드 등으로 바로 전환할 수 있습니다."*

### 3순위 — 근거가 없어 막혀 있는 것
- [ ] **반응속도 실측이 없다.** 감사의 모든 수치는 정적 분석 추정이다.
      `docs/UX_AND_LATENCY_AUDIT.md` 미해결 질문 3번의 순서(os_signpost → Time Profiler →
      ㅛ/ㅠ/ㅢ 빠른 입력 재현)를 돌려야 "리뷰의 반응속도 불만 = 렌더 병목" 인과가 확정된다.
      실기기 익스텐션 프로파일링이 필요하다.

---

## §1. 함정 — 먼저 읽을 것

### 1-1. 워크플로 에이전트가 작업트리를 수정했다 (실제 발생)
검증용 Workflow 에 프롬프트로만 "저장소 파일 수정 금지"라고 지시했는데 **지켜지지 않았다.**
`GestureAnalyzer.trailingNoiseRatio` 가 0.4 → 0.75 로 바뀌고(`// EXPERIMENT E4`),
특성화 하니스에 `swipeLength = .long` 이 주입됐다(`// E9`). 그 상태의 측정값으로 잘못된
결론("0.75가 우수")을 낼 뻔했다.

**규칙**: 코드를 만지는 Workflow 는 `isolation: "worktree"` 로 띄우고, 결과를 받으면
**해석 전에** 아래를 먼저 돌릴 것.
```bash
git status --short
grep -rn "EXPERIMENT\|// E[0-9]" --include="*.swift" MoaPlus MoaPlusKeyboard MoaPlusKeyboardTests
```

### 1-2. 테스트 결과를 잘못 읽는 두 가지 방법
- **`xcodebuild ... | tail` 금지.** zsh 파이프라인 exit code 는 `tail` 의 것이라
  **테스트 실패가 exit 0 으로 보인다.** 로그를 파일로 받고 `TEST SUCCEEDED` 를 직접 grep 할 것.
- **통과 개수로 판정하지 말 것.** 병렬 clone 출력이 서로 끼어들어 로그 줄이 잘린다
  (실제 사례: `Test case '...YoVowel()' p` 뒤에 다른 출력이 붙어 " passed" 가 사라짐).
  `grep -c` 카운트가 실제보다 적게 나온다. **`** TEST SUCCEEDED **` + 실패 0건**이 신뢰할 신호다.

### 1-3. 시뮬레이터에 앱을 띄우면 유닛 테스트가 깨진다
App Group UserDefaults 를 공유하므로 앱을 수동 실행한 시뮬레이터에서
`KeyboardViewModelVowelDragTests` 등이 결정적으로 실패한다.
**유닛 테스트 = `iPhone 17`, 앱 실행/UI 테스트 = `iPhone 17 Pro`** 분리를 유지할 것.
오염되면 `xcrun simctl shutdown <id> && xcrun simctl erase <id>`.

### 1-4. UI 테스트는 그냥 실행되지 않는다 (프로젝트 결함 2개)
`xcodebuild test` 로는 `MoaPlusUITests` 가 절대 돌지 않는다. 우회 2단계가 필요하다.
1. 스킴에서 `skipped = "YES"` → `-only-testing:` 으로 **우회되지 않는다**
   ("isn't a member of the specified test plan or scheme"). 임시로 `"NO"` 로 바꿔야 한다.
2. UITests 타겟의 `TEST_TARGET_NAME` 이 포크 이전 이름 `ios-moaki` 를 가리켜
   "UITargetAppPath should be provided" 로 죽는다. `TEST_TARGET_NAME=MoaPlus` 로 오버라이드.

실행 명령 전문은 `MoaPlusUITests /SettingsDiscoveryUITests.swift` 헤더 주석에 있다.
첫 실행이 `xctrunner` 런치 실패로 한 번 죽고 재시도에서 붙는 경우가 있다 — 케이스가 전부
passed 인데 최종 상태만 FAILED 면 그 상황이다.

### 1-5. iOS 26 은 검색 바를 화면 **아래**에 그린다
설정 검색창이 하단에 뜬다(시뮬레이터 실측). 안내 문구에서 **검색창 위치를 특정하지 말 것** —
실제로 "위쪽 검색창"이라고 썼다가 스크린샷 보고 고쳤다. 컴파일도 단언도 통과하는 종류의 오류다.

### 1-6. 시뮬레이터 키보드 활성화는 plist 편집으로 안 된다
`.GlobalPreferences` 의 `AppleKeyboards` 에 번들 ID 를 써넣으면 설정 앱 카운트만 늘고
**키보드 데몬은 인식하지 않는다.** 게다가 그 가짜 항목이 "새로운 키보드 추가" 목록에서
모아+ 를 숨겨 정식 추가를 막는다. 반드시 설정 UI 로 추가할 것.

### 1-7. 새 테스트 파일은 타겟 등록이 필요 없다
`PBXFileSystemSynchronizedRootGroup`(Xcode 16 폴더 동기화)이라 파일만 넣으면 잡힌다.
단 **UITests 폴더 이름은 `MoaPlusUITests ` — 끝에 공백이 있다.** 공백 없는 경로에 만들면 안 잡힌다.

---

## §2. 완료된 작업 (커밋 20개)

### A. 앱스토어 리뷰 대응 — 높이 조절 + 지구본 키 `426eeb2`
- `keyboardHeightScale`(0.85~1.35, 기본 1.0). 하한에서도 키 행이 38pt 아래로 안 가게 클램프.
- `showGlobeKey` **기본 OFF**. 켜면 스페이스바만 좁아진다.
- **iOS 26 아이폰에서는 우리 지구본이 표시되지 않는다**(실측). iOS 26 이 키보드 아래에
  시스템 지구본 바를 직접 그리며 이때 `needsInputModeSwitchKey == false` 를 반환하고,
  우리 지구본은 이 값에 게이팅돼 있다(중복 방지). 기본 OFF 인 이유이기도 하다.
- `FunctionRowWidthTests` 가 기능행 폭 합 불변식을 가드한다(자식 추가 시 ⏎ 잘림 방지).

### B. 순정 모아키 입력 방식 전환 `c87c0c3`
**조사 결론**: 자음 키 패턴 테이블(`VowelPattern.all`)은 **이미 순정과 100% 일치**했다.
불일치는 v1.7 에 추가한 `resolveConsonantDiagonalVowel` 하나뿐이었고 그게 리뷰 오타의 원인.

우리가 순정에서 벗어난 지점은 정확히 **"1차 입력이 대각선 + 2차 입력이 있을 때"** 다:

| 1차 입력 | 2차 이후 | 처리 | 순정과 |
|---|---|---|---|
| 카디널(↑↓←→) | 무엇이든 | `VowelPattern.all` 트라이 | 동일 |
| 대각선(↖↗↙↘) | 없음 | 트라이 (↗↖=ㅣ, ↙↘=ㅡ) | 동일 |
| 대각선 | **있음** | `resolveConsonantDiagonalVowel` | **우리 확장** |

`consonantDiagonalDerivationEnabled`(기본 false = 순정)로 게이팅. UI 는 `GestureSettingsView`
"입력 방식" Picker. 단독 대각선은 **클래식/확장형 레이아웃의 유일한 ㅣ/ㅡ 경로**라 절대 깨면
안 되고, 가드가 `test_moakeyDefault_pipeline_soloDiagonalsStillProduceBarAndDash` 다.

### C. 긋기 엔진 결함 2건 `4c4c46b`
1. 후행 노이즈 트림이 **인접(≤45°) 꼬리만** 제거하고 있었다. 실제 꼬리는 ↗(180°)·↑(135°)처럼
   급격한 쪽이 더 흔해 전부 빠져나갔다 — 의도와 정반대. → 절대 크기 + 직전 획 대비 비율 결합,
   꼬리가 여러 조각일 수 있어 `while` 반복 제거.
2. `directionMagnitudes` 가 획의 **실제 길이가 아니었다**. 임계를 넘는 순간의 변위만 기록해
   60pt 획도 임계값(≈20pt)으로 남았고, `normalizeSegments` 의 모든 비율 판정이 이 값을
   "직전 획 길이"로 전제하고 있었다. → `strokeOriginPoint` 도입.

### D. 메모리·생명주기 수정 `744d240`
"제미나이에서 사진 첨부 시 키보드 멈춤"(Geumji5) 리포트를 조사하다 발견한 **별개** 결함 2건.
**리포트의 확정 원인이 아니다 — 릴리스 노트에 "프리즈 수정"으로 쓰지 말 것.** 재현 실패했다.
- 배경 이미지가 원본 해상도로 디코딩됐다(12MP = ARGB 약 48MB, 익스텐션 한계 단독 초과).
  → 저장 시 긴 변 1536px + ImageIO 썸네일 디코딩.
- 키보드가 사라져도 백스페이스 반복 Timer 가 계속 돌았다 → `viewWillDisappear` 에서 정리.
  **단 `resetGestureState()` 를 통째로 부르므로 팝업 해제·약어 스토어 재로드까지 함께 일어난다.
  테스트 없는 생명주기 변경이라 범위 축소 여지 있음(§5).**

### E. 입력 반응속도 개선 7건 `bb3b4dc` `8ebd730` `ecf3b0e` `c3b0b36` `1e62a50` `03ee130` `abe9a46`
감사(`docs/UX_AND_LATENCY_AUDIT.md`) 1~6·9번. **항목 하나 적용 → 전체 테스트 → 커밋**을
반복했다. 효과를 항목에 귀속시키려면 이 순서를 유지할 것.
- 긋기 한 번에 키보드 전체가 ~24회 리렌더되던 것을 ~3회로(포워딩 setter 에 중복 발행 제거)
- 터치 포인트마다 4×7 레이아웃 배열을 새로 만들던 것을 제스처 시작 시 1회 조회로
- 렌더당 레이아웃 재구축 6→1회, 롱프레스 매핑 조회 O(n)→O(1), 키 색상 캐시
- `loadAll()` 이 무관한 설정까지 전부 재발행하던 것을 값이 바뀐 항목만 대입으로
- 죽은 `feedbackGenerator` 제거, `pow()` → 곱셈

**검증 상태: 커밋됨 + 테스트 통과. 실측 없음.** 체감 개선은 미확인이다(§0 3순위).
긋기 인식 동작은 안 바뀌었다(특성화 테스트로 확인).
`KeyboardSettingsCacheTests` `fedea21` 가 색상·인덱스 캐시의 무효화 배선을 고정한다 —
스냅샷 테스트는 정적 렌더 1회만 보므로 런타임 설정 변경 경로를 덮지 못한다.

### F. 설정 UX 1단계 — 검색 + 증상 라우터 `4796e16` `900cd53` `8bd10c8`
리뷰 7건 중 5건이 "기능이 없다"가 아니라 **있는 기능을 못 찾은** 경우였다.
- `SettingsCatalog` — 검색과 증상 라우터의 공용 카탈로그. `keywords` 에 **앱 용어가 아니라
  리뷰에서 관찰된 사용자 어휘**("진입앵글", 오타 표기 "지구봉" 포함)를 넣었다.
  **이게 이 기능의 핵심이므로 정리한답시고 앱 용어로 바꾸지 말 것.**
- 설정 루트 `.searchable`, 결과에 탐색 경로 표시. HelpView → 증상 라우터 8항목.
- "반응" → "소리 · 진동" 개명(네이밍 트랩: 내용은 사운드·햅틱뿐인데 "반응속도가 느리다"는
  사용자를 끌어들이고 있었다). 행 레이블과 화면 제목을 일치시켰다.
- 저장 키 변경·화면 이동 없음.

**검증 상태**: UI 테스트 8건 통과(iPhone 17 Pro) + 스크린샷 육안 확인.
**단 한글 IME 경로는 미검증** — `typeText` 는 IME 를 우회해 문자열을 직접 넣는다.
한글 검색은 **음절이 완성돼야** 걸린다(조합 중 자모는 `contains` 미스). 버그가 아니라
알려진 한계이며 `SettingsEntry.matches` 주석에 적어 뒀다. 초성 검색은 별도 기능.

---

## §3. 계측 도구 — 긋기를 건드리기 전에 익힐 것

`MoaPlusKeyboardTests/GestureOverDetectionCharacterizationTests.swift`

- **`drivePath(row:column:segments:stepsPerSegment:)`** — 다구간 폴리라인 하니스.
  기존 `driveKeyGesture` 는 단일 직선(dx/dy)만 가능해 꺾인 궤적을 **구조적으로 재현할 수 없었다.**
  영상 판독 결과를 테스트로 고정할 때 이걸 쓴다.
- 경로 × 민감도(0/1/2) 매트릭스를 `.xcresult` 첨부로 남긴다.

```bash
SS=/tmp/moa && mkdir -p $SS && cd $SS
xcodebuild test -project /Users/ockhyunkim/GitHub/moa-plus/MoaPlus.xcodeproj -scheme MoaPlus \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MoaPlusKeyboardTests/GestureOverDetectionCharacterizationTests/test_characterize_matrix_attachesReport \
  -resultBundlePath m.xcresult >/dev/null 2>&1
mkdir -p att && xcrun xcresulttool export attachments --path m.xcresult --output-path att
# att/manifest.json 에서 suggestedHumanReadableName 이 b1_gesture_matrix* 인 파일
```

**하니스 주의**: `withSensitivity` 안에서 `swipeLength` 같은 다른 설정을 바꾸면 모든 임계가
함께 스케일되어 측정 조건이 오염된다(§1-1 에서 실제 발생). 상수 비교는 **하나만** 바꿀 것.

---

## §4. 확정된 기준선 (기본 설정, `trailingNoiseRatio = 0.4`)

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
- 기본 민감도에서 ↙ 뒤 15~20pt 흔들림이 아직 **ㅢ** 로 승격. ㅢ 는 순정에도 있는 조합(↙↗)이라
  논리적으로 도달 가능하고 와/워 대비 경미하다.
- 진입 획이 짧을 때(30pt) 꼬리(18pt)가 그 61% 라 비율로도 노이즈 판정 불가 —
  의도적인 짧은 ㅢ 왕복과 구분되지 않는다.
- **더 좁히려면 등록 임계를 건드려야 하는데 그러면 "빨리 치면 인식 안 됨" 갈래가 악화된다.**
  이 트레이드오프를 모르고 임계를 낮추지 말 것. → 영상(§0)이 이 판단의 근거가 된다.

### `trailingNoiseRatio` 결론
0.4 와 0.75 를 하니스 고정 상태에서 비교한 결과 **37개 경로 전부 동일**(차이 0건).
`isTinyAbsolute && (isTinyRelative || isAdjacent)` 구조에서 절대 상한이 먼저 지배하기 때문이다.
근거가 없어 더 보수적인 **0.4 유지**.

---

## §5. 미착수 백로그

### 감사에서 나왔으나 손대지 않은 것
- [ ] **반응속도 7번은 손대지 말 것** — 감사가 유일하게 "인식률에 직접 닿는 경로"로 표시했고
      전제(임계값·섹터 폭이 제스처 중 불변)가 미검증이다. 10·11·12 도 미착수.
- [ ] "KeyboardSettings 를 캐싱하자"는 **틀린 방향**(hot path 에 디스크 I/O 없음).
      실제 비용은 구조체 복사·Color 재생성·리렌더 횟수였고 §2-E 로 처리했다.
- [ ] **전체 IA 재편(9섹션)** — 착수 전 **What's New 모달 버그를 먼저 고칠 것.**
      `ContentView.swift:104-113` 이 신규 설치자에게 `lastSeenWhatsNewVersion` 을 미리 찍어
      모달을 영구히 건너뛰게 한다. IA 를 바꾸면 "설정이 어디로 갔는지" 알릴 채널이 필요한데
      그 채널이 새고 있다. features 배열도 1.7.2 이후 갱신 안 됨.
- [ ] 키보드 내 설정 딥링크(`extensionContext.open`, Full Access 불필요) — 오타는 호스트 앱
      안에서 나는데 거기서 설정으로 가는 문이 없다(실사용 6탭).
- [ ] 4방향 모드에서 **무효인 컨트롤이 활성 상태로 남아 있다** —
      `GestureDirection.swift:72-86` 이 fourWay 분기에서 섹터 폭을 무시한다고 주석까지 달아뒀는데
      UI 는 슬라이더를 활성으로 보여준다. 같은 화면의 회전 보정은 실제로 동작하므로 둘을
      구분해 표시해야 한다. 4방향 토글 자체도 자신이 무력화하는 설정과 다른 화면에 있다.

### 테스트 인프라 (CI 미편입 — 사용자 결정)
- [ ] `MoaPlusTests` 타겟이 스킴에 없어 **메인 앱 유닛 테스트가 전혀 돌지 않는다.**
      `MoaPlusTests/ios_moakiTests.swift` 는 존재하지만 실행되지 않는다.
- [ ] `MoaPlusUITests` 의 `TEST_TARGET_NAME` 이 `ios-moaki`(§1-4). 고치려면 pbxproj 수정.
      **스킴만 활성화하고 이걸 안 고치면 CI 가 깨진다.**

### 리뷰 기반 백로그
- [ ] **ㅐ 입력 방향이 순정과 다름**(호떡애비) — 매핑 스펙 결정 필요. **영상 대기 중**(§0).
- [ ] 키보드 폭 축소 / 좌우·하단 여백(나가방) — `KeyboardMetrics` 폭 계산 전반, 회귀 위험 큼
- [ ] 백스페이스를 최상단 행으로(나가방)
- [ ] 세로 줄이고 남는 공간에 숫자열(콩픈패스) — 높이 조절과 조합
- [ ] 특수문자 키패드 프리셋 커스터마이즈(쪼꼬파이원츄) — 1.8.0 2페이지로 문자 부족은 해소,
      편집 기능 미반영
- [ ] `viewWillDisappear` → `resetGestureState()` 범위 축소 검토(§2-D)

### 문구 오류
- [ ] `SpecialCharSettingsView.swift:31` 이 **존재하지 않는 동작**을 설명한다 —
      "언어 변환 키(🌐)를 짧게 탭하면 특수문자 레이어가 열리고". 그런 동작은 없다.
      도달 불가능한 고아 화면이라 급하진 않으나, IA 재설계에서 '특수문자 구성' 진입점으로
      되살릴 때 반드시 다시 쓸 것.
- **고치지 말 것**: `ContentView.swift:156`, `TypingPracticeView.swift:92`,
  `TutorialPracticeView.swift:88` 의 "🌐 버튼으로 전환"은 **시스템 키보드의 지구본**
  (애플 기본 키보드에서 모아+ 로 들어오는 경로)이라 우리 `showGlobeKey` 와 무관하고
  iOS 26 에서도 정확하다. 감사 문서가 이 셋을 오류로 지목했으나 과잉 지적이다.

---

## §6. 파일 지도

### 이번 작업의 신규 파일
| 파일 | 용도 |
|---|---|
| `docs/MOAKEY_RECORDING_GUIDE.md` | **영상 촬영 목록** (§0 1순위) |
| `docs/UX_AND_LATENCY_AUDIT.md` | UX 재설계안 + 반응속도 12건 계획 (워크플로 결과 보존) |
| `MoaPlus/Settings/SettingsCatalog.swift` | 검색 인덱스 + 증상 라우터 공용 카탈로그 |
| `MoaPlus/Settings/KeyboardSizeSettingsView.swift` | 높이 슬라이더 + 지구본 토글 |
| `MoaPlusKeyboardTests/GestureOverDetectionCharacterizationTests.swift` | 긋기 계측기 (§3) |
| `MoaPlusKeyboardTests/KeyboardSettingsCacheTests.swift` | 파생 캐시 무효화 배선 |
| `MoaPlusKeyboardTests/FunctionRowWidthTests.swift` | 기능행 폭 합 불변식 |
| `MoaPlusKeyboardTests/GlobeKeySwitchTests.swift` | 지구본 배선 |
| `MoaPlusKeyboardTests/BackgroundImageMemoryTests.swift` | 배경 이미지 메모리 상한 |
| `MoaPlusUITests /SettingsDiscoveryUITests.swift` | 설정 검색·라우터 (CI 미편입, §1-4) |

### 주의해서 읽을 엔진 파일
- `MoaPlusKeyboard/Engine/GestureAnalyzer.swift` — `strokeOriginPoint`, 후행 트림 재작성
- `MoaPlusKeyboard/ViewModels/KeyboardViewModel.swift` — 순정 게이트, 제스처 상태 dedupe,
  `activeKeyContent` 캐시(수명 = 제스처 1회, `resetGestureState`/`dismissPopup` 이 비운다)
- `MoaPlusKeyboard/Utilities/KeyboardSettings.swift` — 신규 옵션 3개 + 파생 캐시 2개
  (색상 3종, 롱프레스 인덱스). 캐시 재빌드는 **`isLoading` 가드보다 앞**에 있어야 한다.
  → 새 옵션 추가 시 **Keys / @Published / loadAll / resetAll 4곳** 전부 필요 (CLAUDE.md 체크리스트)

`CLAUDE.md` 에 "순정 모아키 입력 스펙(기준)"과 "긋기 노이즈 처리" 절이 있다.
스펙을 바꾸려면 거기부터 볼 것.

# 작업 핸드오프

> 갱신: 2026-08-18 (5차, 햅틱 타이밍) / 브랜치: **`fix/haptic-on-press`** (main 에서 분기)
> **v2.1.1 (build 19) 준비 완료 — 아카이브/제출 전.**
> v2.1.0(18) 까지 main 머지 완료 (PR #21, #22).
> 테스트: `MoaPlusKeyboardTests` 전체 통과 (`iPhone 17`). §1-2 판독 규칙 준수할 것.
> **인증**: 이 저장소는 `koh0001` 전용 — 새 머신은 §1-7 먼저. gh 는
> `GH_TOKEN=$(gh auth token -u koh0001 -h github.com) gh ...` 로 실행할 것
> (활성 계정이 달라 `must be a collaborator` 가 난다 — 실제 발생).

---

## §0. 지금 할 일

### 상태: v2.1.1 (build 19) **커밋 완료, 아카이브 전** (2026-08-18)

GitHub 이슈 #23(mieung) — "글자를 누른 순간 햅틱이 오게 해주세요". 요청대로 햅틱을
입력 확정(손 뗄 때)에서 **터치 다운**으로 옮겼다.

- 긋기 키보드라 press→release 간격이 길어서, 확정 시점 진동은 구조적으로 늦게 체감된다
- 그리드 키는 `gestureStarted`, 슬롯B는 `slotBVowelGestureStarted` 가 `keyPressFeedback()` 호출
- 기능행 키(생성 지점 20곳 초과)는 `EnvironmentValues.keyPressFeedback` 으로 주입
- **입력 메서드에 햅틱을 되살리지 말 것** — 키 하나에 진동 두 번이 된다.
  백스페이스만 예외(`deleteBackward()` 안, 자동 반복 틱마다 울려야 함)
- `KeyboardViewModelHapticTimingTests` 6건이 이 규칙을 고정한다
- 설정 토글은 두지 않았다 (iOS 기본 키보드와 동일 동작, 설정 관리 대상만 늘어남)

**남은 일**
- [ ] Archive → 제출. 텍스트는 `docs/appstore/fields/04~08`
- [ ] 이슈 #23 회신 후 close
- [ ] 실기기 확인: 누름 진동이 한 번만 오는지, 백스페이스 길게 눌렀을 때 반복 진동이
      살아 있는지, 설정 미리보기 키보드가 조용한지

---

### 이전 상태: v2.1.0 (build 18) — main 머지 완료 (2026-08-16)

사용자 제보 3건(기호 트리거 미동작 / 띄어쓰기·기호 트리거 요청 / 확장 후 공백·되돌리기
문의)에서 출발한 단축어 개편. 실기기 확인까지 마쳤고 커밋은 브랜치에 있다.

- 설계 경위·결정 근거: `docs/ABBREVIATION_FEEDBACK_PLAN.md`
- 실기기 체크리스트: `docs/ABBREVIATION_DEVICE_CHECKLIST.md`
- 엔진 규칙 요약은 `CLAUDE.md` "약어(단축어) 트리거 매칭 규칙" 절에 박아 뒀다

**확정된 설계 결정** (되돌리기 전에 이유를 먼저 읽을 것 — 전부 근거가 있다)
- 트리거에 **공백은 불허**. 스페이스가 확정 신호를 겸하면 짧은 트리거가 긴 트리거를
  가로채고(`ㅋ` vs `ㅋ ㅋ`) 삭제 개수 규칙이 갈라진다. 오입력이 아니라 구조적 충돌이라
  설정으로도 풀지 않는다
- 접미 매칭은 **기호 포함 트리거로 한정**. 풀면 평범한 `ㅎㅌ` 가 "안녕ㅎㅌ" 끝에서 터진다
- 기호(`.` `,` `!` …)는 **여전히 확정 구분자**. 없애면 `ㄱㅅ.` 로 확정하던 기존 사용자가
  깨진다. 그 대가로 `ㅏ..` 뒤에 마침표를 더 찍으면 확장된다(의도된 절충, 테스트로 고정)
- 트리거 길이 제한은 **등록 UI 전용**. 엔진에 넣으면 이미 등록된 1글자 단축어가 죽는다

**남은 일**
- [ ] Xcode Archive → App Store Connect 제출. 붙여넣을 텍스트는
      `docs/appstore/fields/04~08` (마크다운 정리본 아님 — `.md` 를 붙여넣으면 줄바꿈이 깨진다)
- [ ] 제보자 회신 — 초안은 `ABBREVIATION_FEEDBACK_PLAN.md` §7
- [ ] 이 브랜치 PR. **PR #21(v2.0) 이 먼저 머지되어야 diff 가 깨끗하다** — 이 브랜치는
      `feat/v2-moakey-parity` 위에 쌓여 있다

---

### 이전 상태: v2.0.0 (build 17) **배포 제출 완료** (2026-08-14)
사용자가 이 브랜치 빌드로 Archive → App Store Connect 제출까지 마쳤다 (심사 대기).
실기기 체크리스트 전 항목 실측 반영 + adb 정밀 측정 4건 종결 + 잔여 오타 2회
반복 수정(실기기 확인: 외+ㆍ=와 ✓, 모서리 흡수 ✓). 유닛 테스트 408건 통과.
이번 세션 상세는 `CHANGELOG.md` build 17 섹션과 `MOAKEY_VIDEO_FINDINGS.md`
§C-2/C-3 참조.

### 1순위 — 릴리스 후속
- [ ] **PR #21 머지** (https://github.com/koh0001/moa-plus/pull/21) — CI 통과
      상태(`Build and Test` 5m31s)로 열려 있다. 제출된 빌드가 이 브랜치에서
      나갔으므로 심사와 무관하게 머지해 main 을 릴리스 상태로 맞출 것.
      주의: gh 활성 계정이 업무 계정이라 이 저장소 gh 작업은
      `GH_TOKEN=$(gh auth token -u koh0001 -h github.com) gh ...` 로 실행 (§1-7).
- [ ] 심사 리젝 대응 대기. 통과 후: 사용자 오타 리포트 채널 모니터링 —
      v2.0 부터 **입력 기록 보드 리포트**(메일 koh0001@outlook.kr / GitHub 이슈)에
      획별 계측·설정 요약이 담겨 온다. 리포트가 오면 raw/fin 획 수치로
      임계(GestureSettings)·트림(GestureAnalyzer) 재조정 판단.
- [ ] 출시 후 문서 정리 (1.7.2 때의 `dc41599` 패턴): README·사이트 스펙 갱신.

### 2순위 — 다음 개선 후보 (근거 있는 것부터)
- [ ] **반응속도 실측이 없다.** 감사의 모든 수치는 정적 분석 추정이다.
      `docs/UX_AND_LATENCY_AUDIT.md` 미해결 질문 3번의 순서(os_signpost → Time Profiler →
      ㅛ/ㅠ/ㅢ 빠른 입력 재현)를 돌려야 "리뷰의 반응속도 불만 = 렌더 병목" 인과가 확정된다.
      실기기 익스텐션 프로파일링이 필요하다.
- [ ] **멀티스트로크 민감도 기본값 0→1** — 영상 판독으로 근거가 생겼다(순정은 속도 거부
      없음 + 반전 임계 실측 정합). 실사용 리포트 쌓인 뒤 판단.
- [ ] adb 측정 기법 재사용 메모: 갤럭시 USB + `adb shell "input motionevent DOWN … MOVE … UP"`
      체인(속도 무관·타임아웃 없음), 결과는 screencap 크롭 판독. 순정 경계 재측정이
      필요해지면 이 세션 방식 그대로 (`MOAKEY_VIDEO_FINDINGS.md` §C-3).

나머지 미착수 항목은 §5 백로그 참조 (IA 재편, 설정 딥링크, 4방향 UI 정리,
상하 줄 이동 재시도 기록 등).

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

### 1-7. 이 저장소는 `koh0001` 계정 전용이다 (다른 머신에서 클론하면 재설정 필요)
사용자는 GitHub 계정을 용도별로 나눠 쓴다 — **이 프로젝트 = `koh0001`, 업무 = 별도 계정.**
`git config --local` 은 **클론을 따라가지 않으므로** 새 머신에서는 아래를 다시 해야 한다.

```bash
git config --local user.name koh0001
git config --local user.email "29946122+koh0001@users.noreply.github.com"
git remote set-url origin https://koh0001@github.com/koh0001/moa-plus.git
# gh helper 는 "활성 계정"만 지원해 다른 계정을 요청하면 빈 응답을 준다.
# 그래서 이 저장소에서만 gh helper 를 끄고 osxkeychain 을 쓴다.
git config --local --replace-all "credential.https://github.com.helper" ""
git config --local --add "credential.https://github.com.helper" osxkeychain
TOKEN=$(gh auth token -u koh0001 -h github.com)
printf 'protocol=https\nhost=github.com\nusername=koh0001\npassword=%s\n\n' "$TOKEN" \
  | git credential-osxkeychain store
unset TOKEN
```

**증상**: 이 설정이 없으면 `git push` 가 `403 Permission denied` 로 죽는다
(전역 활성 계정이 `koh0001` 이 아니기 때문). `gh auth switch` 로 전역을 바꾸는 방법도
있지만 그러면 업무 저장소 작업이 영향을 받으므로 위 저장소별 고정을 쓸 것.
검증은 `git push --dry-run origin <branch>` — 인증이 통과하면 `Everything up-to-date`.

> 커밋 `beb3911` 까지 21개는 author 가 `ockhyun-kim` 으로 올라가 있다(설정 이전).
> 되돌리지 않았다 — 이미 푸시됐고 기능상 문제가 없다. 이후 커밋부터 `koh0001` 이다.

### 1-8. 새 테스트 파일은 타겟 등록이 필요 없다
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

### G. v2.0 순정 모아키 실측 정합화 `d4baf27`…`c22a95d` (이 브랜치, 2026-08-13)
**§0 구 1순위(영상 판독)가 완료됐다.** 관찰 영상 47편(기본 40 + 재촬영 R1~R7)을 병렬
판독 에이전트 13개로 프레임 판독 → 순정 규칙 확정 → 엔진·앱 반영. 판독 전문과 근거는
**`docs/MOAKEY_VIDEO_FINDINGS.md`** (이후 스펙 논쟁은 여기가 1차 근거다).

커밋 6개 (순서 = 의존 순서, 각 시점 테스트 그린):
1. `d4baf27` 확장형 모음 키 라벨 ㅣㆍㅡ/모음
2. `935ca3a` composer — ㆍ 토글(ㅛ↔ㅗ, ㅠ↔ㅜ) + **자소 단위 백스페이스(가→ㄱ)**
3. `ef765bc` gesture — **첫 획 재해석 2-pass**(↗↙=ㅐ 등, 동률=기존 해석으로 ㅢ 보존,
   두 번째 획 0.6×keyWidth 게이트), 수평 시작 직각 스냅(→↓=ㅐ), 트라이 간선 7개
   (↑↓→=ㅘ, ↑↓←→=ㅖ, ↑↓↑↓=ㅠ 등), `MoakeyVideoVerifiedSpecTests` 신규
4. `498cac5` 앱 — 튜토리얼 3단계 재작성(구 단계는 기본 OFF 기능을 가르쳤음),
   6단계 ㅞ 표기 오류(↓→←→↓←→) 수정, 연습 34번 교체, 설정 문구·검색 키워드
5. `ccc2b4e` docs — FINDINGS/RESHOOT/체크리스트 + CLAUDE.md·README 스펙 갱신
6. `c22a95d` release — 2.0.0(16), CHANGELOG, 앱스토어 릴리스 노트

**구 1순위의 핵심 질문 두 개에 대한 답** (상세는 FINDINGS):
- 2차 입력 관대함의 정체 = 순정은 "첫 획 8방향 잠정 → 후속 획 도착 시 4방향 재해석" +
  획 방향은 net 변위로만 판정(꼬리 레버리지 없음) + 최소 획 길이 문턱(키폭 ~30%).
  속도·타임아웃 거부는 아예 없다.
- 완성 글자 전이 = 우리 `HangulComposer` 가 이미 순정과 일치(받침 결합/이월/겹받침 분해).
  다른 건 백스페이스 단위(자소)와 ㆍ 토글뿐이었고 반영 완료.

**리뷰 "ㅐ 방향이 순정과 다름"(호떡애비)은 이걸로 해소** — 순정 사용자의 ㅐ 입력 2/3가
↗ 왕복 경로였고(C 섹션), 우리는 그 경로가 ㅣ로 끝났었다.

⚠️ 판독 함정(재판독 시): ㅢ↔ㅣ, ㅟ↔ㅝ 는 6배+ 확대 필수 / 조합 밑줄이 단독 자모를
"브"처럼 보이게 함 / 일부 영상 timebase 깨져 `-ss` 시크 금지(`fps=` 필터로 일괄 추출) /
1차 판독의 ㅝ↔ㅟ "얕은 각=ㅟ" 2건은 좌표 바 없던 시절 오독으로 **기각**됨(R1).

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
- [ ] **스페이스 드래그 상하 줄 이동 — 시도 후 롤백 (2026-08-14, 재시도 시 필독)**:
      순정 영상(spacebar Drag.mp4) 실측으로 구현했으나 사용자 판정 "순정과 동일하게
      안 되니 오히려 어색"으로 롤백 (`6442f66`+`870eccf` revert). 기술 기록:
      ① iOS 프록시 컨텍스트는 문단 경계에서 잘려 `\n` 이 없다 — "줄바꿈 찾기"는
      항상 no-op. ② 유일하게 동작한 방식은 2단계 착지(before.count=현재 열 →
      -(열+1) 로 이전 줄 끝 착지 → ~80ms 후 컨텍스트 갱신 뒤 열 복원)인데,
      착지→보정의 시차와 소프트랩 미감지가 체감 어색함의 원인. 재시도하려면
      UITextInteraction 계열이 아니라 이 시차를 숨길 UI(커서 이동 중 표시)가 필요.
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
- [x] ~~**ㅐ 입력 방향이 순정과 다름**(호떡애비)~~ — **v2.0 에서 해소** (§2-G, 대각선 왕복 ㅐ).
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
| `docs/MOAKEY_VIDEO_FINDINGS.md` | **순정 실측 판독 결과 종합** — 스펙 논쟁의 1차 근거 (§2-G) |
| `docs/MOAKEY_RESHOOT_LIST.md` | 남은 촬영 3건(S1~S3, 저우선) + 완료 이력 |
| `docs/V2_DEVICE_TEST_CHECKLIST.md` | **실기기 실측 체크리스트** (§0 1순위) |
| `MoaPlusKeyboardTests/MoakeyVideoVerifiedSpecTests.swift` | 영상 근거 순정 스펙 가드 30여 케이스 |
| `docs/MOAKEY_RECORDING_GUIDE.md` | 영상 촬영 가이드 (1차 촬영 완료) |
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

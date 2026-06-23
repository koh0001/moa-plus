# 사용자 피드백 작업 핸드오프

> 작성: 2026-06-23 / 브랜치: `ci/cli-test-and-actions`
> 사용자 피드백 6건을 6개 태스크(T1~T6)로 분석. 우선순위 순서대로 착수 중.

## 현재 상태

**완료(커밋됨): 4방향 전용 모드 (T2+T3+T1 일부) + 레이아웃 호환 + 레이아웃 미리보기 통일** — TDD, 실기기 확인 완료.
**완료: T4 멀티스트로크 민감도** — `GestureSettings.multiStrokeTurnSensitivity`(0~2, 기본 0=기존 동등) + `angularGap`/`qualifiesAsTurn`/`turnRegistrationThreshold` 차등 임계 + **진폭 비율 가드**(ㅗㅜㅏㅓ→ㅚㅛㅐㅑ 과승격 차단). 긋기 설정에 민감도 Picker + ㅣ/ㅡ키 안내. TDD 5종, clean 빌드 26/26.
**완료(커밋됨): T5 자음 힌트 깜빡임 제거** — `isGestureActive` 전역 플래그를 키별 `isActive`로 좁힘
([ConsonantGridView](../MoaPlusKeyboard/Views/ConsonantGridView.swift), [KeyboardView](../MoaPlusKeyboard/Views/KeyboardView.swift)). 빌드 통과, 실기기 확인 예정.

T5 근본 원인: 타이핑 시 `gestureState.activeKey` 변경 → 전역 `isGestureActive`가 28개 키 전체에 전파 →
모든 키 hint `opacity(isGestureActive ? 0 : 1)` 토글 → 깜빡임. 키별 active 판정으로 누른 키만 숨김.

### 4방향 모드 × 레이아웃(slotA) 상호작용 — ㅣ/ㅡ 입력 (중요)
레이아웃마다 ㅣ/ㅡ 입력 경로가 다르다 ([KeyboardMetrics.koreanLayout(_:)](../MoaPlusKeyboard/Utilities/KeyboardMetrics.swift:184)):
- **모던/기본 (.vowel)**: ㅣ/ㅡ 전용 키(.bar row2col6, .dash row3col5) → 탭으로 입력 → **4방향 OK** (테스트 검증).
  ㅣ/ㅡ 키 긋기(ㅕㅑㅗㅜ 등)도 카디널 기반이라 4방향에서 정상.
- **클래식 (.classic11)**: ㅣ/ㅡ 전용 키 없음. 자음 키 대각선 긋기(↗ㅣ ↘ㅡ)에 의존 → **4방향에서 ㅣ/ㅡ 막힘**.
- **확장형 (.fullPackage)**: `.slotBVowelKey` 사용, 긋기는 `vowelResolver.resolve` → ↗ㅣ ↘ㅡ 대각선 의존 → **4방향에서 ㅣ/ㅡ 막힘**.
- 증명 테스트: `KeyboardViewModelVowelDragTests`의 `test_fourWay_slotBUpRightDrag_cannotYieldBar` 등.

**해결(구현됨, 사용자 결정 2026-06-23):**
- 4방향 토글을 **레이아웃 설정의 모던 옵션 하위로 이동** ([LayoutCustomizationView](../MoaPlus/Settings/LayoutCustomizationView.swift)).
  모던(.vowel) 선택 시에만 토글 노출(`fourWayModeBinding`).
- 비모던(클래식/확장형) 레이아웃 선택 시 `fourWayMode` **자동 OFF** (`slotARadioRow` action) — 조용한 깨짐 차단.
- [GestureSettingsView](../MoaPlus/Settings/GestureSettingsView.swift)에서 4방향 토글·권장 알럿 제거.
  단 `fourWayMode==true`면 프리셋/방향 설정은 `.disabled` 유지 + `swipeModeDescription`에 안내.
- 미해결로 남긴 대안: ↗↘ 대각선만 살리는 하이브리드(채택 안 함).

### 레이아웃 설정 미리보기 — 모든 레이아웃 드래그 미리보기 (구현됨)
- 기존: 확장형/slotB vowelKey 에서만 미리보기 터치 활성(`isVowelKeyAvailable`), 모던·클래식은 입력 불가.
- 변경: [LayoutCustomizationView](../MoaPlus/Settings/LayoutCustomizationView.swift)에 `onConsonantPreview` 추가 →
  모든 레이아웃에서 자음/ㅣ·ㅡ 키 드래그 시 결과 모음 버블 표시(실제 입력 X, previewMode 유지).
  `.moved` 단계 vowel 사용(vowelPrimitive 정확도). `isVowelKeyAvailable` 제거.

### 핵심 발견 (재방문 시 반드시 인지)
- 피드백 1의 "각도 변경했는데 테스트에서 적용 안 됨"은 **저장/동기화 버그가 아님**.
- 진짜 원인: `GestureDirection.from`이 **대각선 섹터(↗↖↙↘)를 카디널(↑↓←→)보다 항상 먼저 검사**
  ([GestureDirection.swift:67](../MoaPlusKeyboard/Models/GestureDirection.swift)).
  → ㅗ/ㅜ 카디널 halfWidth를 넓혀도 인접 대각선과 겹치는 영역은 대각선이 가로채 효과가 없음.
- 4방향 모드는 대각선을 끄고 카디널을 90°(±45°)로 고정 → 이 구조적 한계를 우회.
- 저장 경로 자체는 정상: `SectorAngleView` 슬라이더 → `swipeProfile.sectors[i].halfWidth` 즉시 저장,
  production은 매 제스처 시작 시 `KeyboardSettings.shared.gestureSettings` 재読み込み.

## 실기기 테스트 체크리스트 (사용자 진행 중)

`Cmd+R` 빌드 → 설정 → 긋기 입력 설정:
- [ ] "4방향 전용 모드" 토글 ON → 아래 프리셋/방향 설정 섹션이 비활성(흐려짐) 되는지
- [ ] "긋기 실시간 테스트" 진입 → 캔버스가 4분면(상하좌우)으로 그려지는지
- [ ] 4방향 ON 상태에서 ㅗ/ㅜ/ㅏ/ㅓ 단일 긋기 — 살짝 비스듬해도 안정적으로 인식되는지
- [ ] ㅑㅕㅛㅠ, ㅘ 등 멀티스트로크가 4방향 ON에서도 정상 입력되는지
- [ ] 토글 OFF 시 기존 8방향 동작 그대로인지(회귀 없음)
- [ ] 기존 사용자 설정(앱 업데이트 시나리오) 유지 여부 — 디코더 호환 단위테스트로는 통과

## 남은 태스크 (우선순위 순)

### ~~T5. 자음 힌트 문자 깜빡임 제거~~ ✅ 완료 — 피드백 5
- `isGestureActive` 전역 플래그를 KeyGridView 에서 키별 `isActive`로 전달하도록 변경
  ([ConsonantGridView:158](../MoaPlusKeyboard/Views/ConsonantGridView.swift), prop 제거 + [KeyboardView](../MoaPlusKeyboard/Views/KeyboardView.swift) 호출 정리).
- `viewModel.activeKey` == `gestureState.activeKey`(forward) 확인 → 키별 판정으로 동작 보존.

### ~~T4. 멀티스트로크 모음 ⚡️ 인식~~ ✅ 완료 — 피드백 2, 6
- 보수적 완화(옵션 C 변형) + 사용자 민감도 설정 + 진폭 가드. sens 0 회귀 0. 상세는 위 현재 상태 참조.
- 워크플로 분석으로 "⚡️ 완화 = ㅗㅜㅏㅓ 과승격" trade-off 사전 발견 → 진폭 비율 가드로 대응.

### T4(원본 분석 메모). 멀티스트로크 모음 — 피드백 2, 6
- 원인: `GestureAnalyzer`가 방향 벡터를 **터치 시작점이 아닌 `lastDirectionChangePoint`(직전 꺾인 점)
  기준**으로 계산 ([GestureAnalyzer.swift:136-141](../MoaPlusKeyboard/Engine/GestureAnalyzer.swift)).
  → ㅛ(↑↓↑)가 정확한 N자 궤적(원점 복귀)을 요구.
- 접근: 방향 전환 판정을 "절대 변위" → "직전 방향 대비 각도 변화"로 전환. ⚡️ 궤적 허용.
- 회귀 위험 최대 → **TDD 필수**. 기존 `testTripleReversalForYoVowel` 등과의 호환 유지하며 확장.
- 4방향 모드 작업으로 ㅣ 오인식(피드백6)은 부분 완화됐을 수 있음 — 재현 재확인 후 범위 조정.

### T6. 아이패드 레이아웃 (높이 + 가로 좌우 분리) `[대]` — 피드백 4  ← **다음 차례**
- 현황: 높이 260pt 완전 고정, iPad/orientation 감지 코드 없음
  ([KeyboardMetrics.swift:59](../MoaPlusKeyboard/Utilities/KeyboardMetrics.swift),
  [KeyboardViewController.swift:37-54](../MoaPlusKeyboard/KeyboardViewController.swift)).
- 접근: `userInterfaceIdiom`/orientation 기반 동적 높이 + iPad 가로 전용 레이아웃(좌=숫자, 우=모아키).

### T1 잔여. 8방향 유지하며 좌/우 각도 독립 조절 — 피드백 1, 6
- 4방향 모드로 우회됨. 8방향을 쓰면서 ㅗ/ㅜ 좌우를 따로 넓히길 원하면:
  `DirectionSector.halfWidth`를 `leftHalfWidth`/`rightHalfWidth`로 분리 + 디코더 호환.
- 사용자가 4방향에 만족하면 생략 가능.

## 빌드 / 테스트 명령

```bash
# 키보드 단위 테스트 (메인앱 컴파일 포함)
xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MoaPlusKeyboardTests

# 특정 테스트 클래스만
xcodebuild test ... -only-testing:MoaPlusKeyboardTests/GestureAnalyzerTests
```
로컬 가용 시뮬레이터: iPhone 17 / 17 Pro / 17 Pro Max / 17e (모두 사용 가능 확인됨).

## 주의사항 (CLAUDE.md 발췌, 이 작업 관련)
- `KeyboardSettings.load(...) ?? .default` — Codable 디코딩 실패 시 **전체 설정 리셋**.
  새 필드 추가 시 반드시 `decodeIfPresent` 커스텀 디코더 동반 (SwipeProfile에 적용한 패턴 참고).
- enum 새 케이스 추가 시 모든 exhaustive switch 점검.
- 익스텐션 핵심 파일은 메인 앱 타겟에도 멤버십 추가 (`scripts/add_target_membership.rb`).
  단 이번 변경은 기존 멤버십 파일 수정뿐이라 추가 불필요.

# 설계 — OpenMoa 오류 허용 모음 상태기계 이식

> 작성 2026-06-24. brainstorming 승인 완료. 다음 단계: writing-plans.

## 1. 배경 / 문제

현재 자음·모음 키 제스처의 모음 인식은 `VowelPattern.PatternTrie`의 **엄격한 시퀀스 매칭**이다 (`MoaPlusKeyboard/Models/VowelPattern.swift`, `Engine/VowelResolver.swift`).

- trie `match()`는 방향 시퀀스를 순회하다 자식 노드가 없으면 `break`하고 그때까지의 마지막 완성 모음만 반환한다 (`VowelPattern.swift:94`).
- 결과: 1차 입력 후 2·3차 stroke가 패턴에 **정확히** 맞지 않으면 그 stroke가 버려지고 입력이 무효화된다.
- 영향이 큰 모음: **ㅢ**(ㅡ→ㅣ, 2차 ㅣ를 정확히 그어야), **ㅛ/ㅠ**(↑↓↑ / ↓↑↓ 3단계 — 중간 반전 stroke가 조금만 어긋나도 실패), 그 외 다단계 복합모음.

원본 모아키(검증 레퍼런스: 오픈소스 **OpenMoa** `github.com/AiOO/OpenMoa`)는 다르게 동작한다:

- `MoeumGestureProcessor.resolveMoeumList()`의 모든 상태 전이에 `else -> moeum`이 있어 **매칭되지 않는 stroke는 무시하고 현재 상태를 유지**한 채 다음 유효 입력으로 진행한다.
- `// non-strict` 분기로 **인접/유사 방향도 관대하게 수용**한다 (예: ㅏ 상태에서 ㅓ뿐 아니라 ㅗ·ㅜ·ㅡL·ㅣL도 ㅐ로).

즉 OpenMoa는 "오류 허용(error-tolerant)" 상태기계라 다단계 모음 입력 난이도가 낮다. 이 동작을 iOS에 이식해 ㅛ·ㅠ·ㅢ 등의 입력 성공률을 높이는 것이 목표다.

## 2. 목표 / 비목표

**목표**
- 모음 제스처 인식을 OpenMoa `MoeumGestureProcessor` 상태기계로 교체해 오류 허용 + non-strict 동작을 얻는다.
- 정확히 그은 입력의 **결과는 현재와 동일**하게 유지한다(아래 §4 참조 — 매핑표가 이미 동일).

**비목표 (YAGNI)**
- 진입 대각선 좌/우 구별(ㅣ우 vs ㅣ좌)을 결과에 반영 — OpenMoa도 최종 `substring(0,1)`로 첫 글자만 취해 결과에 영향 없음. 내부 중간상태로만 사용.
- 사용자 원래(갤럭시 관찰) 명세 — OpenMoa 규칙으로 대체하기로 확정됨.
- 천지인 누적(`HangulComposer.combineVowels`), 약어, 모드 전환 등 기존 로직 변경.

## 3. 현재 상태 (확정)

`VowelResolver`/`VowelPattern` trie는 **이미 OpenMoa 매핑표 21개를 정확 입력 기준으로 구현**하고 있다. 검증 결과:

| 분류 | 현재 = OpenMoa |
|---|---|
| 대각선 단독 | ↗↖=ㅣ, ↙↘=ㅡ |
| 카디널 단독 | →ㅏ ←ㅓ ↑ㅗ ↓ㅜ |
| 카디널 복합 | →←=ㅐ ←→=ㅔ ↑→=ㅘ ↓←=ㅝ ↑↓=ㅚ ↓↑=ㅟ ↑→←=ㅙ ↓←→=ㅞ |
| Y계열 | →←→=ㅑ ←→←=ㅕ ↑↓↑=ㅛ ↓↑↓=ㅠ →←→←=ㅒ ←→←→=ㅖ |
| ㅢ | ↘↖ / ↘↑ / ↙↗ |

**차이는 매핑이 아니라 허용도뿐이다.** 따라서 이식의 본질은 "엄격 trie → 오류 허용 상태기계" 교체이며, 정확 입력 결과는 보존된다.

## 4. 설계

### 4.1 8방향 → 모음 프리미티브

`GestureDirection`(8방향)을 OpenMoa 프리미티브 문자열로 매핑 (`JaumKeyTouchListener.kt:38-48` 동치):

| GestureDirection | 프리미티브 |
|---|---|
| `.right` | `ㅏ` |
| `.left` | `ㅓ` |
| `.up` | `ㅗ` |
| `.down` | `ㅜ` |
| `.upRight` | `ㅣR` |
| `.upLeft` | `ㅣL` |
| `.downRight` | `ㅡR` |
| `.downLeft` | `ㅡL` |

### 4.2 상태기계 (핵심)

OpenMoa `MoeumGestureProcessor.resolveMoeumList()`를 충실히 포팅한다. 핵심 성질:

1. `moeum` 상태 + `nextMoeum` 입력 → 다음 상태 (전이표는 `MoeumGestureProcessor.kt:18-159` 그대로).
2. 모든 `when`에 **`else -> moeum`(상태 유지)** — 무관한 stroke 무시 후 진행. **이것이 오류 허용의 핵심.**
3. `// non-strict` 분기 — 인접/유사 방향 수용.
4. 중간상태(`ㅡLㅓ`, `ㅣRㅗ` 등) 관리.
5. 최종 결과 = 상태 문자열의 첫 글자(`substring(0,1)`). 미입력이면 nil.

iOS 이식 형태: 새 타입(예: `MoeumGestureResolver`)에 OpenMoa 전이표를 그대로 옮긴다. 상태는 문자열 키로 관리(OpenMoa와 동일)하고 최종에 `Jungseong`으로 변환하거나, 동치의 Swift enum으로 표현한다(구현 plan에서 결정).

### 4.3 적용 범위

`VowelResolver`가 쓰이는 **모든 모음 제스처 경로**를 새 상태기계로 통일한다:
- 자음 키 제스처 (`KeyboardViewModel.handleKoreanModeGesture`)
- slot B 모음 키 (`vowelResolver.resolve`)
- ㅣ/ㅡ 전용 키 (`resolveVowelFromPrimitiveDrag`) — primitive(.bar/.dash)가 시작 상태로 고정되는 형태로 동일 상태기계 사용

`peekVowel`(실시간 미리보기), `hasPotentialMatch`도 동일 상태기계 기반으로 재구현한다.

### 4.4 GestureAnalyzer

`GestureAnalyzer`는 변경하지 않는다 — 8방향 시퀀스(`[GestureDirection]`)를 그대로 생성하고, 오류 허용은 상태기계가 담당한다. 다단계 모음에서 중간 stroke를 GestureAnalyzer가 누락/과인식하는 별개 문제는 실기기 QA에서 임계값 튜닝으로 다룬다(이 spec 범위 밖, 리스크에 기록).

## 5. 회귀 안전성

- **정확 입력 결과 불변**: 매핑표가 동일하므로 기존 21개 모음의 정확 제스처는 같은 결과를 낸다.
- 기존 테스트 유지: `VowelResolverTests`, `KeyboardViewModelVowelDragTests`, `GestureAnalyzerTests`, `KeyboardViewModel* `.
- `VowelPattern`/`PatternTrie`는 새 상태기계가 대체하면 제거 또는 보존(시각화/테스트 참조 여부에 따라 plan에서 결정).

## 6. 엣지케이스

- **좌우 프리미티브(ㅣR/ㅣL, ㅡR/ㅡL)**: 중간상태 전이에만 쓰이고 최종 `substring(0,1)`로 사라짐 — 결과 영향 없음.
- **단독 대각선**: ㅣR/ㅣL → ㅣ, ㅡR/ㅡL → ㅡ (현재와 동일).
- **빈 입력(탭)**: directions 없음 → nil → 천지인 ㆍ 등 기존 탭 경로 유지.
- **3단계 이상**: 상태기계가 stroke를 순차 소비하므로 ㅛ(ㅗ→ㅚ→ㅛ), ㅠ(ㅜ→ㅟ→ㅠ)가 중간 오류를 흡수.

## 7. 테스트 전략

- 단위: 새 상태기계에 OpenMoa `MoeumGestureProcessorTest.kt`의 케이스 + 21개 모음 정확 입력 + **오류 허용 케이스**(중간에 무관 stroke 삽입 시 무시되고 목표 모음 도달) + non-strict 케이스.
- 통합: `driveKeyGesture`류로 자음 키/모음 키 합성 점열 → 모음 (실기기 촘촘 터치 근사).
- 회귀: 기존 전 테스트 통과.

## 8. 리스크

- 엔진 핵심(모음 인식) 교체 — 전수 회귀 검증 필수.
- 메인앱 타겟 빌드 포함 검증 필요(`build-for-testing -scheme MoaPlus`) — `-only-testing`은 메인앱 미빌드.
- GestureAnalyzer의 중간 stroke 인식 정확도가 상태기계 입력 품질을 좌우 — 실기기에서 다단계 모음(ㅛㅠ) 임계값 튜닝이 별도로 필요할 수 있음.

## 9. 결정 로그

- 입력 방식: 한 번의 연속 긋기(방향 시퀀스). 확정.
- 진입 대각선 좌우 구별: 결과 미반영(내부 중간상태만). 확정.
- 레퍼런스: OpenMoa 소스(오픈소스 모아키). 사용자 원래 명세 대체. 확정.
- 적용 범위: VowelResolver를 쓰는 모든 모음 경로 통일. 확정.

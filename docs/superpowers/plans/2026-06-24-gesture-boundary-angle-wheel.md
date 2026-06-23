# 긋기 8방향 좌/우 각도 — per-side 폭 + 하이브리드 파이 UI (v2, autoplan 반영)

> 작성: 2026-06-24 / 브랜치 `ci/cli-test-and-actions` / 피드백 1·6 (T1 잔여)
> v2: gstack-autoplan 6보이스(Codex·Claude × CEO·Design·Eng) 리뷰 반영. v1(경계 파티션 재작성 + 8핸들 드래그 휠) 폐기 — 아래 §0 참조.

## 0. v1에서 무엇이 바뀌었나 (리뷰 합의)

v1은 ≈52/100. 6보이스 전원이 방향 전환 권고. 구조적 결함 3가지로 v1 폐기:
1. **경계 "겹침 없는 파티션" 모델은 기존 per-column 보정(겹침 의존)을 표현 불가** → "동작 보존" 구조적 거짓 (`GestureAnalyzer.swift:92-100` + `ColumnGestureOverride.swift` 가 의도적 겹침으로 설계됨; `testColumn5SteepDiagonalStaysAsUpRight` 71.2°가 [67.5,72.5] 겹침구역). 
2. **8핸들 드래그 휠은 영역을 넓히는 순간 인접 핸들이 충돌**(~80pt 휠에서 min-gap시 ~11pt, 44pt 미달) + 앱에 접근성 인프라 0(grep 0건).
3. v1은 **코어(`GestureDirection.from`, 모든 키 입력 관문)를 재작성** — 핸드오프가 "4방향 만족시 생략 가능"이라 한 선택 기능에 과도.

**v2 = per-side 폭 분리(모델 유지) + 하이브리드 UI(파이 탭선택 + 선택방향만 큰 핸들 드래그 + 좌/우 슬라이더 + 리셋).** 기존 인식 모델·diagonal-first·per-column·wrap 안전성을 **전부 보존**하고, 좌/우 독립 폭이라는 새 축만 가산한다.

## 1. 목표

8방향에서 각 방향의 **인식 범위를 좌/우 독립으로** 넓히거나 좁힌다. 특히 카디널(ㅗ/ㅜ/ㅏ/ㅓ)을 한쪽으로 넓혀 비스듬한 긋기도 의도한 모음으로 인식되게 한다. UX는 **시각적 파이 + 직접 드래그 + 정밀 슬라이더** 하이브리드.

## 2. 엔진 설계 (per-side 폭)

### 2.1 데이터 모델 (`DirectionSector`, `SwipeProfile`)
- `DirectionSector`에 `leftHalfWidth: Double`, `rightHalfWidth: Double` 추가. **기본값 = `halfWidth`(22.5)** → 대칭, 기존과 동일.
- `centerAngle`·`halfWidth` **유지**(4방향 경로가 `centerAngle±45`를 읽고, 기존 UI/시각화가 `halfWidth`를 읽음 — 살려둔다).
- `SwipeProfile`에 전역 `axisRotation: Double = 0`(전체 회전, ±20°). **per-column `rotationOffsetDeg`(±15°)와 별개 축** — 전역은 휠 전체, per-column은 키별. 둘은 effective 계산에서 합산.
- **Codable 폴백**: `leftHalfWidth = decodeIfPresent ?? halfWidth`, `rightHalfWidth = decodeIfPresent ?? halfWidth`, `axisRotation = decodeIfPresent ?? 0`. 구버전 JSON(없음)은 대칭으로 디코딩 → **무손실·동작 동일**. (v1의 손실 마이그레이션 문제 원천 제거 — 모델을 안 바꾸므로.)
- 가드: 각 side 폭 10…40°(기존 슬라이더 범위와 동일). 클램프.

### 2.2 인식 (`GestureDirection.from`)
- `signedAngularDistance(center, relative)`를 **유지**(wrap-safe — 0°/360° 자동 처리. v1의 wrap 재구현 불필요). 부호로 좌/우 side 판별: 양수(CCW, 왼쪽)면 `leftHalfWidth`, 음수(CW, 오른쪽)면 `rightHalfWidth`로 비교.
- claim: `|signedDist| <= sideHalfWidth`.
- **해결 규칙(핵심, TDD로 양방향 검증):**
  - 기본은 **현행 그대로**: diagonal-first 순회(`diagonalSectorIndices + cardinalSectorIndices`). default·per-column 동작 **완전 보존**.
  - 예외(새 능력): 어떤 카디널이 **사용자가 base(22.5)를 넘겨 넓힌 side**로 claim하고( `22.5 < |signedDist| <= sideHalfWidth` ), 그 각이 인접 대각선의 base 범위에 들어 대각선이 가로채던 경우 → **그 카디널이 우선**(사용자 의도 우선). 두 사용자-확대 claim이 충돌하면 center에 가까운 쪽.
  - 4방향(`fourWay`/`forceCardinalOnly`) 경로는 **무변경**(`centerAngle ±45`).
- 검증: 60°에서 ↑ 우측을 35°로 넓히면 ↑가 ↗ 이기고(새 능력), 71.2° 컬럼5는 여전히 ↗(보존 — 71.2는 ↑ base 22.5 안이라 예외 미발동 → diagonal-first).

### 2.3 per-column 보정 공존
- `verticalIWidthDelta`/`horizontalEuWidthDelta`(대각선 폭 가산)는 **무변경**. per-side 카디널 폭은 직교하는 새 축이라 reinterpretation 불필요 → v1의 per-column 등가 문제 소멸.
- `GestureAnalyzer.effectiveSectors`: 기존 대각선 delta 가산은 그대로 두고, 카디널의 left/right 폭을 sector에 반영(컬럼 무관 전역).

### 2.4 두 `from` 호출부
- `GestureAnalyzer.analyzeLatestMovement`의 `GestureDirection.from` 호출 **2곳**(정상 임계 `:168`, reversal 임계 `:183`) 모두 per-side 경로 사용.

## 3. UI 설계 (하이브리드: 파이 탭선택 + 직접 드래그 + 슬라이더)

`SectorAngleView`(슬라이더 8개) → 새 `SectorAngleHybridView`:
- **파이**(기존 미리보기 확대): 8방향 영역 표시 + 라벨(→ㅏ ↗ㅣ …). **방향 탭 → 선택**. 선택 방향 하이라이트.
- **선택 방향의 좌/우 경계에만 큰 드래그 핸들 2개**(≥44pt 터치영역, touch-down시 확대). **한 번에 2개만 활성 → 8핸들 충돌 없음.** 드래그 → 해당 side 폭 갱신.
- **좌/우 폭 슬라이더 2개**(왼쪽 폭/오른쪽 폭, 10–40°, 0.5°) + 숫자 readout + 드래그와 양방향 동기. 슬라이더 = VoiceOver adjustable 무료.
- **리셋**: "이 방향 초기화" / "전체 초기화"(기존 `:517` 계승).
- **전체 회전 슬라이더 1개**(`axisRotation`, ±20°). per-column 회전과 다름을 footer로 안내.
- **상태 명세(전부)**: 드래그중 각도 readout, min/max 도달시 햅틱+시각 하드스톱, 선택 핸들 확대, 라이브 반영(점선=기본 22.5°).
- **접근성**: 슬라이더가 1급 경로(adjustable). 파이는 `accessibilityElement` per 방향 + `accessibilityAdjustable`(증감). 44pt 최소.
- **4방향 모드**: 파이/슬라이더 read-only dim + 기존 안내 카피(`GestureSettingsView.swift:170` 재사용).
- 정보 위계: 파이(상) → 선택방향 컨트롤(중) → 전체회전+리셋(하). 스크롤 없이 파이+선택 컨트롤 보이게.

### 3.1 시각화 연동
- 부채꼴 그리는 **2곳** 모두 per-side로 갱신: `GestureComponents.swift:288-297`(설정 미리보기), `GestureTestView.swift:660-690`(테스트 캔버스). `startAngle = center + leftHalfWidth`, `endAngle = center − rightHalfWidth`(시각 = 인식과 일치).

## 4. 단계 (분해)

### Phase 1 — 엔진 (UI 없음, 전부 TDD)
1. `DirectionSector.leftHalfWidth/rightHalfWidth` + `SwipeProfile.axisRotation` + Codable 폴백 + 구버전 round-trip/대칭 동등 테스트. `halfWidth`/`centerAngle` 유지·동기 불변식.
2. `GestureDirection.from` per-side + 해결 규칙. 테스트: (a) **default 동등** — 기존 `GestureAnalyzerTests` 8방향 단언 전부 통과; (b) **per-column 보존** — `testColumn5SteepDiagonalStaysAsUpRight`(71.2°→↗), 컬럼1; (c) **새 능력** — ↑ 우측 35° → 60°가 ↑; (d) **4방향 무변경**; (e) **wrap** — 0/359/1°, 회전 ±20°+컬럼 ±15° 조합.
3. `GestureAnalyzer.effectiveSectors` per-side 반영 + 두 `from` 호출부.
4. 전체 회귀: `GestureAnalyzerTests`·`KeyboardViewModelVowelDragTests`·`VowelResolverTests` 그린.

### Phase 2 — UI
5. `SectorAngleHybridView`(파이 탭선택 + 선택방향 2핸들 드래그 + 좌/우 슬라이더 + 리셋 + 회전 + 상태/햅틱 + 접근성).
6. `GestureSettingsView` 네비 교체, 4방향 비활성 안내.
7. 시각화 2곳 per-side 갱신.
8. 시뮬레이터 시각 검증(스냅샷, layoutOverride 패턴 재사용 가능).

## 5. 리스크 / 완화
- **코어 변경**: v1보다 작음(모델 유지·가산). default+per-column 동등을 TDD로 고정. 해결 규칙 예외는 사용자 확대시에만 발동 → 미설정 사용자 무변경.
- **마이그레이션**: per-side 기본=halfWidth → 무손실(모델 불변). 비-default 프로필도 대칭 유지 → 동작 동일.
- **UI 충돌/접근성**: 선택 방향만 2핸들 → 충돌 제거. 슬라이더 = 접근성 1급. 리셋 명세.
- **시각화 2곳**: 둘 다 갱신 명시(v1이 1곳만 인용한 결함 수정).

## 6. 테스트 전략
- 단위: per-side claim/해결 규칙(default 동등·per-column 보존·새 능력·4방향·wrap·회전 합성), Codable round-trip(default+비default), 폭 클램프, halfWidth/centerAngle 동기.
- 동등 앵커: 기존 `GestureAnalyzerTests` 8방향/4방향 단언 무변경 통과.
- 시각: 시뮬 스냅샷(하이브리드 파이 + 선택 상태).
- 명령: `xcodebuild test -only-testing:MoaPlusKeyboardTests`.

## 7. 결정된 사항 (v1 미결 해소)
- per-side 폭 범위: **10–40°**(기존 슬라이더와 동일).
- 전역 회전 `axisRotation` **±20°**, per-column `rotationOffsetDeg` **±15°** 별개 — UI에서 둘 다 노출, footer 설명.
- `DirectionSector`: `centerAngle`+`halfWidth` **유지**(4방향·시각화 의존).
- 마이그레이션: 모델 유지로 **무손실**(샘플링·유도 불필요).
- 해결 규칙: 사용자-확대 카디널이 대각선 base를 이기되 base 범위는 diagonal-first 보존(컬럼 테스트 안전).
- 드래그 vs 슬라이더: **둘 다**(선택방향 2핸들 드래그 + 좌/우 슬라이더 동기) — 사용자 결정.

## 8. 비범위
- 자동 캘리브레이션/학습(CEO 보이스 10x 제안)은 별도 후속. DiagonalMapping/모음매핑 변경 없음. 4방향 로직 변경 없음(호환만).

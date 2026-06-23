# 긋기 8방향 경계 각도 — 경계 모델 + 드래그 휠 UI

> 작성: 2026-06-24 / 브랜치 `ci/cli-test-and-actions` / 피드백 1·6 (T1 잔여)
> 리뷰 파이프라인(`/gstack-autoplan`: CEO·Design·Eng·DX) 입력용 종합 플랜.

## 1. 목표 / 제품 근거

8방향 긋기에서 사용자가 **각 방향의 인식 범위 경계를 좌/우 독립으로 미세조정**할 수 있게 한다.

**왜 지금까지 안 됐나(근본 원인):** 현재 모델은 각 방향이 `중심각 ± halfWidth`(대칭)이고, `GestureDirection.from`이 **대각선 섹터를 카디널보다 먼저 검사**한다([GestureDirection.swift:84](../../MoaPlusKeyboard/Models/GestureDirection.swift)). 그래서 카디널(ㅗ/ㅜ 등) halfWidth를 넓혀도 인접 대각선과 겹치는 영역을 대각선이 가로채 **효과가 없다**(피드백 1 "각도 바꿔도 적용 안 됨"의 실제 원인, 핸드오프 핵심 발견). 4방향 모드는 대각선을 꺼서 이 한계를 우회했을 뿐, 8방향에서는 미해결로 남아 있었다.

**누가 쓰나:** 엄지 각도/손 기울기가 사람마다 달라 기본 45° 분할이 안 맞는 사용자. 특히 한 방향이 자꾸 인접 방향/대각선으로 오인식되는 경우 경계를 직접 옮겨 교정.

## 2. 핵심 설계 결정 (브레인스토밍 확정)

1. **경계(boundary) 기반 모델** — "중심±폭" 대신 인접 방향 사이의 **8개 경계각**을 1급 데이터로. 경계를 옮기면 한 방향이 넓어지고 인접 방향이 그만큼 좁아진다 → **겹침/공백 원천 차단, 대각선 우선판정 불필요** → 위 근본 문제 해소.
2. **UI = 원형 드래그 휠** — 슬라이더 8개를 **경계 핸들 8개 드래그**로 교체(직접 조작). 인접 경계 사이로 제약된 드래그.
3. **전체 회전만 슬라이더 유지** — 휠 전체(모든 경계)를 CW/CCW로 돌리는 전역 `rotation` 슬라이더 1개는 남긴다(손 기울기 보정).
4. **4방향 모드 호환** — 4방향 ON이면 휠/회전 비활성(기존처럼 90° 고정), 안내 문구.
5. **기존 사용자 무손상** — Codable 폴백으로 구버전 설정(대칭 halfWidth)을 경계로 유도.

## 3. 아키텍처 / 컴포넌트

### 3.1 데이터 모델 (`SwipeProfile`)
- 신규: `var sectorBoundaries: [Double]` — 8개 경계각(math deg, 0=→ 기준 CCW, 단조증가). 방향 i 구간 = `(boundaries[(i+7)%8] … boundaries[i])`. 기본값 `[22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5]`(현 동작과 정확히 동등).
- `DirectionSector`는 **라벨/중심각용으로 축소**(또는 boundaries에서 start/end 파생). `halfWidth`는 deprecated.
- **Codable 폴백** ([SwipeProfile.swift:154](../../MoaPlusKeyboard/Models/SwipeProfile.swift)): `sectorBoundaries = decodeIfPresent(...) ?? deriveBoundaries(from: sectors)`. 구버전 JSON(boundaries 없음)은 기존 sectors의 centerAngle±halfWidth에서 경계 유도 → 설정 전체 리셋 방지(CLAUDE.md 규칙).
- 불변식 가드: 정렬·인접 최소 간격(예: 8°)·총합 360° 보존. 위반 시 클램프.

### 3.2 인식 로직 (`GestureDirection.from`)
- `center ± halfWidth` 순회 + 대각선 우선 → **경계 구간 탐색**: 입력 각도(상대 = normalized − rotation)가 어느 `(boundaries[i-1], boundaries[i])`에 드는지 이진/선형 탐색 → `sectorOrder[i]`. 겹침이 없으니 대각선 우선판정 제거.
- `fourWay`(4방향) 경로는 **현행 유지**(±45° 쿼드런트 고정). 경계는 8방향일 때만.
- `rotation`: 기존 `rotationOffset` 파라미터 재사용(전역 회전 슬라이더 → 모든 경계에 동일 offset).

### 3.3 per-column 보정 공존 (`GestureAnalyzer.effectiveSectors`)
- 현재 컬럼별 `verticalIWidthDelta`(↗↖ 확장)·`horizontalEuWidthDelta`(↙↘ 확장)는 sectors[1,3]/[5,7] halfWidth에 가산([GestureAnalyzer.swift:86](../../MoaPlusKeyboard/Engine/GestureAnalyzer.swift)).
- 경계 모델에선 **해당 경계를 컬럼별로 이동**(예: ↗ 폭 확대 = ↗의 양쪽 경계 22.5/67.5를 바깥으로). effective boundaries = 전역 boundaries + per-column 경계 shift. 기존 ㅣ/ㅡ 컬럼 보정 동작 보존.

### 3.4 UI (`SectorAngleView` 교체)
- 신규 `SectorBoundaryWheelView`: 원형 캔버스에 8개 방향 섹터 + 8개 경계 핸들. 핸들 드래그 → 해당 경계 각도 갱신(인접 경계 사이로 제약, 최소 간격 가드). 라이브 반영(점선=기본 위치). 방향별 라벨(→ㅏ ↗ㅣ ↑ㅗ …).
- **전체 회전 슬라이더 1개** 유지.
- 4방향 모드 ON이면 휠/슬라이더 비활성 + 안내(기존 `swipeModeDescription` 패턴).
- 기존 `SectorAngleView`(슬라이더 8개) 제거, `GestureSettingsView`의 NavigationLink 대상 교체.

### 3.5 시각화 연동 (`GestureTestView`)
- 긋기 테스트 캔버스가 sectors[i].startAngle/endAngle로 부채꼴을 그림([GestureComponents.swift:358](../../MoaPlus/Settings/GestureComponents.swift)). 경계 모델의 boundaries로 부채꼴 산출하도록 갱신 → 테스트 화면과 휠 설정이 일치.

## 4. 구현 단계 (분해)

코어 회귀 위험이 크므로 **2 Phase로 분해, 각 Phase 독립 동작·테스트 가능.**

### Phase 1 — 엔진 (UI 없음, 전부 TDD)
1. `SwipeProfile.sectorBoundaries` + Codable 폴백 + 불변식 가드 + round-trip/구버전 호환 테스트.
2. `GestureDirection.from` 경계 구간 탐색 전환 + 기본 boundaries = 기존 `GestureDirectionTests` 전부 통과(동등성) + 비대칭 경계 신규 테스트.
3. `GestureAnalyzer.effectiveSectors`(또는 effectiveBoundaries) per-column shift 전환 + 기존 컬럼 보정 테스트 보존.
4. 4방향 모드 경로 불변 회귀 테스트.

### Phase 2 — UI
5. `SectorBoundaryWheelView`(드래그 휠 + 제약 드래그 + 라이브) + 전체 회전 슬라이더.
6. `SectorAngleView` 제거·교체, `GestureSettingsView` 네비 갱신, 4방향 비활성 안내.
7. `GestureTestView` 부채꼴을 boundaries 기반으로 갱신.
8. 시뮬레이터 시각 검증(스냅샷 또는 수동).

## 5. 리스크 / 완화
- **제스처 인식 코어 리팩터(최고 위험)** — `GestureDirection.from`은 모든 입력의 관문. 완화: Phase 1 전부 TDD, 기본 boundaries로 기존 테스트 100% 동등 보장, 비대칭은 추가 테스트로만 확장.
- **per-column 보정 회귀** — effectiveSectors 변경. 완화: 기존 컬럼 보정 테스트 유지 + 경계 shift 등가 검증.
- **커스텀 인터랙티브 휠 UI** — 제약 드래그/히트타겟. 완화: Phase 2 분리, 시뮬 시각 검증.
- **마이그레이션** — 구버전 대칭 halfWidth → 경계 유도가 어긋나면 사용자 설정 깨짐. 완화: decodeIfPresent 폴백 + round-trip 테스트 + 유도식 단위테스트.

## 6. 테스트 전략
- 단위: 경계 구간 탐색(경계/구간 내/외), 마이그레이션 유도, round-trip, 0폭/역전 가드, per-column shift, 4방향 불변.
- 동등성: 기본 boundaries에서 기존 `GestureDirectionTests` 전체 통과.
- 시각: iPhone 17 + GestureTestView 부채꼴, 휠 드래그 결과(시뮬).
- 명령: `xcodebuild test -only-testing:MoaPlusKeyboardTests`.

## 7. 리뷰 게이트용 미결 취향 결정 (autoplan이 판단할 지점)
- **인접 최소 간격** 값(8°? 5°?) — 너무 작으면 0폭, 크면 자유도 제한.
- **per-column 보정**: 경계 shift로 재해석 vs 이 기능 범위에서 보정 단순화/제거.
- **회전 슬라이더 범위**: 현행 per-column ±15°와 별개 전역 회전의 범위(±20°?).
- **휠 핸들 히트타겟/접근성**: 작은 화면에서 8핸들 드래그 정확도.
- **DirectionSector 처리**: 완전 제거 vs 라벨/파생 유지(기존 참조 다수 — 호환 비용).

## 8. 비범위
- 모음 매핑(DiagonalMapping) 변경 없음. 4방향 모드 로직 변경 없음(호환만). per-column 보정 UI 신규 추가 없음(기존 유지).

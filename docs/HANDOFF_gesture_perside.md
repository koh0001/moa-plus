# 핸드오프 — 8방향 좌/우 각도(per-side) 기능 + 미해결 fix

> 작성 2026-06-24. 새 세션이 이걸 읽고 콜드 스타트로 이어가도록 작성.
> 직전 작업: 실기기 테스트에서 **데드존 버그 + 파이 일관성** 발견 → fix 대기.

## 0. TL;DR (지금 상태)
- **브랜치 `ci/cli-test-and-actions`, HEAD `5454f63`, 작업트리 clean.**
- **main `9b5fdd4`** = iPad 레이아웃 기능까지 머지+푸시됨(origin/main 동기). **8방향 per-side 기능은 main에 없음**(ci에만, 8커밋).
- 8방향 per-side 기능: **구현·리뷰·테스트 완료, 단 실기기서 2개 이슈 발견 → 다음 세션 최우선 fix.**

## 1. 이번 세션 한 일 (3건)

### A. ㅛㅠㅕㅑ 단일긋기 안내 제거 (커밋 `60f9f09`, main 포함)
- 모던 ㅣ/ㅡ 키 단일긋기 파생모음이 실기기 미작동(클린빌드로도 재현). 코드·단위테스트는 정상이나 실기기 터치스트림에서만 실패 → 원인 추적 비용 큼 → **안내만 제거**(멀티스트로크 ↑↓↑ 경로는 유지). GestureSettingsView의 단일방향 안내 Label 삭제.

### B. iPad 레이아웃 (T6) — 완료, main 머지+푸시, CI green
- 동적 높이(런타임 UIScreen 실측) + 가로 좌우 분리(좌 숫자패드/우 모아키) + numberPadSide 설정 + 회전 대응.
- 커밋 `6e7e815`~`2c355f5`(8태스크) + `45bc0fe`(팝업X보정) + `9b5fdd4`(numpad 그림자+스냅샷 하네스). 시뮬 스냅샷 검증됨. main=9b5fdd4, **origin/main 푸시 완료, GitHub Actions green.**
- `KeyboardView.layoutOverride`(기본 nil) 시드 + `KeyboardSnapshotTests`(ImageRenderer) = iPad 시각 회귀 가드(메인앱 뷰는 익스텐션 테스트타겟에서 렌더 불가라 이 패턴 사용).
- 부수: 확장형/클래식 자음 대각선 ㅣ/ㅡ 실기기 미작동 → **KNOWN_ISSUES KI-2로 폐기 기록**(커밋 `2691c90`). 모던 레이아웃 권장.

### C. 8방향 좌/우 각도 (per-side) — ci에만, 미해결 fix 있음
아래 §2~§4가 본 핸드오프의 핵심.

## 2. per-side 기능 — 설계 배경 (왜 이 모양인가, 재논의 방지)

**요구**: 8방향에서 각 방향의 인식 범위를 좌/우 독립으로 미세조정(특히 ㅗ/ㅜ를 한쪽으로 넓혀 비스듬한 긋기 교정). UX는 사용자 요청으로 시각 파이 + 직접 드래그.

**`/gstack-autoplan` 6보이스 리뷰(CEO·Design·Eng × Codex·Claude)가 v1을 폐기시킴:**
- **v1(폐기, 커밋 `21c919e`)** = "겹침 없는 8경계 파티션" 모델 + 8핸들 드래그 휠. ≈52점.
- 폐기 사유(전원 합의): ① 경계 파티션은 **기존 per-column 보정(겹침 의존)을 표현 불가** — "동작 보존" 구조적 거짓(`testColumn5SteepDiagonalStaysAsUpRight` 71.2°가 [67.5,72.5] 겹침구역). ② 8핸들 휠은 **영역 넓힐 때 핸들 충돌**+접근성 0. ③ 선택 기능에 코어 과재작성.
- **v2(채택, 커밋 `d186bd6`, ≈91점)** = `DirectionSector.leftHalfWidth/rightHalfWidth`(per-side) + 하이브리드 파이(탭선택 + 선택방향만 큰 핸들 드래그 + 좌/우 슬라이더 + 리셋). **기존 모델·diagonal-first·per-column·wrap 안전성 전부 보존**, 좌/우 폭이라는 새 축만 가산.
- 전체 설계: `docs/superpowers/plans/2026-06-24-gesture-boundary-angle-wheel.md` (v2).

**엔진 핵심 (`MoaPluskeyboard/Models/GestureDirection.swift` from()):**
- `DirectionSector`에 `leftHalfWidth`/`rightHalfWidth`(기본=halfWidth 22.5). `halfWidth` `didSet`이 양 side로 미러(프리셋/델타가 halfWidth 직접 변경 시 동기). `centerAngle` 유지(4방향이 사용).
- `SwipeProfile.axisRotation`(전역 회전 ±20°, per-column rotationOffset ±15°와 별개로 합산).
- `from()` 8방향 경로 2단계: **STEP1** 사용자가 base(22.5) 넘겨 넓힌 카디널이 `base < |signedDist| <= side`로 claim하면 우선(부호: +=CCW=left→leftHalfWidth). **STEP2** 기존 diagonal-first 순회를 per-side claim으로. default(left==right==22.5)면 STEP1 미발동·STEP2=기존과 비트동등(720점 스위프 mismatch 0 입증). 4방향 경로 무변경.
- `GestureAnalyzer.effectiveSectors`: 컬럼 delta를 `leftHalfWidth += / rightHalfWidth +=`로 직접 가산(비대칭 보존). `effectiveRotationOffset` = axisRotation + per-column.

**UI (`MoaPlus/Settings/GestureComponents.swift` SectorAngleHybridView + PerSidePieChart):**
- 파이 탭→방향 선택, 선택방향만 좌/우 경계 큰 핸들 2개(44pt) 드래그, 좌/우 폭 슬라이더(10~40°), 리셋(이방향/전체), 전체회전 슬라이더, 4방향시 비활성, 접근성(슬라이더 adjustable).
- **불변식**: UI는 `leftHalfWidth`/`rightHalfWidth`만 직접 set, `halfWidth`는 절대 set 금지(didSet가 per-side 리셋). 리셋만 halfWidth=22.5 의도적.

**리뷰 결과**: Phase1 엔진 COMMENT(회귀0 수학증명), Phase2 UI APPROVE(8 spec PASS). fix웨이브(axisRotation 시각화 일치 + per-column per-side + tie테스트, 커밋 `0ec5cd6`) 적용됨.

## 3. ⚠️ 미해결 — 실기기 테스트서 발견 (다음 세션 최우선)

사용자 실기기 테스트(↗ 방향 왼쪽14°/오른쪽40°로 편집):

### 이슈 1 — **데드존 버그 (확정, 최우선)**
- `GestureDirection.from` 마지막 줄(`MoaPlusKeyboard/Models/GestureDirection.swift:122`): claim 섹터 없으면 `return nil`.
- per-side로 한쪽을 **좁히면** 인접과 사이에 **빈 구역(gap)** 발생(예: ↗ 왼쪽 14° → ↗[59°]와 ↑[67.5°] 사이 [59,67.5] 무주공산). 거기로 그으면 **인식 안 됨(데드존)**.
- **수정안(사용자와 합의 진행중, 미구현)**: `from()`에 **STEP3 = 가장 가까운 center 폴백** 추가 → gap 각도를 |signedDist| 최소 섹터에 배정. 데드존 제거.
- 멘탈모델 확정: **"넓히면 그 방향이 영역을 뺏고(STEP1/diagonal-first), 좁혀서 빈 곳은 가장 가까운 방향이 가져간다(STEP3)."** 데드존 0.

### 이슈 2 — **파이 일관성**
- 설정 파이 4종이 서로 다른 변환 적용: `SectorAngleHybridView`(편집, PerSidePieChart)·`mappingSlices`(방향별 모음 매핑)는 회전/델타 **미적용**(원본 per-side), `GestureTestView` SectorOverlay·per-column 미리보기는 **델타/회전 적용**. → 같은 ↗ 편집이 화면마다 다르게 보임.
- 셋 다 `profile.sectors`(per-side) 읽긴 함(`GestureComponents.swift:323,338`; `mappingSlices:338`; `GestureTestView.swift:549`). 편집 파이↔매핑 파이는 동일소스라 일치해야 함 — 불일치면 **갱신/캐시(@Published 전파)** 점검 필요.
- **할 일**: 4파이가 무엇을 보여주는지 명확화·통일(예: 모두 원본 per-side 기준 + 별도로 "이 화면은 N열 보정 반영" 라벨), 편집/매핑 불일치 재현·수정.

### 이슈 3 — 겹침 우선순위 (사용자 답 대기)
- 현재 = "넓힌 방향이 이김"(STEP1 카디널 / diagonal-first 대각선). 사용자가 ↗ 넓히니 →ㅏ 영역 양보돼 **의도대로 동작 확인됨**.
- 제안값(추천): 위 "넓히면 뺏고 좁히면 가까운쪽" 규칙. 대안: 무조건 nearest-center(단 per-column 깨짐 — 채택 비권장).
- 사용자가 핸드오프 요청으로 전환 → **최종 confirm 대기 중**. 새 세션은 이 규칙으로 갈지 먼저 확인.

## 4. 다음 세션 액션 (순서)
1. **이슈 3 규칙 확정**(사용자에게 "넓히면 뺏고/좁히면 가까운쪽" OK인지).
2. **이슈 1 fix**: `from()` STEP3 nearest-center 폴백 + TDD(gap 각도가 nearest로 배정, 데드존 0, default/per-column 무변경 회귀).
3. **이슈 2 fix**: 파이 4종 일관성 점검·통일.
4. 전체 회귀(`xcodebuild test -only-testing:MoaPlusKeyboardTests`) + 실기기 재확인.
5. 사용자 매뉴얼 QA 잔여(아래 §5).
6. **머지 결정**: 준비되면 ci → main 머지 + origin 푸시(CI). iPad 때처럼 사용자 확인 후.

## 5. 사용자 매뉴얼 QA 체크리스트 (미완)
- **8방향(최우선)**: A-1 기존 긋기 회귀 / A-3 실제 교정 효과(방향 넓힌 뒤 비스듬한 긋기 인식). 데드존 fix 후 재확인.
- **iPad(시뮬)**: 가로 분리/세로 높이/숫자패드 좌우 설정/롱프레스 팝업 위치/아이폰 회귀.
- 빌드 위생: **⌘⇧K + 키보드 삭제/재추가 필수**(익스텐션 incremental 누락 잦음).

## 6. 핵심 파일
- 엔진: `MoaPlusKeyboard/Models/GestureDirection.swift`(from STEP1/2, :122 gap), `Models/SwipeProfile.swift`(DirectionSector per-side + didSet, axisRotation, Codable), `Engine/GestureAnalyzer.swift`(effectiveSectors per-side, effectiveRotationOffset).
- UI: `MoaPlus/Settings/GestureComponents.swift`(SectorAngleHybridView, PerSidePieChart, baseSlices, mappingSlices, DirectionPieChart), `GestureTestView.swift`(SectorOverlay :548), `GestureSettingsView.swift`(네비).
- 테스트: `MoaPlusKeyboardTests/PerSideSectorWidthTests.swift`(14+ tie), `GestureAnalyzerTests.swift`(컬럼 보존 앵커).
- 플랜/리뷰: `docs/superpowers/plans/2026-06-24-gesture-boundary-angle-wheel.md`(v2), 리뷰 스크래치 `.superpowers/sdd/`(gitignored).
- 앱스토어 노트: `docs/appstore/whats-new-next.md`(iPad + 좌/우 각도, 안전형식 한/영).

## 7. 명령
```bash
# 키보드 단위/회귀 테스트
xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoaPlusKeyboardTests
# 클린(익스텐션 변경 검증)
xcodebuild clean test ... -only-testing:MoaPlusKeyboardTests
```

## 8. 결정 로그 (재논의 금지)
- 경계 파티션 모델 = 폐기(per-column 겹침 보존 불가). per-side 채택.
- 8핸들 직접 드래그 휠 = 폐기(충돌). 하이브리드(탭선택+선택방향만 핸들+슬라이더) 채택.
- 겹침 = 넓힌 쪽 우선. 틈 = 가장 가까운 쪽(STEP3, 미구현).
- iPad: 모던만 분리, 아이폰 무손상, 동적높이 런타임 실측.

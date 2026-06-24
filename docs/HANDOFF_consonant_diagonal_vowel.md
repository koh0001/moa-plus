# 핸드오프 — 자음 대각선 ㅣ/ㅡ 파생모음 (GestureAnalyzer 근본 fix ✅ 완료)

> 작성 2026-06-25. fix 적용·시뮬 전체 유닛테스트 통과. 남은 것 = 실기기 QA + main 머지.

## ✅ FIX 완료 (2026-06-25)
- **fix(split5, `Engine/GestureAnalyzer.swift`):** `analyzeLatestMovement` referencePoint 분리.
  - 방향값 = 최근 window(`effectiveReversalThreshold` 호길이, `windowReferenceIndex`) 궤적으로 판정 → 흡수/유령방향 제거.
  - turn 변위 = 직전 stroke 마지막점(`strokeAnchorPoint` = turn 지점)부터 측정 → 긴 진입 stroke의 누적 부풀림 배제.
  - 비reversal turn은 `effectiveThreshold` 바닥 게이트(정수직 ↗ wobble/끝휨 차단 = ㅗ→ㅘ 방지), reversal은 낮은 임계 유지(ㅛㅠ 촘촘 반전 보존).
  - public API(addPoint/finalizeGesture/reset) 무변경. 신규 변수 `strokeAnchorPoint`, 헬퍼 `windowReferenceIndex(arcLength:)`.
- **검증:** Python 정밀 포팅으로 회귀 41 + 신규 11 전부 통과(점밀도 4~80 무관, 곡선 robustness current 대비 대폭 개선) → `xcodebuild test -only-testing:MoaPlusKeyboardTests` 전체 `** TEST SUCCEEDED **`(실패 0). 통합 `driveKeyMulti` 15개(`KeyboardViewModelVowelDragTests`) + 직접 진단 3개(`GestureAnalyzerTests`) 추가. "기"→"가", ↙↑="고", 21모음 파생 전부 GREEN.
- **남은 것:** 실기기 QA(⌘R → 자음 ㄱ ↗→="가", ↙↑="고" 등), main 머지(ci 미머지 누적 `e3f71c7`~`f14d268` + 이 fix 함께).

---

## 0. TL;DR (작업 당시 기록 — 아래는 히스토리)
- 브랜치 `ci/cli-test-and-actions`. main 미머지 ci 누적: `e3f71c7`(trie skip 오류허용)·`3305fef`/`01f05cf`(spec)·`1240181`(자음 대각선 파생 헬퍼).
- **자음 대각선 ㅣ/ㅡ 진입 후 파생모음 기능 = 실기기 미작동**(ㅢ만 됨). 헬퍼 코드는 맞으나 **GestureAnalyzer가 directions를 의도와 다르게 생성**하는 게 root cause. systematic-debugging으로 확정.
- 다음: GestureAnalyzer 근본 fix (사용자 승인). **단 미묘·회귀 위험 큼 → spec→autoplan→TDD 권장.**

## 1. Root Cause (확정, 재조사 불필요)

`GestureAnalyzer.analyzeLatestMovement`(`Engine/GestureAnalyzer.swift:159`)는 첫 stroke 등록 후 `lastDirectionChangePoint`를 그 시작점에 **고정**한다(연속 동일 방향이면 갱신 안 함, else 분기에 아무 동작 없음). 방향 판정 vector = `currentPoint - lastDirectionChangePoint`.

자음 대각선 진입은 긴 첫 stroke(↗/↙)가 되고, 후속 카디널 stroke의 점들이 **그 먼 시작점 기준**으로 vector 계산 → 얕은/엉뚱한 각도 → 후속이 진입 대각선에 흡수되거나 다른 방향으로 잡힘. 컬럼 섹터 widening(per-column `verticalIWidthDelta` 등)이 악화.

**진단 확정값** (GestureAnalyzer 직접, driveKeyMulti 동일 8점 점열):
- iRight `↗→`: col0 = `[.upRight, .right]`(정상) / **col4(ㄱ) = `[.upRight]`**(후속 → 흡수, ㄱ열 iDelta 1.5+rotation -2°로 ↗섹터 [21,69]). → 헬퍼 rest 빈 → fallback ㅣ → "기".
- euUp `↙↑`: col0/col4 = **`[.downLeft, .left, .up]`**(의도 ↙↑ 아닌 ↙←↑). → 헬퍼 ㅛ → "교".
- ㅢ(↘↖/↘↑)만 trie 단독 패턴이라 우연히 됨 → 사용자 "ㅢ만 됨".

**왜 단위 통과/실기기 실패**: 단위 테스트는 directions를 직접 주입(`resolveConsonantDiagonalVowel([.upRight,.right])`=ㅏ 통과)해 GestureAnalyzer 왜곡을 안 거침. 실기기는 GestureAnalyzer가 왜곡된 directions 생성.

## 2. Fix 방향 (사용자 승인: GestureAnalyzer 근본 fix)

핵심: 후속 stroke의 방향 판정이 "먼 진입 시작점"이 아니라 "최근 위치" 기준이어야 함.

- **순진한 안(위험)**: 같은 방향 시 `lastDirectionChangePoint = currentPoint` 슬라이딩 → turn 등록 magnitude(`current - lastChangePoint`)가 작아져 실기기 촘촘 터치에서 turn 미등록 → ㅛㅠㅘ 등 기존 멀티스트로크 회귀.
- **권장 안**: 방향 판정용 referencePoint(최근 점/window)와 turn magnitude용 referencePoint(stroke 시작점)를 **분리**. 방향은 최근 기준(정확), magnitude는 누적(turn 등록 보존).
- 회귀 필수: 기존 `GestureAnalyzerTests`(ㅛㅠ triple reversal, drift 흡수, over-promote 방지, column5/1 대각선 앵커), `KeyboardViewModelVowelDragTests` 전부.

## 3. 검증 방법 (이번 세션에서 검증)

`KeyboardViewModelVowelDragTests`에 통합 헬퍼 추가해 실기기 근사:
```swift
private func driveKeyMulti(row:Int, column:Int, strokes:[(dx:CGFloat,dy:CGFloat)]) {
    var p = CGPoint(x:100,y:100); vm.gestureStarted(row:row,column:column,at:p)
    for s in strokes { for i in 1...4 { let f=CGFloat(i)/4; vm.gestureMoved(to:CGPoint(x:p.x+s.dx*f,y:p.y+s.dy*f)) }; p=CGPoint(x:p.x+s.dx,y:p.y+s.dy) }
    vm.gestureEnded(row:row,column:column)
}
// ㄱ 키 (row1,col4): ↙ㅡ 후 ↑ → "고"(ㄱ+ㅗ) 기대, ↗ㅣ 후 → → "가"(ㄱ+ㅏ) 기대.
```
fix 전 이 통합 테스트가 RED(현재 "기"/"교"), fix 후 GREEN이 목표. (이번 세션 임시 진단은 정리함.)
새 Xcode26: assert/XCTFail 메시지가 콘솔에 안 찍힘 → 후보별 `XCTAssertEqual`로 통과/실패만으로 actual 좁히는 기법 사용. xcodebuild 출력은 소문자 `Test case`.

## 4. 현재 코드 상태
- `resolveConsonantDiagonalVowel`(`KeyboardViewModel.swift`, 커밋 1240181): directions[0] 대각선이면 ㅣ/ㅡ primitive로 보고 후속을 `resolveVowelFromPrimitiveDrag`에 위임 + ㅡ+ㅣ방향=ㅢ 보강. **directions만 제대로 오면 작동**(단위테스트 통과). GestureAnalyzer fix로 directions가 맞으면 자동 동작.
- spec: `docs/superpowers/specs/2026-06-25-consonant-diagonal-vowel-derivation-design.md`. 매핑표(천지인 정통) §3.

## 5. 결정 로그
- 매핑: 천지인 정통(전용 ㅣ/ㅡ키와 동일), 진입 좌우 구별 X. 확정.
- trie skip 오류허용(e3f71c7): ㅛㅠ 다단계 모음 — 실기기 OK(사용자 확인).
- fix는 GestureAnalyzer referencePoint 분리. autoplan 권장(OpenMoa 전체이식처럼 결함 사전 차단).

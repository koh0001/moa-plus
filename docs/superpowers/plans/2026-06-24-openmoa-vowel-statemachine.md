# 다단계 모음 오류 허용 — PatternTrie skip 최소 fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`).
> 2026-06-25. /gstack-autoplan 4-voice 리뷰가 전체 OpenMoa 이식을 만장일치 REJECT
> (전용 ㅣ/ㅡ키 6+테스트 회귀 + DiagonalMapping 설정화면 무력화 + scope 과대).
> 사용자 결정: **최소 fix 채택, 잘 되는지 보고 OpenMoa 확장 여부 재결정.**
> 원본(전체 이식) 플랜: `~/.gstack/projects/koh0001-moa-plus/ci-cli-test-and-actions-autoplan-restore-*.md`

**Goal:** `VowelPattern.PatternTrie.match()`의 `break`(자식 없으면 멈춤)를 **skip**(무관 stroke 건너뛰고 매칭 계속)으로 바꿔, 자음키/slot-B 모음 제스처에서 중간 무관 stroke를 흡수 → ㅛ·ㅠ·ㅢ 등 다단계 모음 입력 난이도 개선.

**Architecture:** `match()` 한 곳만 수정. `VowelResolver`/`normalizeForMatching`/`resolveDirectDiagonal`/전용 ㅣ/ㅡ키(`resolveVowelFromPrimitiveDrag`)/`DiagonalMapping`/`canExtend`/`hasMoreMatches` 전부 무손상.

## Global Constraints

- 정확 입력 결과 불변 — 기존 `VowelResolverTests`(특히 over-promote 방지, diagonal drift), `KeyboardViewModelVowelDragTests`, `GestureAnalyzerTests` **전부 통과 유지**.
- 빌드 검증 메인앱 포함: `xcodebuild build-for-testing -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17'`.
- **핵심 리스크(autoplan)**: skip 이 너무 공격적이면 over-promote(작은 노이즈를 복합모음으로 과승격) 회귀 + false-positive(의도적 중단을 흡수). 기존 회귀 테스트가 깨지면 skip 범위를 제한해야 함.

---

## Task 1: PatternTrie.match break→skip + 오류 허용 테스트

**Files:**
- Modify: `MoaPlusKeyboard/Models/VowelPattern.swift` (`PatternTrie.match`, line 88-113)
- Test: `MoaPlusKeyboardTests/VowelResolverTests.swift`

**Interfaces:** `match([GestureDirection]) -> MatchResult` 시그니처 불변. 동작만 관대해짐.

- [ ] **Step 1: RED — 오류 허용 테스트 추가** (VowelResolverTests.swift)

```swift
func testErrorTolerance_skipsUnmatchedMidStroke() {
    // ↑↓↑(ㅛ) 사이에 무관한 ← 노이즈가 끼어도 skip 되어 ㅛ 완성
    XCTAssertEqual(resolver.resolve(directions: [.up, .left, .down, .up]).vowel, .ㅛ)
}
```

- [ ] **Step 2: RED 확인** — `resolve([.up,.left,.down,.up])`는 현재 `.up`(ㅗ) 다음 `.left`에서 trie 자식 없음 → `break` → ㅗ 반환. Expected ㅛ, got ㅗ → FAIL.

- [ ] **Step 3: GREEN — match 의 break를 continue(skip)로**

```swift
func match(_ directions: [GestureDirection]) -> MatchResult {
    var current = root
    var lastMatch: (vowel: Jungseong, count: Int)?
    var hasLongerMatch = false

    for (index, direction) in directions.enumerated() {
        guard let next = current.children[direction] else {
            continue   // skip unmatched stroke (was: break) — 오류 허용
        }
        current = next
        if let vowel = current.vowel {
            lastMatch = (vowel, index + 1)
        }
        if index == directions.count - 1 && !current.children.isEmpty {
            hasLongerMatch = true
        }
    }

    if let match = lastMatch {
        return MatchResult(vowel: match.vowel, consumedCount: match.count, hasLongerMatch: hasLongerMatch)
    }
    return MatchResult(vowel: nil, consumedCount: 0, hasLongerMatch: !current.children.isEmpty)
}
```

- [ ] **Step 4: GREEN + 회귀 — 전체 VowelResolverTests**

Run: `xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoaPlusKeyboardTests/VowelResolverTests 2>&1 | grep -E "Test Case .* failed|TEST (SUCCEEDED|FAILED)"`
Expected: 신규 통과 + **기존 전부 통과**. 만약 over-promote/drift 테스트가 깨지면 → skip을 제한(예: 직전 매칭 이후 1회만 skip 허용, 또는 consumedCount 기반)하도록 Step 3 재설계.

- [ ] **Step 5: Commit**

```bash
git add MoaPlusKeyboard/Models/VowelPattern.swift MoaPlusKeyboardTests/VowelResolverTests.swift
git commit -m "feat(vowel): PatternTrie match skip — 다단계 모음 오류 허용"
```

---

## Task 2: 전수 회귀 + 메인앱 빌드

- [ ] **Step 1:** `xcodebuild build-for-testing -scheme MoaPlus ...` → TEST BUILD SUCCEEDED
- [ ] **Step 2:** `xcodebuild test ... -only-testing:MoaPlusKeyboardTests` → `** TEST SUCCEEDED **`, 실패 0
- [ ] **Step 3:** 실기기/시뮬 검증 — 자음 대각선(↙ㅡ, ↗ㅣ)에서 ㅛ/ㅠ/ㅢ 입력이 노이즈에도 잘 되는지. false-positive(의도 중단인데 모음 commit) 체감 확인.

## Self-Review

- Spec §4.2(오류 허용) → match skip ✓. §5(정확 입력 불변) → 기존 테스트 회귀로 검증 ✓.
- Placeholder: Step 4의 "skip 제한 재설계"는 회귀 발생 시 조건부 — 발생 안 하면 불필요.
- 전용키/DiagonalMapping/canExtend 무변경 — autoplan이 잡은 회귀 전부 회피.
- **열린 리스크**: false-positive는 단위테스트로 완전 검증 불가 → 실기기 QA(Task 2 Step 3)로 사용자 판단.

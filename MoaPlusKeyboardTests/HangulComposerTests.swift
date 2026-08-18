import XCTest

final class HangulComposerTests: XCTestCase {

    var composer: HangulComposer!

    override func setUp() {
        super.setUp()
        composer = HangulComposer()
    }

    override func tearDown() {
        composer = nil
        super.tearDown()
    }

    // MARK: - Basic Composition Tests

    func testInitialState() {
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
        XCTAssertEqual(composer.displayText, "")
    }

    func testSingleChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func testChoseongJungseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    func testCompleteSyllable() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "간")
    }

    func testSequentialSyllables() {
        // 안녕
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        XCTAssertEqual(composer.currentComposingCharacter, "안")

        _ = composer.inputJungseong(.ㅕ)
        XCTAssertEqual(composer.composedText, "아")
        XCTAssertEqual(composer.currentComposingCharacter, "녀")

        _ = composer.inputChoseong(.ㅇ)
        XCTAssertEqual(composer.currentComposingCharacter, "녕")
    }

    // MARK: - Double Jongseong Tests

    func testDoubleJongseong() {
        // 값
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㅅ)
        XCTAssertEqual(composer.currentComposingCharacter, "값")
    }

    func testDoubleJongseongSplit() {
        // 읽다 -> 읽 + 다
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㄹ)
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.currentComposingCharacter, "읽")

        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.composedText, "일")
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    // MARK: - Delete Tests

    func testDeleteChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
    }

    func testDeleteJungseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.deleteBackward()
        // 순정 모아키 실측(영상 G5): 자소 단위 삭제 — 중성만 지우고 초성을 남긴다 (가→ㄱ)
        XCTAssertEqual(composer.state, .choseong(.ㄱ))
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    // MARK: - Backspace Behavior Tests (PR A)

    func test_backspace_choseongJungseong_leavesChoseong() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "이")
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        // 순정 모아키 실측(영상 G5): 이 → ㅇ (자소 단위)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅇ")
        XCTAssertEqual(composer.state, .choseong(.ㅇ))
    }

    /// 순정 실측(영상 G5): 중성은 천지인 획 되감기 없이 통째로 지워진다 —
    /// 개→ㄱ (ㅐ가 ㅏ로 되돌아가지 않음).
    func test_backspace_compoundJungseong_deletesWholeVowel() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputJungseong(.ㅣ)   // ㅏ+ㅣ=ㅐ
        XCTAssertEqual(composer.currentComposingCharacter, "개")
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.state, .choseong(.ㄱ))
    }

    func test_backspace_completeWithJongseong_removesJongseong() {
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)  // jongseong
        XCTAssertEqual(composer.currentComposingCharacter, "한")
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        XCTAssertEqual(composer.currentComposingCharacter, "하")
    }

    func test_backspace_choseongOnly_clearsState() {
        _ = composer.inputChoseong(.ㅎ)
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        XCTAssertNil(composer.currentComposingCharacter)
    }

    func test_backspace_choseongJungseongCompound_leavesChoseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅗ)
        _ = composer.inputJungseong(.ㅏ)  // ㅘ
        XCTAssertEqual(composer.currentComposingCharacter, "과")
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        // 순정 모아키 실측(영상 G3: 걔괴 →⌫ 걔ㄱ): 복합 중성도 통째로 지우고
        // 초성을 남긴다 — ㅘ→ㅗ 획 되감기 없음.
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
        XCTAssertEqual(composer.state, .choseong(.ㄱ))
    }

    func testDeleteJongseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    func testDeleteDoubleJongseong() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputChoseong(.ㅅ)
        XCTAssertEqual(composer.currentComposingCharacter, "값")

        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "갑")
    }

    // MARK: - Edge Cases

    func testDoubleConsonantCannotBeJongseong() {
        // ㄸ, ㅃ, ㅉ cannot be jongseong
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄸ)

        XCTAssertEqual(composer.composedText, "가")
        XCTAssertEqual(composer.currentComposingCharacter, "ㄸ")
    }

    func testVowelWithoutConsonant() {
        // PR G3: standalone vowels are now held pending so 천지인
        // sequences can compose. composedText stays empty until the
        // pending vowel is committed by another input.
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅏ")
        XCTAssertEqual(composer.composedText, "")
        XCTAssertEqual(composer.state, .standaloneVowel(.ㅏ))
    }

    // MARK: - Unicode Composition Tests

    func testUnicodeValues() {
        // 가 = 0xAC00
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter?.unicodeScalars.first?.value, 0xAC00)

        // 힣 = 0xD7A3 (last syllable)
        composer.reset()
        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㅎ)
        XCTAssertEqual(composer.currentComposingCharacter?.unicodeScalars.first?.value, 0xD7A3)
    }

    // MARK: - Complex Input Sequences

    func testHelloWorld() {
        // 안녕하세요 — standard 두벌식 IME requires the second ㄴ to commit
        // "안" before starting the "녀" syllable.
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅕ)
        _ = composer.inputChoseong(.ㅇ)

        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)

        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅔ)

        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅛ)

        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "안녕하세요")
    }

    func testThankYou() {
        // 감사합니다 — keys: ㄱㅏㅁ ㅅㅏ ㅎㅏㅂ ㄴㅣ ㄷㅏ
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅁ)

        _ = composer.inputChoseong(.ㅅ) // ㅁ+ㅅ no combine → commit "감"
        XCTAssertEqual(composer.composedText, "감")

        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅎ) // ㅎ as jongseong
        _ = composer.inputJungseong(.ㅏ) // splits → commit "사"
        XCTAssertEqual(composer.composedText, "감사")

        _ = composer.inputChoseong(.ㅂ) // ㅂ as jongseong
        _ = composer.inputChoseong(.ㄴ) // ㅂ+ㄴ no combine → commit "합"
        XCTAssertEqual(composer.composedText, "감사합")

        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputChoseong(.ㄷ) // ㄷ as jongseong
        _ = composer.inputJungseong(.ㅏ) // splits → commit "니"
        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "감사합니다")
    }

    // MARK: - Vowel Combination Tests (Cheonjiin Integration, PR E1)

    func test_combineVowels_aPlusI_yieldsAe() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)  // 아
        _ = composer.inputJungseong(.ㅣ)  // ㅏ+ㅣ → ㅐ → 애
        XCTAssertEqual(composer.currentComposingCharacter, "애")
    }

    func test_combineVowels_yaPlusI_yieldsYae() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅑ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "얘")
    }

    func test_combineVowels_eoPlusI_yieldsE() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅓ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "에")
    }

    func test_combineVowels_yeoPlusI_yieldsYe() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅕ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "예")
    }

    func test_combineVowels_oPlusA_yieldsWa_stillWorks() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅗ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter, "과")
    }

    // MARK: - Cheonjiin Standalone Vowel Composition (PR G3)

    func test_standalone_eu_pendingThenI_yieldsUi() {
        _ = composer.inputJungseong(.ㅡ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅡ")
        XCTAssertTrue(composer.composedText.isEmpty)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅢ")
    }

    func test_standalone_iPlusDot_yieldsA() {
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅏ")
    }

    func test_standalone_dotPlusI_yieldsEo() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅓ")
    }

    func test_standalone_dotPlusEu_yieldsO() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅡ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅗ")
    }

    func test_standalone_euPlusDot_yieldsU() {
        _ = composer.inputJungseong(.ㅡ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅜ")
    }

    func test_standalone_iDotDot_yieldsYa() {
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputJungseong(.ㆍ)  // ㅏ
        _ = composer.inputJungseong(.ㆍ)  // ㅑ
        XCTAssertEqual(composer.currentComposingCharacter, "ㅑ")
    }

    func test_standalone_iDotI_yieldsAe() {
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputJungseong(.ㆍ)  // ㅏ
        _ = composer.inputJungseong(.ㅣ)  // ㅐ
        XCTAssertEqual(composer.currentComposingCharacter, "ㅐ")
    }

    // MARK: - ㆍ 무한 토글 (순정 adb 실측 2026-08-14, 실기기 체크리스트 a6)

    func test_aePlusDot_togglesYaeAndBack() {
        // 애 + ㆍ = 얘, 얘 + ㆍ = 애 … 무한 토글 (갤럭시 순정 모아키 실측).
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅐ)
        XCTAssertEqual(composer.currentComposingCharacter, "애")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "얘")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "애")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "얘")
        XCTAssertTrue(composer.composedText.isEmpty, "토글 중 커밋되면 안 됨")
    }

    func test_ePlusDot_togglesYeAndBack() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅔ)
        XCTAssertEqual(composer.currentComposingCharacter, "에")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "예")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "에")
        XCTAssertTrue(composer.composedText.isEmpty)
    }

    func test_oePlusDot_becomesWa_thenIMakesWae() {
        // 천지인 표준: ㅚ+ㆍ=ㅘ (ㅗ+[ㅣ+ㆍ=ㅏ]) — 순정 adb 실측 (외→와).
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅚ)
        XCTAssertEqual(composer.currentComposingCharacter, "외")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "와")
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "왜", "ㅘ+ㅣ=ㅙ 체인 연결")
        XCTAssertTrue(composer.composedText.isEmpty)
    }

    func test_wiPlusDot_becomesWo_thenIMakesWe() {
        // 대칭: ㅟ+ㆍ=ㅝ — 순정 adb 실측 (위→워).
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅟ)
        XCTAssertEqual(composer.currentComposingCharacter, "위")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "워")
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "웨", "ㅝ+ㅣ=ㅞ 체인 연결")
    }

    func test_euiPlusDot_commitsAndStartsDotPending() {
        // 순정은 ㅢ+ㆍ 에서 옛한글 ㅡㅏ 를 만든다(adb 실측) — 현대 한글 밖이라
        // 재현하지 않고, 의 커밋 + ㆍ pending 으로 둔다 (기존 동작 고정).
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅢ)
        XCTAssertEqual(composer.currentComposingCharacter, "의")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.composedText, "의", "의는 커밋")
        XCTAssertEqual(composer.state, .dotPending(choseong: nil, dotCount: 1))
    }

    func test_standaloneAePlusDot_togglesYae() {
        // 자음 없는 standalone 경로도 동일 규칙.
        _ = composer.inputJungseong(.ㅐ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅒ")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅐ")
    }

    // MARK: ㅏ↔ㅑ / ㅓ↔ㅕ 토글 (실기기 제보 2026-08-18)
    //
    // 제보: "ㅣ ㆍ ㆍ 로 ㅣ→ㅏ→ㅑ 까지는 되는데, ㅑ 에서 ㆍ 를 한 번 더 누르면
    // ㅏ 로 회귀하지 않고 ㅑㆍ 로 붙어버린다." 정방향(ㅏ+ㆍ=ㅑ)만 있고 역방향이
    // 빠져 있어 `combineVowels` 가 nil 을 돌려주고 ㅑ 가 커밋됐다.

    func test_standalone_iDotDotDot_togglesBackToA() {
        // 제보 시나리오 그대로: ㅣ → ㅏ → ㅑ → ㅏ → ㅑ …
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅣ")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅏ")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅑ")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅏ", "ㅑ + ㆍ = ㅏ 로 회귀해야 함")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅑ")
        XCTAssertTrue(composer.composedText.isEmpty, "토글 중 커밋되면 안 됨 (ㅑㆍ 로 떨어지던 증상)")
    }

    func test_aPlusDot_togglesYaAndBack() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        XCTAssertEqual(composer.currentComposingCharacter, "아")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "야")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "아")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "야")
        XCTAssertTrue(composer.composedText.isEmpty)
    }

    func test_eoPlusDot_togglesYeoAndBack() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅓ)
        XCTAssertEqual(composer.currentComposingCharacter, "어")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "여")
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "어")
        XCTAssertTrue(composer.composedText.isEmpty)
    }

    /// base ↔ y 6쌍 전체의 대칭성을 한 번에 고정한다. 이 표가 반쪽만 채워지면
    /// (ㅏ→ㅑ 는 되는데 ㅑ→ㅏ 는 안 되는 식) ㆍ 연타가 조용히 끊겨 커밋된다.
    func test_dotToggle_everyBaseYPairRoundTrips() {
        let pairs: [(base: Jungseong, y: Jungseong)] = [
            (.ㅏ, .ㅑ), (.ㅓ, .ㅕ), (.ㅗ, .ㅛ), (.ㅜ, .ㅠ), (.ㅐ, .ㅒ), (.ㅔ, .ㅖ)
        ]
        for pair in pairs {
            // `currentComposingCharacter` 는 `Character?` 다 — 기대값도 같은 타입으로
            // 못 박아야 XCTAssertEqual 의 제네릭 추론이 갈리지 않는다.
            let expectedBase: Character? = pair.base.compatibilityCharacter
            let expectedY: Character? = pair.y.compatibilityCharacter
            let baseText = String(pair.base.compatibilityCharacter)
            let yText = String(pair.y.compatibilityCharacter)
            let c = HangulComposer()

            _ = c.inputJungseong(pair.base)
            _ = c.inputJungseong(.ㆍ)
            XCTAssertEqual(c.currentComposingCharacter, expectedY, baseText + " + ㆍ = " + yText)

            _ = c.inputJungseong(.ㆍ)
            XCTAssertEqual(c.currentComposingCharacter, expectedBase, yText + " + ㆍ = " + baseText + " 로 회귀")

            XCTAssertTrue(c.composedText.isEmpty, baseText + "↔" + yText + " 토글 중 커밋되면 안 됨")
        }
    }

    func test_standalone_dotDotI_yieldsYeo() {
        // PR G5: ㆍ accumulates in dotPending. ㆍ+ㆍ+ㅣ → ㅕ (천지인 3-stroke).
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertTrue(composer.composedText.isEmpty)
        XCTAssertEqual(composer.displayText, "ㆍㆍ")
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅕ")
    }

    func test_standalone_euEu_separatesIntoTwo() {
        _ = composer.inputJungseong(.ㅡ)
        _ = composer.inputJungseong(.ㅡ)
        // Same vowel doesn't combine: first commits, second pends.
        XCTAssertEqual(composer.composedText, "ㅡ")
        XCTAssertEqual(composer.currentComposingCharacter, "ㅡ")
    }

    func test_standalone_uPlusU_separatesIntoTwo() {
        _ = composer.inputJungseong(.ㅜ)
        _ = composer.inputJungseong(.ㅜ)
        XCTAssertEqual(composer.composedText, "ㅜ")
        XCTAssertEqual(composer.currentComposingCharacter, "ㅜ")
    }

    func test_standalone_thenChoseong_commitsVowel() {
        _ = composer.inputJungseong(.ㅡ)
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.composedText, "ㅡ")
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func test_standalone_backspace_clearsState() {
        _ = composer.inputJungseong(.ㅡ)
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        XCTAssertNil(composer.currentComposingCharacter)
        XCTAssertTrue(composer.composedText.isEmpty)
        XCTAssertEqual(composer.state, .empty)
    }

    func test_choseongPlusEuPlusI_yieldsGwi() {
        // 자음 + ㅡ + ㅣ → 긔 (combineVowels(.ㅡ, .ㅣ) = .ㅢ)
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅡ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "긔")
    }

    func test_choseongPlusDot_holdsAsDotPending() {
        // PR G5: 자음 + ㆍ → dotPending(cho, 1). composedText 비고
        // displayText 는 "ㄱㆍ". 후속 ㅣ/ㅡ/ㆍ 가 누적/합성 가능하도록.
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertTrue(composer.composedText.isEmpty)
        XCTAssertEqual(composer.displayText, "ㄱㆍ")
    }

    func test_choseongJungseongPlusDot_combinesIntoY() {
        // ㄱ + ㅏ + ㆍ → 갸
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "갸")
    }

    func test_choseongIPlusDot_yieldsGa() {
        // ㄱ + ㅣ + ㆍ → 가 (combineVowels(.ㅣ, .ㆍ) = .ㅏ)
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅣ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.currentComposingCharacter, "가")
    }

    // MARK: - 3-Stroke Cheonjiin (PR G5)

    func test_dotI_yieldsEo() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅓ")
    }

    func test_dotEu_yieldsO() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅡ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅗ")
    }

    func test_dotDotI_yieldsYeo() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅕ")
    }

    func test_dotDotEu_yieldsYo() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅡ)
        XCTAssertEqual(composer.currentComposingCharacter, "ㅛ")
    }

    func test_choseongDotI_yieldsEoSyllable() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "어")
    }

    func test_choseongDotEu_yieldsOSyllable() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅡ)
        XCTAssertEqual(composer.currentComposingCharacter, "오")
    }

    func test_choseongDotDotI_yieldsYeoSyllable() {
        // 사용자 보고 케이스: ㅇ + ㆍ + ㆍ + ㅣ → 여
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "여")
    }

    func test_choseongDotDotEu_yieldsYo() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㅡ)
        XCTAssertEqual(composer.currentComposingCharacter, "요")
    }

    func test_dotPending_backspace_decreasesDotCount() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.displayText, "ㆍㆍ")
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.displayText, "ㆍ")
        _ = composer.deleteBackward()
        XCTAssertNil(composer.currentComposingCharacter)
        XCTAssertEqual(composer.state, .empty)
    }

    func test_choseongDotPending_backspace_returnsToChoseong() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.displayText, "ㅇㆍ")
        _ = composer.deleteBackward()
        XCTAssertEqual(composer.currentComposingCharacter, "ㅇ")
    }

    func test_dotPending_thenChoseong_commitsRawDots() {
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.composedText, "ㆍㆍ")
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func test_choseongDotPending_thenChoseong_commitsConsonantAndDots() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputChoseong(.ㄱ)
        XCTAssertEqual(composer.composedText, "ㅇㆍ")
        XCTAssertEqual(composer.currentComposingCharacter, "ㄱ")
    }

    func test_tripleDot_commitsAndRestarts() {
        // 4번째 ㆍ는 표준 패턴 없음 → ㆍㆍ commit + 새 dotPending(1)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        _ = composer.inputJungseong(.ㆍ)
        XCTAssertEqual(composer.composedText, "ㆍㆍ")
        XCTAssertEqual(composer.displayText, "ㆍㆍㆍ")
    }
}

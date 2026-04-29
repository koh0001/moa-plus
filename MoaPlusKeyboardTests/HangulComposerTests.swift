import XCTest
@testable import MoaPlusKeyboard

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
        // NEW BEHAVIOR: 받침 없는 글자에서 ⌫ → 글자 전체 삭제
        XCTAssertEqual(composer.state, .empty)
        XCTAssertNil(composer.currentComposingCharacter)
    }

    // MARK: - Backspace Behavior Tests (PR A)

    func test_backspace_choseongJungseong_clearsState() {
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅣ)
        XCTAssertEqual(composer.currentComposingCharacter, "이")
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        XCTAssertNil(composer.currentComposingCharacter)
        XCTAssertEqual(composer.state, .empty)
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

    func test_backspace_choseongJungseongCompound_clearsState() {
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅗ)
        _ = composer.inputJungseong(.ㅏ)  // ㅘ
        XCTAssertEqual(composer.currentComposingCharacter, "과")
        let action = composer.deleteBackward()
        XCTAssertEqual(action, .update)
        XCTAssertNil(composer.currentComposingCharacter)
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
        // 안녕하세요
        let inputs: [(Choseong?, Jungseong?)] = [
            (.ㅇ, .ㅏ), (nil, nil), // 아 + ㄴ (next)
            (.ㄴ, nil), // attached as jongseong
            (nil, .ㅕ), // splits to 안 + 녀
            (.ㅇ, nil), // 녕
            (nil, nil), // commit
            (.ㅎ, .ㅏ), // 하
            (.ㅅ, nil), // 세 (next syllable start)
            (nil, .ㅔ), // 세
            (.ㅇ, nil), // jongseong? no, starts new: 세 + ㅇ
            (nil, .ㅛ), // 셍? no - 세요
        ]

        // Simplified test
        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅕ)
        _ = composer.inputChoseong(.ㅇ)

        composer.commitCurrent()

        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)

        composer.commitCurrent()

        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅔ)

        composer.commitCurrent()

        _ = composer.inputChoseong(.ㅇ)
        _ = composer.inputJungseong(.ㅛ)

        composer.commitCurrent()

        XCTAssertEqual(composer.composedText, "안녕하세요")
    }

    func testThankYou() {
        // 감사합니다
        _ = composer.inputChoseong(.ㄱ)
        _ = composer.inputJungseong(.ㅏ)
        _ = composer.inputChoseong(.ㅁ)
        _ = composer.inputJungseong(.ㅏ)

        XCTAssertEqual(composer.composedText, "가")

        _ = composer.inputChoseong(.ㅅ)
        _ = composer.inputJungseong(.ㅏ)

        XCTAssertEqual(composer.composedText, "감")

        _ = composer.inputChoseong(.ㅎ)
        _ = composer.inputJungseong(.ㅏ)

        XCTAssertEqual(composer.composedText, "감사")

        _ = composer.inputChoseong(.ㅂ)
        _ = composer.inputJungseong(.ㅣ)

        XCTAssertEqual(composer.composedText, "감사하")

        _ = composer.inputChoseong(.ㄴ)
        _ = composer.inputJungseong(.ㅏ)

        XCTAssertEqual(composer.composedText, "감사합")

        _ = composer.inputChoseong(.ㄷ)
        _ = composer.inputJungseong(.ㅏ)

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

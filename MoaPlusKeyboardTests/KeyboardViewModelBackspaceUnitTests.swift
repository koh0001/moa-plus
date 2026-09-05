import XCTest
@testable import MoaPlusKeyboard

/// 백스페이스 삭제 단위 옵션(`backspaceDeletesWholeSyllable`) — 앱스토어 리뷰 제보.
/// 뷰모델이 설정을 읽어 컴포저에 넘기는 배선과 설정 저장/기본값을 가드한다.
final class KeyboardViewModelBackspaceUnitTests: XCTestCase {

    private static let suite = KeyboardSettings.appGroupId
    private static let key = "backspaceDeletesWholeSyllable"

    private func withWholeSyllable(_ on: Bool, _ body: (KeyboardViewModel) -> Void) {
        let original = KeyboardSettings.shared.backspaceDeletesWholeSyllable
        defer { KeyboardSettings.shared.backspaceDeletesWholeSyllable = original }
        KeyboardSettings.shared.backspaceDeletesWholeSyllable = on
        body(KeyboardViewModel())
    }

    // MARK: - 설정

    func test_setting_defaultsToJamoUnit() {
        let s = KeyboardSettings.shared
        let original = s.backspaceDeletesWholeSyllable
        defer { s.backspaceDeletesWholeSyllable = original }
        UserDefaults(suiteName: Self.suite)?.removeObject(forKey: Self.key)
        s.loadAll()
        XCTAssertFalse(s.backspaceDeletesWholeSyllable,
                       "저장값이 없으면 자소 단위(순정) — 기본값을 바꾸면 기존 사용자의 백스페이스가 달라진다")
    }

    func test_setting_roundTripsThroughLoadAll() {
        let s = KeyboardSettings.shared
        let original = s.backspaceDeletesWholeSyllable
        defer { s.backspaceDeletesWholeSyllable = original }
        s.backspaceDeletesWholeSyllable = true
        s.loadAll()
        XCTAssertTrue(s.backspaceDeletesWholeSyllable)
    }

    // MARK: - 뷰모델 배선

    func test_wholeSyllable_deletesComposingSyllableAtOnce() {
        withWholeSyllable(true) { vm in
            vm.inputConsonant(.ㄱ)
            vm.inputVowel(.ㅏ)
            XCTAssertEqual(vm.composingText, "가")
            vm.deleteBackward()
            XCTAssertEqual(vm.composingText, "", "글자 단위: 한 번에 가 → (빈)")
        }
    }

    func test_jamoUnit_leavesChoseong() {
        withWholeSyllable(false) { vm in
            vm.inputConsonant(.ㄱ)
            vm.inputVowel(.ㅏ)
            vm.deleteBackward()
            XCTAssertEqual(vm.composingText, "ㄱ", "기본(자소 단위): 가 → ㄱ")
        }
    }

    func test_wholeSyllable_jongseongFirstThenSyllable() {
        withWholeSyllable(true) { vm in
            vm.inputConsonant(.ㅎ)
            vm.inputVowel(.ㅏ)
            vm.inputConsonant(.ㄴ)
            XCTAssertEqual(vm.composingText, "한")
            vm.deleteBackward()
            XCTAssertEqual(vm.composingText, "하")
            vm.deleteBackward()
            XCTAssertEqual(vm.composingText, "")
        }
    }
}

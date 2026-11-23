import XCTest

/// 긋기 미리보기에 조합될 글자를 함께 보여 준다 (앱스토어 리뷰 "팝업 기능 제안" 2026-11).
/// 글자는 `previewVowel` setter 가 같이 갱신하므로 모음과 어긋나지 않아야 한다.
final class KeyboardViewModelPreviewSyllableTests: XCTestCase {
    private var vm: KeyboardViewModel!
    private static let origin = CGPoint(x: 100, y: 100)

    override func setUp() {
        super.setUp()
        vm = KeyboardViewModel()
        vm.keyboardMode = .korean
    }

    override func tearDown() {
        vm = nil
        super.tearDown()
    }

    /// ㄱ(1행 4열, 모든 프리셋 공통)에서 오른쪽으로 길게 → ㅏ, 글자는 가.
    func test_consonantKey_rightSwipe_previewsSyllable() {
        vm.gestureStarted(row: 1, column: 4, at: Self.origin)
        XCTAssertNil(vm.gestureState.previewSyllable)
        vm.gestureMoved(row: 1, column: 4, to: CGPoint(x: Self.origin.x + 200, y: Self.origin.y))
        XCTAssertEqual(vm.gestureState.previewVowel, .ㅏ)
        XCTAssertEqual(vm.gestureState.previewSyllable, "가")
    }

    func test_release_clearsSyllableWithVowel() {
        vm.gestureStarted(row: 1, column: 4, at: Self.origin)
        vm.gestureMoved(row: 1, column: 4, to: CGPoint(x: Self.origin.x + 200, y: Self.origin.y))
        vm.gestureEnded(row: 1, column: 4)
        XCTAssertNil(vm.gestureState.previewVowel)
        XCTAssertNil(vm.gestureState.previewSyllable)
    }

    /// 모음 키(슬롯 B)는 자음이 없으니 글자 없이 모음만 — 그리드 자음을 누른 채 모음 키로 넘어가도(롤오버) 앞 자음이 남지 않는다.
    func test_slotBVowelKey_neverShowsSyllable_evenAfterHeldConsonant() {
        vm.slotBVowelGestureStarted(at: Self.origin)
        vm.slotBVowelGestureMoved(to: CGPoint(x: Self.origin.x + 200, y: Self.origin.y))
        XCTAssertNotNil(vm.gestureState.previewVowel)
        XCTAssertNil(vm.gestureState.previewSyllable)
        vm.slotBVowelGestureEnded()

        vm.gestureStarted(row: 1, column: 4, at: Self.origin)
        vm.slotBVowelGestureStarted(at: Self.origin)
        vm.slotBVowelGestureMoved(to: CGPoint(x: Self.origin.x + 200, y: Self.origin.y))
        XCTAssertNotNil(vm.gestureState.previewVowel)
        XCTAssertNil(vm.gestureState.previewSyllable, "ㄱ 을 누른 채 모음 키 — '가' 가 남으면 안 된다")
        vm.slotBVowelGestureEnded()
    }
}

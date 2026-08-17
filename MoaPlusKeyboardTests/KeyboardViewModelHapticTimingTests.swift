import XCTest
import CoreGraphics

/// 햅틱 발생 **시점** 회귀 테스트 (GitHub 이슈 #23).
///
/// 이전에는 모든 햅틱이 입력이 확정되는 시점, 즉 손을 뗄 때 울렸다. 모아+ 는 긋기
/// 키보드라 손가락이 붙어 있는 시간이 길어서, 획을 긋는 내내 아무 반응이 없다가
/// 마지막에 한 번 울리는 것이 "반응이 늦다" 로 체감됐다.
///
/// 규칙: **키 하나에 진동 하나, 누르는 순간에.** 획이 끝날 때 다시 울리지 않는다.
/// 백스페이스만 예외로 `deleteBackward()` 안에 남아 있다 — 누른 즉시 한 글자 지우고
/// 자동 반복으로 이어지므로 반복 틱마다 울려야 한다.
final class KeyboardViewModelHapticTimingTests: XCTestCase {
    private var viewModel: KeyboardViewModel!
    private var delegate: HapticCountingDelegate!

    override func setUp() {
        super.setUp()
        delegate = HapticCountingDelegate()
        viewModel = KeyboardViewModel()
        viewModel.delegate = delegate
    }

    override func tearDown() {
        viewModel = nil
        delegate = nil
        super.tearDown()
    }

    /// 그리드 키를 누르는 순간 울리고, 입력이 확정될 때는 다시 울리지 않는다.
    func testGridKey_buzzesOnPress_notAgainOnRelease() {
        viewModel.gestureStarted(row: 1, column: 3, at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(delegate.hapticCount, 1, "누르는 순간 한 번 울려야 한다")

        viewModel.inputConsonant(.ㄱ)
        XCTAssertEqual(delegate.hapticCount, 1, "입력 확정 시점에는 다시 울리지 않는다")
    }

    /// 획을 길게 그어도 진동은 누를 때 한 번뿐이다.
    func testGridKey_longSwipe_buzzesOnlyOnce() {
        viewModel.gestureStarted(row: 1, column: 3, at: CGPoint(x: 10, y: 10))
        for x in stride(from: 20, through: 120, by: 10) {
            viewModel.gestureMoved(to: CGPoint(x: CGFloat(x), y: 10))
        }
        viewModel.inputVowel(.ㅏ)

        XCTAssertEqual(delegate.hapticCount, 1, "획 중간이나 끝에서 추가로 울리면 안 된다")
    }

    /// 슬롯B 모음 키도 누르는 순간 울린다.
    func testSlotBVowelKey_buzzesOnPress() {
        viewModel.slotBVowelGestureStarted(at: CGPoint(x: 10, y: 10))
        XCTAssertEqual(delegate.hapticCount, 1)
    }

    /// 설정 화면 미리보기 키보드는 울리지 않는다.
    func testPreviewMode_doesNotBuzz() {
        viewModel.previewMode = true

        viewModel.gestureStarted(row: 1, column: 3, at: CGPoint(x: 10, y: 10))
        viewModel.keyPressFeedback()

        XCTAssertEqual(delegate.hapticCount, 0, "미리보기에서는 진동을 울리지 않는다")
    }

    /// 백스페이스는 누른 즉시 지우면서 울린다 (자동 반복 틱도 같은 경로를 탄다).
    func testBackspace_buzzesOnPress() {
        viewModel.beginBackspacePress()
        XCTAssertEqual(delegate.hapticCount, 1, "백스페이스도 누른 즉시 울려야 한다")
        viewModel.endBackspacePress()
    }

    /// 스페이스·엔터 같은 기능행 키는 뷰가 누름 시점에 `keyPressFeedback()` 을 부르고,
    /// 입력 메서드 자체는 더 이상 울리지 않는다. 뷰 없이 입력 메서드만 호출해 확인한다.
    func testFunctionKeys_inputMethodsDoNotBuzz() {
        viewModel.inputSpace()
        viewModel.inputReturn()
        viewModel.inputSymbol(".")
        viewModel.toggleLetterMode()
        viewModel.toggleSymbolMode()

        XCTAssertEqual(delegate.hapticCount, 0,
                       "입력 확정 경로에는 진동이 남아 있으면 안 된다 (누름 시점에서만 울린다)")
    }
}

/// 햅틱 호출 횟수만 세는 델리게이트.
private final class HapticCountingDelegate: KeyboardViewModelDelegate {
    private(set) var text: String = ""
    private(set) var hapticCount = 0

    func insertText(_ string: String) { text.append(string) }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }

    func updateComposingText(from previous: String, to current: String) {
        for _ in previous where !text.isEmpty { text.removeLast() }
        text.append(current)
    }

    func switchToNextKeyboard() {}
    func triggerHapticFeedback() { hapticCount += 1 }
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { text }
}

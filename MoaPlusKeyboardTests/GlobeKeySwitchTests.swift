import XCTest
import SwiftUI
@testable import MoaPlusKeyboard

/// 지구본(키보드 전환) 키 배선 검증.
/// v1.8.0 까지 `KeyboardViewModel.switchKeyboard()` 는 어떤 뷰에서도 호출되지
/// 않아 사용자가 모아+에서 다른 키보드로 나갈 방법이 없었다(앱스토어 리뷰 2건).
/// 여기서 고정하는 것은 "탭 → 델리게이트까지 도달" 까지다. 실제 키보드 전환은
/// `advanceToNextInputMode()` 라는 iOS 시스템 호출이라 유닛 테스트 범위 밖.
final class GlobeKeySwitchTests: XCTestCase {

    private var viewModel: KeyboardViewModel!
    private var delegate: MockSwitchDelegate!

    override func setUp() {
        super.setUp()
        viewModel = KeyboardViewModel()
        delegate = MockSwitchDelegate()
        viewModel.delegate = delegate
    }

    func test_switchKeyboard_reachesDelegate() {
        viewModel.switchKeyboard()
        XCTAssertEqual(delegate.switchKeyboardCount, 1)
    }

    /// 조합 중이던 글자는 전환 전에 확정돼야 한다. 확정하지 않으면 다른
    /// 키보드를 거쳐 돌아왔을 때 조합 상태가 남아 다음 입력에서 되살아난다
    /// (v1.7.2 커서 탭 중복 삽입과 같은 계열의 실패).
    /// `commitCurrent()` 는 proxy 를 건드리지 않으므로, 확정 여부는 "다음 입력이
    /// 빈 상태에서 시작하는가"로 관찰한다.
    func test_switchKeyboard_commitsInProgressComposition() {
        viewModel.inputConsonant(.ㄱ)
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㄱ", "사전 조건: 조합 중")

        viewModel.switchKeyboard()
        XCTAssertEqual(delegate.switchKeyboardCount, 1)

        delegate.composingUpdates.removeAll()
        viewModel.inputConsonant(.ㄴ)
        XCTAssertEqual(delegate.composingUpdates.first?.previous, "",
                       "전환 시 조합이 확정되지 않아 ㄱ 이 되살아남")
        XCTAssertEqual(delegate.composingUpdates.last?.current, "ㄴ")
    }

    /// 뷰모델 기본값은 호스트 앱 미리보기용 true. 익스텐션에서는
    /// `KeyboardViewController` 가 `needsInputModeSwitchKey` 로 덮어쓴다.
    func test_canSwitchInputMode_defaultsTrueForHostPreview() {
        XCTAssertTrue(KeyboardViewModel().canSwitchInputMode)
    }
}

private final class MockSwitchDelegate: KeyboardViewModelDelegate {
    struct ComposingUpdate: Equatable {
        let previous: String
        let current: String
    }

    var switchKeyboardCount = 0
    var insertedTexts: [String] = []
    var composingUpdates: [ComposingUpdate] = []

    func insertText(_ text: String) { insertedTexts.append(text) }
    func deleteBackward() {}
    func updateComposingText(from previous: String, to current: String) {
        composingUpdates.append(.init(previous: previous, current: current))
    }
    func switchToNextKeyboard() { switchKeyboardCount += 1 }
    func triggerHapticFeedback() {}
    func moveCursor(by offset: Int) {}
}

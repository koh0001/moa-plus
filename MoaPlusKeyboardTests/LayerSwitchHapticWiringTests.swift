import XCTest
import SwiftUI
@testable import MoaPlusKeyboard

/// 레이어 전환 햅틱(이슈 #41)의 **뷰 배선** 가드.
///
/// 뷰모델 쪽(`layerSwitchPressFeedback()`)은 `KeyboardViewModelHapticTimingTests` 가 본다. 하지만
/// 실제 키에 닿으려면 두 군데가 더 맞아야 한다 — 기능행이 레이어 키를 `pressFeedback: .layerSwitch`
/// 로 만들 것, `KeyboardView` 가 환경 값 `layerSwitchPressFeedback` 을 주입할 것. 둘 중 하나만
/// 빠져도 레이어 키가 조용해지거나(환경 기본값 no-op) 탭 햅틱으로 돌아가는데, 뷰모델 테스트는
/// 그대로 통과한다 ("설정은 저장되는데 키보드가 안 읽는" 계열). 손가락 누름은 단위 테스트에서
/// 흉내 낼 수 없으므로 뷰 값 트리를 `Mirror` 로 훑어 배선 자체를 확인한다.
final class LayerSwitchHapticWiringTests: XCTestCase {

    // MARK: - 기능행: 레이어 키 = .layerSwitch, 나머지 기능키 = .tap

    private func row(mode: KeyboardMode,
                     showGlobeKey: Bool = true,
                     slotA: SlotAPreset = .vowel,
                     koreanPunctuationEnabled: Bool = true,
                     bimanual: Bool = false) -> FunctionRowView {
        var customization = LayoutCustomization()
        customization.slotA = slotA
        customization.koreanPunctuationEnabled = koreanPunctuationEnabled
        customization.englishPunctuationEnabled = true
        return FunctionRowView(
            totalWidth: 393,
            mode: mode,
            onToggleSymbolPressed: {},
            onToggleLetterPressed: {},
            onSpacePressed: {},
            onPunctuation: { _ in },
            onReturnPressed: {},
            showGlobeKey: showGlobeKey,
            useBimanualLayout: bimanual,
            layoutCustomization: customization
        )
    }

    /// 지금 바디가 실제로 그리는 `FunctionKeyView` 들.
    private func functionKeys(in view: FunctionRowView) -> [FunctionKeyView] {
        var found: [FunctionKeyView] = []
        collect(FunctionKeyView.self, in: view.body, into: &found)
        return found
    }

    /// 바디마다 레이어 키 수(123/한글 · 한/영, 심볼 모드면 #+=/123 까지)와 나머지(⏎ · 🌐)를 센다.
    /// 레이어 키 하나라도 `.tap` 으로 돌아가면 `.layerSwitch` 수가 줄어 실패한다.
    private func assertFeedback(_ view: FunctionRowView,
                                kind: FunctionRowView.BodyKind,
                                layerKeys: Int,
                                tapKeys: Int,
                                _ label: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(view.activeBodyKind, kind, "\(label): 기대와 다른 바디", file: file, line: line)
        let keys = functionKeys(in: view)
        XCTAssertEqual(keys.filter { $0.pressFeedback == .layerSwitch }.count, layerKeys,
                       "\(label): 레이어 전환 햅틱을 내는 키 수", file: file, line: line)
        XCTAssertEqual(keys.filter { $0.pressFeedback == .tap }.count, tapKeys,
                       "\(label): 탭 햅틱을 내는 기능키 수(⏎ · 🌐)", file: file, line: line)
    }

    func test_defaultBody_layerKeysUseLayerSwitchFeedback() {
        assertFeedback(row(mode: .korean), kind: .default, layerKeys: 2, tapKeys: 2, "기본 · 지구본")
        assertFeedback(row(mode: .english, showGlobeKey: false), kind: .default,
                       layerKeys: 2, tapKeys: 1, "기본 · 영문")
    }

    func test_symbolBody_includesSymbolPageToggle() {
        assertFeedback(row(mode: .symbolFromKorean), kind: .symbol, layerKeys: 3, tapKeys: 2, "심볼 · 지구본")
        assertFeedback(row(mode: .symbolFromEnglish, showGlobeKey: false), kind: .symbol,
                       layerKeys: 3, tapKeys: 1, "심볼")
    }

    func test_longSpaceBody_layerKeysUseLayerSwitchFeedback() {
        assertFeedback(row(mode: .korean, slotA: .fullPackage), kind: .longSpace,
                       layerKeys: 2, tapKeys: 2, "긴 스페이스 · 확장형")
        assertFeedback(row(mode: .korean, showGlobeKey: false, koreanPunctuationEnabled: false),
                       kind: .longSpace, layerKeys: 2, tapKeys: 1, "긴 스페이스 · 펑크 끔")
    }

    func test_bimanualBody_layerKeysUseLayerSwitchFeedback() {
        assertFeedback(row(mode: .korean, bimanual: true), kind: .bimanual,
                       layerKeys: 2, tapKeys: 2, "양손")
        assertFeedback(row(mode: .symbolFromKorean, showGlobeKey: false, bimanual: true), kind: .bimanual,
                       layerKeys: 3, tapKeys: 1, "양손 · 심볼")
    }

    // MARK: - FunctionKeyView: 종류 → 클로저

    /// 기능행이 고른 종류를 키가 맞는 클로저로 바꾸는지 — 두 갈래가 뒤바뀌면 위 개수 테스트와
    /// 아래 주입 테스트는 그대로 통과하면서 모든 기능키가 엉뚱한 진동을 낸다.
    func test_functionKey_pressFeedbackKind_callsMatchingClosure() {
        var tap = 0
        var layer = 0
        FunctionKeyView.pressFeedbackAction(for: .tap, tap: { tap += 1 }, layerSwitch: { layer += 1 })()
        XCTAssertEqual(tap, 1)
        XCTAssertEqual(layer, 0)
        FunctionKeyView.pressFeedbackAction(for: .layerSwitch, tap: { tap += 1 }, layerSwitch: { layer += 1 })()
        XCTAssertEqual(tap, 1, "레이어 전환 키가 탭 진동을 냈다")
        XCTAssertEqual(layer, 1)
    }

    // MARK: - KeyboardView: 환경 값 주입

    /// 한계: `Mirror` 는 `GeometryReader` 클로저 안을 못 본다 — 본문 최상위 수정자 체인만 확인한다.
    /// 주입을 그 안이나 자식 뷰로 옮기면 이 테스트가 "주입하지 않는다" 로 실패하고(동작은 정상),
    /// 안쪽에서 같은 키를 덮어써도 이 테스트는 잡지 못한다.

    /// `KeyboardView` 가 주입한 두 누름 피드백이 뷰모델의 해당 햅틱으로 이어지는지.
    /// `.environment(\.layerSwitchPressFeedback)` 줄을 지우면 기본값(no-op)이 실려 레이어 키가 조용해진다.
    @MainActor
    func test_keyboardView_injectsPressFeedbackClosures() throws {
        let vm = KeyboardViewModel()
        let spy = FeedbackCountingDelegate()
        vm.delegate = spy
        let view = KeyboardView(viewModel: vm, gestureState: vm.gestureState, popupState: vm.popupState)

        let writers = environmentClosures(in: view.body)
        let layer = try XCTUnwrap(writers.first { $0.keyPath == \EnvironmentValues.layerSwitchPressFeedback },
                                  "KeyboardView 가 layerSwitchPressFeedback 을 주입하지 않는다")
        let tap = try XCTUnwrap(writers.first { $0.keyPath == \EnvironmentValues.keyPressFeedback },
                                "KeyboardView 가 keyPressFeedback 을 주입하지 않는다")

        layer.value()
        XCTAssertEqual(spy.layerSwitchCount, 1, "레이어 키 누름이 레이어 전환 햅틱으로 가야 한다")
        XCTAssertEqual(spy.hapticCount, 0, "레이어 키 누름이 탭 햅틱까지 울렸다")

        tap.value()
        XCTAssertEqual(spy.hapticCount, 1)
        XCTAssertEqual(spy.layerSwitchCount, 1)
    }

    // MARK: - Mirror helpers

    private func collect<T>(_ type: T.Type, in value: Any, depth: Int = 0, into found: inout [T]) {
        if let hit = value as? T {
            found.append(hit)
            return
        }
        guard depth < 64 else { return }
        for child in Mirror(reflecting: value).children {
            collect(type, in: child.value, depth: depth + 1, into: &found)
        }
    }

    private typealias Writer = (keyPath: WritableKeyPath<EnvironmentValues, () -> Void>, value: () -> Void)

    /// `.environment(\.x, value)` 가 만든 수정자(`keyPath` + `value` 를 가진 노드) 중 값이 클로저인 것.
    private func environmentClosures(in value: Any, depth: Int = 0) -> [Writer] {
        let mirror = Mirror(reflecting: value)
        var found: [Writer] = []
        let children = Dictionary(mirror.children.compactMap { child in child.label.map { ($0, child.value) } },
                                  uniquingKeysWith: { first, _ in first })
        if let keyPath = children["keyPath"] as? WritableKeyPath<EnvironmentValues, () -> Void>,
           let closure = children["value"] as? () -> Void {
            found.append((keyPath, closure))
        }
        guard depth < 64 else { return found }
        for child in mirror.children {
            found += environmentClosures(in: child.value, depth: depth + 1)
        }
        return found
    }
}

/// 햅틱 종류별 호출 횟수만 세는 델리게이트.
private final class FeedbackCountingDelegate: KeyboardViewModelDelegate {
    private(set) var hapticCount = 0
    private(set) var layerSwitchCount = 0

    func insertText(_ string: String) {}
    func deleteBackward() {}
    func updateComposingText(from previous: String, to current: String) {}
    func switchToNextKeyboard() {}
    func triggerHapticFeedback() { hapticCount += 1 }
    func triggerLayerSwitchFeedback() { layerSwitchCount += 1 }
    func triggerLongPressFeedback() {}
    func moveCursor(by offset: Int) {}
    func textBeforeCursor() -> String? { nil }
}

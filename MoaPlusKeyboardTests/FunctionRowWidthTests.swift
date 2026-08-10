import XCTest
import SwiftUI
@testable import MoaPlusKeyboard

/// 기능 행의 자식 폭 합 == 사용 가능 폭 불변식.
/// 자식을 추가하면 간격(gap) 개수도 함께 늘어나야 하는데, 이를 놓치면 가장
/// 오른쪽 키(⏎)가 넘쳐 잘린다. v1.9 지구본 키 추가가 바로 그 위험이라
/// 모든 바디 × 지구본 on/off 조합을 고정한다.
final class FunctionRowWidthTests: XCTestCase {

    private func row(mode: KeyboardMode,
                     showGlobeKey: Bool,
                     slotA: SlotAPreset = .vowel,
                     koreanPunctuationEnabled: Bool = true,
                     englishPunctuationEnabled: Bool = true,
                     bimanual: Bool = false,
                     totalWidth: CGFloat = 393) -> FunctionRowView {
        var customization = LayoutCustomization()
        customization.slotA = slotA
        customization.koreanPunctuationEnabled = koreanPunctuationEnabled
        customization.englishPunctuationEnabled = englishPunctuationEnabled
        return FunctionRowView(
            totalWidth: totalWidth,
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

    private func assertFits(_ view: FunctionRowView,
                            _ label: String,
                            kind: FunctionRowView.BodyKind,
                            file: StaticString = #filePath, line: UInt = #line) {
        // 의도한 바디를 실제로 렌더하는지 먼저 확인 — 조건이 바뀌어 다른 바디로
        // 새면 폭 검증은 통과하면서 정작 대상 바디는 미검증으로 남는다.
        XCTAssertEqual(view.activeBodyKind, kind,
                       "\(label): 기대와 다른 바디가 활성", file: file, line: line)
        XCTAssertEqual(view.occupiedWidth, view.availableWidth, accuracy: 0.5,
                       "\(label): 자식 폭 합이 사용 가능 폭과 다름 — 오른쪽 키가 잘린다",
                       file: file, line: line)
        XCTAssertGreaterThan(view.occupiedWidth, 0, "\(label): 폭이 0 이하", file: file, line: line)
    }

    func test_defaultLayout_fitsWithAndWithoutGlobe() {
        for globe in [false, true] {
            assertFits(row(mode: .korean, showGlobeKey: globe), "default korean globe=\(globe)", kind: .default)
            assertFits(row(mode: .english, showGlobeKey: globe), "default english globe=\(globe)", kind: .default)
        }
    }

    func test_symbolLayout_fitsWithAndWithoutGlobe() {
        for globe in [false, true] {
            assertFits(row(mode: .symbolFromKorean, showGlobeKey: globe), "symbol globe=\(globe)", kind: .symbol)
            assertFits(row(mode: .symbolFromEnglish, showGlobeKey: globe), "symbol-en globe=\(globe)", kind: .symbol)
        }
    }

    /// 긴 스페이스 바디는 두 경로로 진입한다 — 한글 펑크 OFF, 그리고 확장형(A3).
    func test_longSpaceLayout_fitsWithAndWithoutGlobe() {
        for globe in [false, true] {
            assertFits(row(mode: .korean, showGlobeKey: globe, koreanPunctuationEnabled: false),
                       "longSpace(펑크 OFF) globe=\(globe)", kind: .longSpace)
            assertFits(row(mode: .english, showGlobeKey: globe, englishPunctuationEnabled: false),
                       "longSpace(영문 펑크 OFF, 기본값) globe=\(globe)", kind: .longSpace)
            assertFits(row(mode: .korean, showGlobeKey: globe, slotA: .fullPackage),
                       "longSpace(확장형) globe=\(globe)", kind: .longSpace)
        }
    }

    func test_bimanualLayout_fitsWithAndWithoutGlobe() {
        for globe in [false, true] {
            assertFits(row(mode: .korean, showGlobeKey: globe, bimanual: true, totalWidth: 1366),
                       "bimanual globe=\(globe)", kind: .bimanual)
            assertFits(row(mode: .symbolFromKorean, showGlobeKey: globe, bimanual: true, totalWidth: 1366),
                       "bimanual symbol globe=\(globe)", kind: .bimanual)
        }
    }

    /// 지구본을 켜면 스페이스 바만 줄어들어야 한다. 펑크 키까지 같이 줄면
    /// 기존 사용자의 특수문자 키 타격 지점이 바뀐다.
    func test_globeKeyShrinksOnlyTheSpaceBar() {
        let off = row(mode: .korean, showGlobeKey: false)
        let on = row(mode: .korean, showGlobeKey: true)
        XCTAssertEqual(on.punctuationWidth, off.punctuationWidth, accuracy: 0.01)
        XCTAssertEqual(on.symbolToggleWidth, off.symbolToggleWidth, accuracy: 0.01)
        XCTAssertEqual(on.letterToggleWidth, off.letterToggleWidth, accuracy: 0.01)
        XCTAssertEqual(on.returnWidth, off.returnWidth, accuracy: 0.01)
        XCTAssertLessThan(on.spaceWidth, off.spaceWidth)
        XCTAssertEqual(off.spaceWidth - on.spaceWidth,
                       on.globeWidth + KeyboardMetrics.keySpacing, accuracy: 0.01)
    }
}

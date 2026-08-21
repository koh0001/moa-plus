import XCTest

/// 설정 검색과 증상 라우터가 실제로 동작하는지 시뮬레이터에서 확인한다.
///
/// **왜 UI 테스트인가**: `SettingsCatalog`/`SettingsMainView`/`HelpView` 는 메인 앱
/// 타겟이고, `MoaPlusTests` 가 스킴에서 빠져 있어 유닛 테스트가 전혀 돌지 않는다.
/// `xcodebuild test` 가 통과해도 이 코드는 **컴파일만** 검증됐을 뿐이었다.
///
/// **이 테스트가 증명하지 않는 것**: `typeText` 는 한글 IME 를 거치지 않고 문자열을
/// 필드에 직접 넣는다. 따라서 실제 사용자가 시스템 키보드로 한글을 타이핑할 때
/// 겪는 "음절이 완성되기 전까지 결과가 비어 보이는" 현상은 여기서 재현되지 않는다
/// (`SettingsEntry.matches` 주석의 알려진 한계). 여기서 확인하는 것은 카탈로그
/// 매칭과 화면 이동 배선이다.
///
/// **실행 기기**: 반드시 iPhone 17 Pro. 이 테스트는 앱을 실행하므로 App Group
/// UserDefaults 를 건드리는데, 유닛 테스트용 iPhone 17 과 공유하면
/// `KeyboardViewModelVowelDragTests` 등이 결정적으로 깨진다 (docs/HANDOFF.md §0-2).
///
/// **실행법**: 스킴에 편입돼 있으므로 그냥 돌아간다.
///
/// ```bash
/// xcodebuild test -project MoaPlus.xcodeproj -scheme MoaPlus \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///   -only-testing:MoaPlusUITests
/// ```
///
/// 과거에는 프로젝트 결함 2개(스킴의 `skipped = "YES"`, 포크 이전 이름을 가리키던
/// `TEST_TARGET_NAME = ios-moaki`) 때문에 우회가 필요했다. 둘 다 v2.1.2 에서 고쳤다.
///
/// **`-uiTesting` 인자는 필수다.** 없으면 온보딩/"새로운 기능" 시트가 홈 화면을 덮어
/// "모아키 설정" 이 hittable 하지 않고, 이 파일의 테스트가 **전부** `openSettings()`
/// 한 줄에서 죽는다. 깨끗한 시뮬레이터에서 결정적으로 재현되므로 CI 에서는 항상 그렇다.
///
/// 첫 실행이 `xctrunner` 런치 실패로 한 번 죽고 재시도에서 붙는 경우가 있다 —
/// 케이스가 전부 passed 인데 최종 상태만 FAILED 로 나오면 그 상황이다.
final class SettingsDiscoveryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// 레이블로 요소를 찾아 탭한다.
    ///
    /// SwiftUI 의 `NavigationLink { Label(...) }` 은 List 안에서 `buttons` 로 보일 때도
    /// 있고 셀 아래 `staticTexts` 로만 보일 때도 있어, 한 종류만 노리면 빌드 사이클을
    /// 낭비하게 된다. 존재하고 누를 수 있는 첫 후보를 쓴다.
    @discardableResult
    private func tap(_ app: XCUIApplication, _ label: String,
                     timeout: TimeInterval = 5,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let queries: [XCUIElementQuery] = [app.buttons, app.staticTexts, app.cells, app.otherElements]
        for query in queries {
            let element = query[label]
            if element.waitForExistence(timeout: timeout / TimeInterval(queries.count)),
               element.isHittable {
                element.tap()
                return true
            }
        }
        attachTree(app, name: "tap 실패 시점 트리 — \(label)")
        XCTFail("‘\(label)’ 을(를) 찾지 못했다", file: file, line: line)
        return false
    }

    /// 레이블이 화면 어딘가에 보이는지 (요소 종류를 가리지 않고) 확인.
    private func exists(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return app.descendants(matching: .any).matching(predicate).firstMatch
            .waitForExistence(timeout: timeout)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachTree(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openSettings() -> XCUIApplication {
        let app = XCUIApplication()
        // 온보딩 / "새로운 기능" 시트를 끈다. 안 끄면 시트가 홈 화면을 덮어
        // "모아키 설정" 이 hittable 하지 않고, 여기 있는 테스트가 **전부** 이
        // 한 줄에서 죽는다(깨끗한 시뮬레이터에서 결정적으로 재현).
        app.launchArguments += ["-uiTesting"]
        app.launch()
        tap(app, "모아키 설정")
        return app
    }

    // MARK: - 검색

    @MainActor
    func testSearch_findsGlobeKeyByUserVocabulary() throws {
        let app = openSettings()
        shot(app, "1-설정 루트 (검색창 노출)")

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "설정 루트에 검색창이 없다")
        field.tap()
        field.typeText("지구본")

        XCTAssertTrue(exists(app, "키보드 전환 (지구본) 키"),
                      "‘지구본’ 검색이 전환 키 항목을 찾지 못했다")
        shot(app, "2-검색 ‘지구본’")
    }

    @MainActor
    func testSearch_findsGestureAngleByUserVocabulary() throws {
        let app = openSettings()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("각도")

        XCTAssertTrue(exists(app, "긋기 각도"), "‘각도’ 검색이 긋기 각도를 찾지 못했다")
        shot(app, "3-검색 ‘각도’")
    }

    /// 이 기능의 핵심 가치 — 앱 용어가 아닌 **사용자 어휘**로 도달할 수 있는가.
    /// 리뷰에 실제로 등장한 표기(‘지구봉’ 오타 포함)를 그대로 넣어 본다.
    @MainActor
    func testSearch_acceptsReviewVocabulary() throws {
        let app = openSettings()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("지구봉")

        XCTAssertTrue(exists(app, "키보드 전환 (지구본) 키"),
                      "리뷰 표기 ‘지구봉’ 이 검색에 걸리지 않는다 — keywords 가 사라졌는지 확인할 것")
        shot(app, "4-검색 ‘지구봉’ (리뷰 오타 표기)")
    }

    @MainActor
    func testSearch_navigatesToResult() throws {
        let app = openSettings()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("각도")

        tap(app, "긋기 각도")
        XCTAssertTrue(app.navigationBars["긋기 입력 설정"].waitForExistence(timeout: 5),
                      "검색 결과를 탭했는데 긋기 설정 화면으로 가지 않았다")
        shot(app, "5-검색 결과 탭 → 긋기 입력 설정")
    }

    // MARK: - 증상 라우터

    @MainActor
    func testSymptomRouter_opensFromSettingsRoot() throws {
        let app = openSettings()
        tap(app, "이럴 때 어떻게 하나요")

        // 행 레이블과 도착 화면 제목이 같아야 한다 — 다르면 "여기가 맞나" 하고 되돌아간다.
        XCTAssertTrue(app.navigationBars["이럴 때 어떻게 하나요"].waitForExistence(timeout: 5),
                      "도움말 화면 제목이 행 레이블과 다르다")
        XCTAssertTrue(exists(app, "오타가 잦아요"), "증상 항목이 보이지 않는다")
        shot(app, "6-증상 라우터 목록")
    }

    @MainActor
    func testSymptomRouter_typoSymptomLeadsToGestureSettings() throws {
        let app = openSettings()
        tap(app, "이럴 때 어떻게 하나요")
        tap(app, "오타가 잦아요")

        XCTAssertTrue(app.navigationBars["긋기 입력 설정"].waitForExistence(timeout: 5),
                      "‘오타가 잦아요’ 가 긋기 설정으로 가지 않았다")
        shot(app, "7-증상 → 긋기 입력 설정")
    }

    @MainActor
    func testSymptomRouter_globeSymptomLeadsToSizeSettings() throws {
        let app = openSettings()
        tap(app, "이럴 때 어떻게 하나요")
        tap(app, "다른 키보드로 못 바꾸겠어요")

        XCTAssertTrue(app.navigationBars["크기 · 전환 키"].waitForExistence(timeout: 5),
                      "‘다른 키보드로 못 바꾸겠어요’ 가 크기·전환 키 화면으로 가지 않았다")
        shot(app, "8-증상 → 크기 · 전환 키")
    }

    // MARK: - 네이밍 트랩 회귀 가드

    /// 행은 "소리 · 진동"인데 도착 화면 제목이 "반응"이면, "반응속도가 느리다"는
    /// 사용자를 다시 사운드·햅틱 화면으로 끌어들이게 된다. 두 곳이 어긋나지 않도록 고정.
    @MainActor
    func testFeedbackRowAndScreenTitleAgree() throws {
        let app = openSettings()
        tap(app, "소리 · 진동")

        XCTAssertTrue(app.navigationBars["소리 · 진동"].waitForExistence(timeout: 5),
                      "행 레이블과 화면 제목이 어긋난다 — ‘반응’ 으로 되돌아갔는지 확인할 것")
        shot(app, "9-소리 · 진동 화면")
    }
}

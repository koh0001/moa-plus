//
//  MoaPlusUITestsLaunchTests.swift
//  MoaPlusUITests
//
//  Created by Jeffrey Kim on 2026/1/28.
//

import XCTest

/// 앱이 켜지는지만 보는 스모크 테스트 + 실행 직후 스크린샷 첨부.
///
/// 같이 있던 Xcode 템플릿(`ios_moakiUITests.swift`)은 v2.1.2 에서 삭제했다.
/// `testExample()` 은 본문이 비어 단언이 하나도 없었고, `testLaunchPerformance()`
/// 는 부하가 들쭉날쭉한 CI 러너에서 의미 없는 숫자에 236초를 썼다. 그 둘이
/// 클론 2개를 동시에 띄우면서 런치 타임아웃(116초 실패)을 만들어 CI 를 막았다.
/// **템플릿 스텁을 다시 만들지 말 것** — 검증하는 게 없으면서 실패는 한다.
final class MoaPlusUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

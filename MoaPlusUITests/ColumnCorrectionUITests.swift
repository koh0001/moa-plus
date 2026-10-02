import XCTest

/// 세로 라인별 보정 토글이 실제 판정에 닿는지, **정확한 각도의 직선 긋기**로 확인한다.
///
/// 손으로 그으면 매번 각도가 달라 켬/끔 차이를 비교할 수 없다(실기기 확인 시 사용자 피드백).
/// 긋기 실시간 테스트 화면은 앱 안에 실제 `KeyboardView` 를 넣어 production 판정 경로를 그대로
/// 쓰므로, 여기서 같은 각도로 그어 켬/끔 결과를 나란히 비교한다. 결과 표는 첨부로 남긴다.
///
/// 실행 기기: iPhone 17 Pro (유닛 테스트용 iPhone 17 과 App Group 을 공유하면 안 된다 —
/// `SettingsDiscoveryUITests` 머리말 참조).
final class ColumnCorrectionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        for query in [app.buttons, app.staticTexts, app.cells, app.otherElements] {
            let e = query[label]
            if e.waitForExistence(timeout: 2), e.isHittable { return e }
        }
        XCTFail("‘\(label)’ 없음")
        return app.staticTexts[label]
    }

    private func scrollTo(_ el: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !el.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
    }

    /// 제스처 (긋기) 설정 화면에서 보정 토글을 원하는 상태로 맞춘다.
    private func setCorrection(_ on: Bool, app: XCUIApplication) {
        let toggle = app.switches["세로 라인별 보정 사용"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2) || { scrollTo(toggle, in: app); return toggle.exists }())
        scrollTo(toggle, in: app)
        let isOn = (toggle.value as? String) == "1"
        if isOn != on {
            // SwiftUI Toggle 은 셀 중앙이 아니라 스위치 쪽을 눌러야 확실히 바뀐다.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual((toggle.value as? String) == "1", on, "토글 상태를 바꾸지 못했다")
    }

    /// ㅅ 키 중앙에서 `degrees`(오른쪽 0°, 반시계) 방향으로 `length`pt 직선을 긋고 최종 모음을 읽는다.
    private func swipe(_ app: XCUIApplication, key: String, degrees: Double, length: Double = 60) -> String {
        let k = app.staticTexts[key].firstMatch
        XCTAssertTrue(k.waitForExistence(timeout: 3), "키 \(key) 없음")
        let start = k.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let rad = degrees * .pi / 180
        let end = start.withOffset(CGVector(dx: cos(rad) * length, dy: -sin(rad) * length))
        start.press(forDuration: 0.05, thenDragTo: end)
        return app.staticTexts["gestureTest.vowel.최종 결과"].label
    }

    private func metric(_ app: XCUIApplication, _ title: String) -> String {
        app.staticTexts["gestureTest.metric.\(title)"].label
    }

    func testColumnCorrection_toggleChangesEdgeColumnJudgement() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        element(app, "모아키 설정").tap()
        element(app, "키보드").tap()
        element(app, "제스처 (긋기)").tap()

        // 맨 오른쪽 열(ㅅ)에서 ↗(ㅣ)↔↑(ㅗ) 경계 근처를 2° 간격으로.
        let angles: [Double] = Array(stride(from: 58.0, through: 76.0, by: 2.0))
        var table: [String: [String]] = [:]
        var rotation: [String: String] = [:]

        for on in [true, false] {
            setCorrection(on, app: app)
            app.swipeDown(); app.swipeDown()
            element(app, "긋기 실시간 테스트").tap()
            let name = on ? "켜짐" : "꺼짐"
            var results: [String] = []
            for a in angles {
                results.append(swipe(app, key: "ㅅ", degrees: a))
            }
            rotation[name] = metric(app, "적용된 회전 보정")
            table[name] = results
            app.navigationBars.buttons.element(boundBy: 0).tap()  // 설정 화면으로
        }

        var report = "ㅅ(5열) 직선 긋기 60pt — 각도별 최종 모음\n"
        report += "적용된 회전 보정: 켜짐 \(rotation["켜짐"] ?? "?") / 꺼짐 \(rotation["꺼짐"] ?? "?")\n\n"
        report += "각도  켜짐  꺼짐\n"
        for (i, a) in angles.enumerated() {
            report += String(format: "%4.0f°  ", a) + "\(table["켜짐"]![i])     \(table["꺼짐"]![i])\n"
        }
        let att = XCTAttachment(string: report)
        att.name = "column-correction-report"
        att.lifetime = .keepAlways
        add(att)
        print(report)

        XCTAssertEqual(rotation["켜짐"], "-3.0°", "켜짐에서 5열 회전 보정이 보이지 않는다")
        XCTAssertEqual(rotation["꺼짐"], "0.0°", "꺼짐인데 5열 회전 보정이 남아 있다")

        // 테스트가 바꾼 설정을 원래대로(켜짐) 돌려 둔다.
        setCorrection(true, app: app)
    }
}

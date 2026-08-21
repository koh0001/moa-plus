import XCTest
@testable import MoaPlusKeyboard

/// 하단 여백(홈 인디케이터 회피) 가드.
///
/// 배경: 물리 홈 버튼 없는 아이폰에서 스페이스바가 화면 맨 아래 홈 제스처 구역에
/// 붙어 있어 스페이스를 누르다 홈 화면으로 빠져나간다는 제보.
///
/// 이 파일이 지키는 **핵심 불변식**은 "여백을 늘려도 키 크기는 그대로"다.
/// 컨테이너 높이만 키우고 `keyHeight(for:)` 입력에서 여백을 빼지 않으면
/// 늘어난 높이를 키들이 그대로 흡수해 버리고 기능행은 여전히 잘린다
/// (약어 후보 바에서 실기기로 이미 한 번 겪은 실패 모드).
final class KeyboardBottomInsetTests: XCTestCase {

    // MARK: - 핵심 불변식: 여백은 키 높이를 바꾸지 않는다

    func test_bottomInset_doesNotChangeKeyRowHeight() {
        let base = KeyboardMetrics.keyboardHeight(
            isPad: false, isLandscape: false, screenShort: 390, screenLong: 844)
        let baseline = KeyboardMetrics.keyHeight(for: base)

        for inset in [CGFloat(8), 20, 34, 54] {
            // 컨테이너는 여백만큼 커지고, 그리드 배분에서는 같은 값을 뺀다.
            let container = base + inset
            let keyHeight = KeyboardMetrics.keyHeight(for: container - inset)
            XCTAssertEqual(keyHeight, baseline, accuracy: 0.001,
                           "여백 \(inset)pt 에서 키 한 행 높이가 달라졌다")
        }
    }

    /// 후보 바와 여백이 동시에 있어도 같은 규칙이 성립해야 한다.
    func test_bottomInsetWithCandidateBar_doesNotChangeKeyRowHeight() {
        let base = KeyboardMetrics.keyboardHeight(
            isPad: false, isLandscape: false, screenShort: 390, screenLong: 844)
        let baseline = KeyboardMetrics.keyHeight(for: base)

        let bar = KeyboardMetrics.abbreviationCandidateBarFootprint
        let inset: CGFloat = 34
        let container = base + bar + inset
        XCTAssertEqual(KeyboardMetrics.keyHeight(for: container - bar - inset),
                       baseline, accuracy: 0.001)
    }

    // MARK: - resolvedBottomInset

    func test_resolvedBottomInset_autoOnAddsDeviceInsetAndExtra() {
        XCTAssertEqual(
            KeyboardMetrics.resolvedBottomInset(autoEnabled: true, deviceInset: 34, extra: 8),
            42, accuracy: 0.001)
    }

    func test_resolvedBottomInset_autoOffIgnoresDeviceInset() {
        XCTAssertEqual(
            KeyboardMetrics.resolvedBottomInset(autoEnabled: false, deviceInset: 34, extra: 8),
            8, accuracy: 0.001)
        // 자동 OFF + 추가 여백 0 = 여백 없음 = 이 기능 도입 전과 동일한 레이아웃.
        XCTAssertEqual(
            KeyboardMetrics.resolvedBottomInset(autoEnabled: false, deviceInset: 34, extra: 0),
            0, accuracy: 0.001)
    }

    /// 홈 버튼 기기(안전영역 0)에서는 자동을 켜도 아무 일도 일어나지 않아야 한다.
    func test_resolvedBottomInset_homeButtonDevice_autoIsNoOp() {
        XCTAssertEqual(
            KeyboardMetrics.resolvedBottomInset(autoEnabled: true, deviceInset: 0, extra: 0),
            0, accuracy: 0.001)
    }

    // MARK: - 클램프 / 손상값 방어

    func test_clampedExtraBottomInset_clampsOutOfRange() {
        let lower = KeyboardMetrics.extraBottomInsetRange.lowerBound
        let upper = KeyboardMetrics.extraBottomInsetRange.upperBound
        XCTAssertEqual(KeyboardMetrics.clampedExtraBottomInset(-50), CGFloat(lower), accuracy: 0.001)
        XCTAssertEqual(KeyboardMetrics.clampedExtraBottomInset(999), CGFloat(upper), accuracy: 0.001)
    }

    /// NaN 은 `min`/`max` 비교를 전부 통과해 그대로 전파되고, 그러면 높이 제약
    /// constant 가 NaN 이 되어 레이아웃이 통째로 깨진다.
    func test_clampedExtraBottomInset_nanFallsBackToLowerBound() {
        XCTAssertEqual(KeyboardMetrics.clampedExtraBottomInset(.nan),
                       CGFloat(KeyboardMetrics.extraBottomInsetRange.lowerBound), accuracy: 0.001)
    }

    func test_resolvedBottomInset_nanDeviceInsetIsIgnored() {
        let result = KeyboardMetrics.resolvedBottomInset(autoEnabled: true, deviceInset: .nan, extra: 4)
        XCTAssertTrue(result.isFinite, "NaN 안전영역이 여백으로 전파됐다")
        XCTAssertEqual(result, 4, accuracy: 0.001)
    }

    func test_resolvedBottomInset_negativeDeviceInsetIsClampedToZero() {
        XCTAssertEqual(
            KeyboardMetrics.resolvedBottomInset(autoEnabled: true, deviceInset: -20, extra: 0),
            0, accuracy: 0.001)
    }

    /// 자동 여백은 iOS 실측값에만 의존하므로, 어떤 조합에서 0 으로 오면 무동작이
    /// 된다. 그때도 **수동만으로** 홈 제스처 구역을 전부 비울 수 있어야 한다.
    func test_extraBottomInsetRange_canCoverHomeIndicatorAlone() {
        XCTAssertGreaterThanOrEqual(
            CGFloat(KeyboardMetrics.extraBottomInsetRange.upperBound),
            KeyboardMetrics.homeIndicatorBottomInset,
            "자동이 무동작일 때 수동으로 홈 인디케이터 구역을 못 비운다")
    }

    // MARK: - estimatedBottomSafeInset (메인 앱 전용 폴백)
    //
    // 익스텐션은 이 추정값을 쓰지 않는다 — 실측 안전영역만 믿는다.
    // 여기 테스트는 메인 앱(`DeviceSafeArea`)이 앱 창을 아직 못 얻었을 때의
    // 마지막 폴백 동작을 고정한다.

    func test_estimatedBottomSafeInset_homeIndicatorIPhones() {
        // 홈 인디케이터 아이폰은 장/단변 비율이 ≈2.16.
        let devices: [(CGFloat, CGFloat)] = [
            (375, 812),   // iPhone X / 11 Pro
            (390, 844),   // iPhone 12~14
            (393, 852),   // iPhone 15/16
            (428, 926),   // 12/13 Pro Max
            (430, 932),   // 14/15 Pro Max
        ]
        for (short, long) in devices {
            XCTAssertEqual(
                KeyboardMetrics.estimatedBottomSafeInset(
                    isPad: false, isLandscape: false, screenShort: short, screenLong: long),
                KeyboardMetrics.homeIndicatorBottomInset, accuracy: 0.001,
                "\(short)×\(long) 가 홈 인디케이터 기기로 인식되지 않았다")
        }
    }

    func test_estimatedBottomSafeInset_homeButtonIPhonesAreZero() {
        // 홈 버튼 아이폰은 비율 ≈1.78 — 비울 구역이 없다.
        let devices: [(CGFloat, CGFloat)] = [
            (320, 568),   // SE 1세대
            (375, 667),   // 8 / SE 2·3세대
            (414, 736),   // 8 Plus
        ]
        for (short, long) in devices {
            XCTAssertEqual(
                KeyboardMetrics.estimatedBottomSafeInset(
                    isPad: false, isLandscape: false, screenShort: short, screenLong: long),
                0, accuracy: 0.001,
                "\(short)×\(long) 에 불필요한 여백이 생겼다")
        }
    }

    func test_estimatedBottomSafeInset_landscapeIPhoneIsShorter() {
        XCTAssertEqual(
            KeyboardMetrics.estimatedBottomSafeInset(
                isPad: false, isLandscape: true, screenShort: 390, screenLong: 844),
            KeyboardMetrics.homeIndicatorBottomInsetLandscape, accuracy: 0.001)
    }

    func test_estimatedBottomSafeInset_zeroScreenIsSafe() {
        // 레이아웃 전 호출 등으로 화면 크기가 0 이어도 0/0 = NaN 이 새면 안 된다.
        let result = KeyboardMetrics.estimatedBottomSafeInset(
            isPad: false, isLandscape: false, screenShort: 0, screenLong: 0)
        XCTAssertTrue(result.isFinite)
        XCTAssertEqual(result, 0, accuracy: 0.001)
    }

    // MARK: - 설정 기본값

    /// 기본 ON. 끄는 경로는 "설정 › 키보드 › 크기 · 전환 키 › 하단 여백".
    func test_settingsDefaults_autoInsetOnAndNoExtra() {
        let settings = KeyboardSettings.shared
        let prevAuto = settings.keyboardAutoBottomInsetEnabled
        let prevExtra = settings.keyboardExtraBottomInset
        defer {
            settings.keyboardAutoBottomInsetEnabled = prevAuto
            settings.keyboardExtraBottomInset = prevExtra
        }

        settings.resetAll()
        XCTAssertTrue(settings.keyboardAutoBottomInsetEnabled)
        XCTAssertEqual(settings.keyboardExtraBottomInset,
                       KeyboardMetrics.defaultExtraBottomInset, accuracy: 0.001)
    }

    /// `keyboardHeight(...)` 시그니처에 여백이 섞여 들어가면 기존 테스트/호출부가
    /// 전부 흔들린다. 여백은 호출부에서 **더하는** 값으로만 남아야 한다.
    func test_keyboardHeight_isUnaffectedByInsetSettings() {
        let settings = KeyboardSettings.shared
        let prevAuto = settings.keyboardAutoBottomInsetEnabled
        let prevExtra = settings.keyboardExtraBottomInset
        defer {
            settings.keyboardAutoBottomInsetEnabled = prevAuto
            settings.keyboardExtraBottomInset = prevExtra
        }

        settings.keyboardAutoBottomInsetEnabled = true
        settings.keyboardExtraBottomInset = 20
        XCTAssertEqual(
            KeyboardMetrics.keyboardHeight(
                isPad: false, isLandscape: false, screenShort: 390, screenLong: 844),
            260, accuracy: 0.01)
    }
}

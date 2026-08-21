import UIKit

/// 이 기기의 하단 안전영역(홈 인디케이터 구역) 값을 메인 앱에서 읽는다.
///
/// 키보드 익스텐션은 자기 입력 뷰의 `safeAreaInsets` 를 직접 읽지만, 메인 앱의
/// 설정 화면·미리보기는 익스텐션이 실행 중이 아닐 때도 같은 값을 보여줘야 한다.
/// 익스텐션이 남긴 실측값을 최우선으로 쓰고, 없으면 앱 창 값으로 근사한다.
///
/// `UIApplication` 은 앱 익스텐션에서 사용할 수 없어 이 파일은 **메인 앱 전용**이다.
/// 익스텐션 쪽 대응 로직은 `KeyboardViewController.bottomInset()`.
enum DeviceSafeArea {

    /// 설정 화면·미리보기가 쓸 하단 안전영역.
    ///
    /// 우선순위: ①익스텐션이 실측해 App Group 에 남긴 값 → ②앱 창의 안전영역 →
    /// ③화면 비율 추정값.
    ///
    /// ①이 최우선인 이유: 앱 창과 키보드 익스텐션의 안전영역은 **다를 수 있다**.
    /// iOS 26 은 키보드 아래에 지구본 바를 직접 그려 익스텐션 쪽은 0 인데 앱 창은
    /// 여전히 34pt 를 보고한다. 앱 창 값으로 그리면 실제 키보드에 없는 여백을
    /// 설정 화면과 미리보기가 있다고 표시하게 된다.
    static var bottomInset: CGFloat {
        if let measured = KeyboardSettings.shared.measuredKeyboardBottomInset {
            return CGFloat(measured)
        }
        if let window = keyWindowBottomInset, window > 0 { return window }
        let bounds = UIScreen.main.bounds
        return KeyboardMetrics.estimatedBottomSafeInset(
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            isLandscape: false,
            screenShort: min(bounds.width, bounds.height),
            screenLong: max(bounds.width, bounds.height))
    }

    /// 익스텐션이 실측값을 남긴 적이 있는지. 설정 화면이 "아직 모름"과
    /// "0 으로 확인됨"을 구분해 안내하는 데 쓴다.
    static var hasKeyboardMeasurement: Bool {
        KeyboardSettings.shared.measuredKeyboardBottomInset != nil
    }

    private static var keyWindowBottomInset: CGFloat? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom
    }
}

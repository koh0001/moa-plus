import SwiftUI

/// 키보드 크기 / 전환 키 설정.
/// 앱스토어 리뷰에서 가장 많이 요청된 "키보드 높이 조절"(v1.8.0 기준 4명)과
/// "애플 기본 키보드로 돌아갈 방법이 없다"(2명)를 함께 다룬다.
struct KeyboardSizeSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    /// 아이폰 기준 실제 적용 높이(pt). 아이패드는 화면 크기에서 파생되므로
    /// 여기서는 배율만 안내하고 수치는 아이폰 기준으로 보여준다.
    private var resolvedPhoneHeight: CGFloat {
        KeyboardMetrics.keyboardHeight(
            isPad: false, isLandscape: false,
            screenShort: 0, screenLong: 0,
            scale: settings.keyboardHeightScale)
    }

    /// 배율을 적용했을 때 자음 키 한 행의 높이. 너무 낮추면 오타가 늘어나므로
    /// 사용자가 수치로 직접 확인할 수 있게 노출한다.
    private var resolvedKeyHeight: CGFloat {
        KeyboardMetrics.keyHeight(for: resolvedPhoneHeight)
    }

    private var isDefaultHeight: Bool {
        abs(settings.keyboardHeightScale - KeyboardMetrics.defaultKeyboardHeightScale) < 0.001
    }

    var body: some View {
        List {
            Section {
                KeyboardPreviewView()
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            } footer: {
                Text("설정을 바꾸면 미리보기에 바로 반영됩니다.")
            }

            Section {
                HStack {
                    Text("높이")
                    Spacer()
                    Text("\(Int(settings.keyboardHeightScale * 100))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $settings.keyboardHeightScale,
                    in: KeyboardMetrics.keyboardHeightScaleRange,
                    step: 0.01
                )
                Button("기본값으로 되돌리기") {
                    settings.keyboardHeightScale = KeyboardMetrics.defaultKeyboardHeightScale
                }
                .disabled(isDefaultHeight)
            } header: {
                Text("키보드 높이")
            } footer: {
                Text("아이폰 기준 \(Int(resolvedPhoneHeight))pt (키 한 행 \(Int(resolvedKeyHeight))pt). 아이패드는 화면 크기에 맞춘 높이에 같은 배율이 적용됩니다. 너무 낮추면 키가 작아져 오타가 늘 수 있습니다.")
            }

            Section {
                Toggle("키보드 전환 키 표시", isOn: $settings.showGlobeKey)
            } header: {
                Text("키보드 전환")
            } footer: {
                Text("켜면 기능 행 맨 왼쪽에 지구본 키가 생겨 애플 기본 키보드 등 다른 키보드로 바로 전환합니다. 스페이스바는 그만큼 좁아집니다.\n\n최신 iOS(26 이상) 아이폰은 시스템이 키보드 아래에 지구본 바를 직접 표시하므로, 켜도 지구본이 중복으로 나타나지는 않습니다. 설치된 키보드가 모아+ 하나뿐일 때도 전환할 대상이 없어 표시되지 않습니다.")
            }
        }
        .navigationTitle("크기 · 전환 키")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        KeyboardSizeSettingsView()
    }
}

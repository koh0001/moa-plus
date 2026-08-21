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

    /// 이 기기가 실제로 보고하는 하단 안전영역(홈 인디케이터 구역).
    /// 홈 버튼이 있는 기기에서는 0이라 자동 여백이 아무 일도 하지 않는다.
    private var deviceBottomInset: CGFloat { DeviceSafeArea.bottomInset }

    private var resolvedBottomInset: CGFloat {
        KeyboardMetrics.resolvedBottomInset(
            autoEnabled: settings.keyboardAutoBottomInsetEnabled,
            deviceInset: deviceBottomInset,
            extra: settings.keyboardExtraBottomInset)
    }

    private var isDefaultBottomInset: Bool {
        settings.keyboardAutoBottomInsetEnabled
            && abs(settings.keyboardExtraBottomInset - KeyboardMetrics.defaultExtraBottomInset) < 0.001
    }

    /// 세 가지 상태를 구분해 안내한다. "0pt = 홈 버튼 기기"로 단정하면 안 된다 —
    /// 최신 iOS 는 키보드 아래에 시스템 바를 직접 그려서, 홈 인디케이터가 있는
    /// 기기인데도 키보드가 비울 구역은 0 인 경우가 있다.
    private var autoInsetDescription: String {
        guard DeviceSafeArea.hasKeyboardMeasurement else {
            return "모아+ 키보드를 한 번 사용하면 이 기기에서 실제로 확보되는 값을 여기에 표시합니다."
        }
        return deviceBottomInset > 0
            ? "이 기기에서 자동으로 확보되는 구역은 \(Int(deviceBottomInset))pt 입니다."
            : "이 기기에서는 자동으로 비울 구역이 없습니다 — 홈 버튼이 있거나, iOS가 키보드 아래 영역을 이미 차지하고 있습니다. 켜 두어도 변화가 없습니다."
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
                Toggle("홈 인디케이터 자동 피하기", isOn: $settings.keyboardAutoBottomInsetEnabled)

                HStack {
                    Text("추가 여백")
                    Spacer()
                    Text("\(Int(settings.keyboardExtraBottomInset))pt")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $settings.keyboardExtraBottomInset,
                    in: KeyboardMetrics.extraBottomInsetRange,
                    step: 1
                )

                HStack {
                    Text("총 적용 여백")
                    Spacer()
                    Text("\(Int(resolvedBottomInset))pt")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Button("기본값으로 되돌리기") {
                    settings.keyboardAutoBottomInsetEnabled = true
                    settings.keyboardExtraBottomInset = KeyboardMetrics.defaultExtraBottomInset
                }
                .disabled(isDefaultBottomInset)
            } header: {
                Text("하단 여백")
            } footer: {
                Text("물리 홈 버튼이 없는 아이폰은 화면 맨 아래가 홈 제스처 구역이라, 스페이스바를 누르다 홈 화면으로 빠져나가는 일이 생깁니다. 자동 피하기를 켜면 그 구역을 비우고 키보드를 그만큼 위로 올립니다.\n\n\(autoInsetDescription) 키 크기는 그대로 유지되고 키보드 전체 높이가 여백만큼 늘어납니다.\n\n자동을 켰는데도 키보드가 그대로라면(앱에 따라 이럴 수 있습니다) 추가 여백을 직접 올려 보세요. 추가 여백만으로도 홈 제스처 구역 전체를 비울 수 있습니다.")
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
                Text("아이폰 기준 키보드 본체 \(Int(resolvedPhoneHeight))pt (키 한 행 \(Int(resolvedKeyHeight))pt). 하단 여백은 여기에 더해집니다 — 지금 설정으로 전체 \(Int(resolvedPhoneHeight + resolvedBottomInset))pt 입니다. 아이패드는 화면 크기에 맞춘 높이에 같은 배율이 적용됩니다. 너무 낮추면 키가 작아져 오타가 늘 수 있습니다.")
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

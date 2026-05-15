import SwiftUI

struct FeedbackSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section {
                Toggle("키 클릭 사운드", isOn: $settings.clickSoundEnabled)
            } header: {
                Text("사운드")
            }

            Section {
                Toggle("햅틱 반응", isOn: $settings.themeSettings.hapticEnabled)

                if settings.themeSettings.hapticEnabled {
                    Picker("햅틱 강도", selection: $settings.themeSettings.hapticStrength) {
                        ForEach(HapticStrength.allCases, id: \.self) { strength in
                            Text(strength.displayName).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("햅틱")
            } footer: {
                // iOS restricts UIImpactFeedbackGenerator inside keyboard
                // extensions unless Full Access is granted. The toggles
                // above stay user-controlled; this footer just explains
                // why vibration may be silent.
                if settings.themeSettings.hapticEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("진동이 느껴지지 않으면 '전체 접근 허용' 권한이 필요합니다.")
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("iOS 키보드 설정 열기", systemImage: "arrow.up.right.square")
                                .font(.footnote)
                        }
                        Text("설정 → 일반 → 키보드 → 키보드 → 모아+ → '전체 접근 허용' 토글을 켜주세요. 키 입력은 외부로 전송되지 않으며, 햅틱 진동·사운드·앱 설정 동기화를 위해서만 사용됩니다.")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if settings.themeSettings.hapticEnabled {
                Section {
                    Toggle("탭", isOn: $settings.themeSettings.hapticOnTap)
                    Toggle("롱프레스 팝업", isOn: $settings.themeSettings.hapticOnLongPress)
                    Toggle("레이어 전환", isOn: $settings.themeSettings.hapticOnLayerSwitch)
                    Toggle("약어 확정", isOn: $settings.themeSettings.hapticOnAbbreviationConfirm)
                } header: {
                    Text("이벤트별 햅틱")
                } footer: {
                    Text("각 이벤트별로 햅틱 반응을 개별 설정할 수 있습니다.")
                }
            }

        }
        .navigationTitle("반응")
    }
}

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

            Section {
                Picker("삭제 반복 속도", selection: $settings.backspaceSpeed) {
                    Text("느리게").tag(0)
                    Text("보통").tag(1)
                    Text("빠르게").tag(2)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("백스페이스")
            } footer: {
                Text("길게 누를 때 글자가 반복 삭제되는 속도입니다.")
            }

            Section {
                Toggle("단어 단위 삭제", isOn: $settings.wordDeleteEnabled)

                if settings.wordDeleteEnabled {
                    HStack {
                        Text("전환 시간")
                        Spacer()
                        Text("\(settings.wordDeleteDelay, specifier: "%.1f")초")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.wordDeleteDelay, in: 0.8...3.0, step: 0.1)
                }
            } footer: {
                if settings.wordDeleteEnabled {
                    Text("백스페이스를 \(settings.wordDeleteDelay, specifier: "%.1f")초 이상 누르면 공백 단위로 빠르게 삭제합니다.")
                } else {
                    Text("백스페이스를 길게 눌러도 한 글자씩만 삭제합니다.")
                }
            }
        }
        .navigationTitle("반응")
    }
}

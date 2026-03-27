//
//  FeedbackSettingsView.swift
//  ios-moaki
//

import SwiftUI

struct FeedbackSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section(header: Text("사운드")) {
                Toggle("키 클릭 사운드", isOn: $settings.themeSettings.clickSoundEnabled)
            }

            Section(header: Text("햅틱")) {
                Toggle("햅틱 반응", isOn: $settings.themeSettings.hapticEnabled)

                if settings.themeSettings.hapticEnabled {
                    Picker("햅틱 강도", selection: $settings.themeSettings.hapticStrength) {
                        ForEach(HapticStrength.allCases, id: \.self) { strength in
                            Text(strength.displayName).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if settings.themeSettings.hapticEnabled {
                Section(header: Text("이벤트별 햅틱")) {
                    Toggle("탭", isOn: $settings.themeSettings.hapticOnTap)
                    Toggle("롱프레스 팝업", isOn: $settings.themeSettings.hapticOnLongPress)
                    Toggle("레이어 전환", isOn: $settings.themeSettings.hapticOnLayerSwitch)
                    Toggle("약어 확정", isOn: $settings.themeSettings.hapticOnAbbreviationConfirm)
                } footer: {
                    Text("각 이벤트별로 햅틱 반응을 개별 설정할 수 있습니다.")
                }
            }
        }
        .navigationTitle("반응")
    }
}

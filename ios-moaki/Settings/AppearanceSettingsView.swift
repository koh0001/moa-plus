//
//  AppearanceSettingsView.swift
//  ios-moaki
//

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section(header: Text("테마 모드")) {
                Picker("모드", selection: $settings.themeSettings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("버튼 색상 테마")) {
                ForEach(ButtonTheme.allCases) { theme in
                    Button(action: { settings.themeSettings.buttonTheme = theme }) {
                        HStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.keyBackgroundColor)
                                .overlay(
                                    Text("ㄱ")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(theme.keyTextColor)
                                )
                                .frame(width: 36, height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )

                            Text(theme.displayName)
                                .foregroundColor(Color(.label))

                            Spacer()

                            if settings.themeSettings.buttonTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }

            Section(header: Text("배경")) {
                HStack {
                    Text("배경 투명도")
                    Spacer()
                    Text("\(Int(settings.themeSettings.backgroundOpacity * 100))%")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.themeSettings.backgroundOpacity, in: 0...0.6, step: 0.05)
            } footer: {
                Text("배경 이미지 위에 키보드가 반투명하게 표시됩니다.")
            }
        }
        .navigationTitle("외형")
    }
}

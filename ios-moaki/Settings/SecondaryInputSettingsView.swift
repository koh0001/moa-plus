//
//  SecondaryInputSettingsView.swift
//  ios-moaki
//

import SwiftUI

struct SecondaryInputSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section(header: Text("보조 힌트 표시")) {
                Toggle("힌트 표시", isOn: $settings.showSecondaryHints)

                if settings.showSecondaryHints {
                    Picker("힌트 크기", selection: $settings.hintSize) {
                        Text("작게").tag(0)
                        Text("보통").tag(1)
                        Text("크게").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text("각 자음 키에 숫자/기호 힌트를 작게 표시합니다.")
            }

            Section(header: Text("롱프레스 보조 입력")) {
                ForEach(settings.secondaryKeyActions) { action in
                    HStack {
                        Text(action.keyId)
                            .font(.title3)
                            .frame(width: 30)

                        Divider()

                        Text(action.visibleHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 24)

                        Text("→")
                            .foregroundColor(.secondary)

                        Text(action.primaryLongPressOutput)
                            .font(.body)

                        if !action.popupOutputs.isEmpty {
                            Spacer()
                            Text(action.popupOutputs.joined(separator: " "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } footer: {
                Text("길게 누르면 대표 문자가 입력되고, 계속 누르면 추가 후보를 선택할 수 있습니다.")
            }

            Section {
                Button("기본 매핑으로 복원") {
                    settings.secondaryKeyActions = SecondaryKeyAction.defaults
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("보조 입력")
    }
}

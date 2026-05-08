import SwiftUI

struct LongPressSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var editingAction: SecondaryKeyAction?

    var body: some View {
        List {
            Section {
                Toggle("힌트 표시", isOn: $settings.showSecondaryHints)

                if settings.showSecondaryHints {
                    Picker("힌트 크기", selection: $settings.hintSize) {
                        Text("작게").tag(0)
                        Text("보통").tag(1)
                        Text("크게").tag(2)
                    }
                    .pickerStyle(.segmented)

                    Toggle("전체 후보 표시", isOn: $settings.showDetailedHints)
                }
            } header: {
                Text("보조 힌트 표시")
            } footer: {
                Text(settings.showDetailedHints
                    ? "각 키에 롱프레스 후보 문자가 모두 표시됩니다."
                    : "각 자음 키에 대표 숫자/기호 힌트를 작게 표시합니다.")
            }

            Section {
                HStack {
                    Text("롱프레스 반응 시간")
                    Spacer()
                    Text("\(settings.longPressDelay, specifier: "%.1f")초")
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.longPressDelay, in: 0.2...1.0, step: 0.1)
            } header: {
                Text("롱프레스 속도")
            } footer: {
                Text("짧을수록 빠르게 보조 입력이 활성화됩니다. 기본값: 0.5초")
            }

            Section {
                ForEach(settings.secondaryKeyActions) { action in
                    Button {
                        editingAction = action
                    } label: {
                        HStack {
                            Text(action.keyId)
                                .font(.title3)
                                .foregroundColor(Color(.label))
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
                                .foregroundColor(Color(.label))

                            if !action.popupOutputs.isEmpty {
                                Spacer()
                                Text(action.popupOutputs.joined(separator: " "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("키 매핑")
            } footer: {
                Text("탭하여 수정 — 각 키의 롱프레스 시 출력 문자를 변경할 수 있습니다.")
            }

            Section {
                Button("기본 매핑으로 복원") {
                    settings.secondaryKeyActions = SecondaryKeyAction.defaults
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("롱프레스")
        .sheet(item: $editingAction) { action in
            EditSecondaryKeyView(action: action) { updated in
                if let index = settings.secondaryKeyActions.firstIndex(where: { $0.keyId == updated.keyId }) {
                    settings.secondaryKeyActions[index] = updated
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LongPressSettingsView()
    }
}

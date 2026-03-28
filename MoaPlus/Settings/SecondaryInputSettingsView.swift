import SwiftUI

struct SecondaryInputSettingsView: View {
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
                Toggle("괄호 자동 닫기", isOn: $settings.autoBracketEnabled)
            } header: {
                Text("괄호")
            } footer: {
                Text("( [ { 등 여는 괄호 입력 시 닫는 괄호를 자동 삽입하고 커서를 가운데에 놓습니다.")
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
                Text("롱프레스 보조 입력")
            } footer: {
                Text("탭하여 편집. 길게 누르면 대표 문자가 입력되고, 계속 누르면 추가 후보를 선택할 수 있습니다.")
            }

            Section {
                Button("기본 매핑으로 복원") {
                    settings.secondaryKeyActions = SecondaryKeyAction.defaults
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("보조 입력")
        .sheet(item: $editingAction) { action in
            EditSecondaryKeyView(action: action) { updated in
                if let index = settings.secondaryKeyActions.firstIndex(where: { $0.keyId == updated.keyId }) {
                    settings.secondaryKeyActions[index] = updated
                }
            }
        }
    }
}

// MARK: - Edit Secondary Key View

struct EditSecondaryKeyView: View {
    let action: SecondaryKeyAction
    let onSave: (SecondaryKeyAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var visibleHint: String = ""
    @State private var primaryOutput: String = ""
    @State private var popupText: String = ""  // space-separated

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("자음 키")
                        Spacer()
                        Text(action.keyId)
                            .font(.title2)
                    }
                } header: {
                    Text("키 정보")
                }

                Section {
                    HStack {
                        Text("힌트 라벨")
                        Spacer()
                        TextField("예: 1", text: $visibleHint)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("표시")
                } footer: {
                    Text("키 우상단에 작게 표시되는 문자입니다.")
                }

                Section {
                    HStack {
                        Text("롱프레스 출력")
                        Spacer()
                        TextField("예: 1", text: $primaryOutput)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("롱프레스")
                } footer: {
                    Text("길게 누르면 입력되는 대표 문자입니다.")
                }

                Section {
                    TextField("예: 1 ! ~", text: $popupText)
                } header: {
                    Text("팝업 후보")
                } footer: {
                    Text("공백으로 구분하여 입력하세요. 길게 누른 후 드래그하면 선택할 수 있습니다.")
                }

                // Preview
                Section {
                    HStack(spacing: 16) {
                        // Key preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)

                            Text(action.keyId)
                                .font(.title2)

                            if !visibleHint.isEmpty {
                                Text(visibleHint)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(4)
                            }
                        }
                        .frame(width: 50, height: 50)

                        Image(systemName: "hand.tap")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("롱프레스 → \(primaryOutput.isEmpty ? "-" : primaryOutput)")
                                .font(.callout)
                            Text("후보: \(popupText.isEmpty ? "없음" : popupText)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("미리보기")
                }
            }
            .navigationTitle("\(action.keyId) 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let popupList = popupText
                            .split(separator: " ")
                            .map(String.init)
                        var updated = action
                        updated.visibleHint = visibleHint
                        updated.primaryLongPressOutput = primaryOutput
                        updated.popupOutputs = popupList
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(primaryOutput.isEmpty)
                }
            }
            .onAppear {
                visibleHint = action.visibleHint
                primaryOutput = action.primaryLongPressOutput
                popupText = action.popupOutputs.joined(separator: " ")
            }
        }
    }
}

import SwiftUI

struct AbbreviationSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var showingAddSheet = false
    @State private var editingExpansion: ShortcutExpansion?
    @State private var searchText = ""

    private var filteredExpansions: [ShortcutExpansion] {
        let all = settings.shortcutExpansionStore.expansions
        if searchText.isEmpty { return all }
        return all.filter {
            $0.trigger.contains(searchText) || $0.replacement.contains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Toggle("단축어 사용", isOn: $settings.abbreviationEnabled)
            } footer: {
                Text("끄면 등록된 단축어가 더 이상 자동 확장되지 않습니다. 등록된 항목은 그대로 유지되어 다시 켜면 즉시 작동합니다.")
            }

            Section {
                Toggle("변환 후 띄어쓰기 유지", isOn: $settings.abbreviationKeepConfirmSpaceEnabled)
                Toggle("백스페이스로 되돌리기", isOn: $settings.abbreviationUndoOnBackspaceEnabled)
            } footer: {
                Text("‘변환 후 띄어쓰기 유지’ 를 끄면 변환을 확정한 스페이스가 결과 뒤에 남지 않습니다. 마침표 같은 기호와 엔터는 문장에 필요한 입력이라 이 설정과 관계없이 그대로 유지됩니다.\n\n‘백스페이스로 되돌리기’ 는 변환된 직후 백스페이스를 한 번 누르면 원래 트리거로 되돌립니다. 끄면 일반 삭제처럼 한 글자씩 지워집니다.")
            }

            Section {
                Picker("트리거 제한", selection: $settings.abbreviationTriggerPolicy) {
                    ForEach(AbbreviationTriggerPolicy.allCases, id: \.self) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("트리거 제한")
            } footer: {
                Text(settings.abbreviationTriggerPolicy.footerText
                     + "\n이미 등록한 단축어는 이 설정을 바꿔도 그대로 동작합니다.")
            }

            Section {
                if filteredExpansions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("등록된 단축어가 없습니다")
                            .foregroundColor(.secondary)
                        Text("자주 쓰는 문구를 약어로 등록하면\n빠르게 입력할 수 있습니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(filteredExpansions) { expansion in
                        Button {
                            editingExpansion = expansion
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(expansion.trigger)
                                        .font(.headline)
                                        .foregroundColor(Color(.label))
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(expansion.replacement)
                                        .font(.body)
                                        .foregroundColor(Color(.label))
                                        .lineLimit(1)
                                }
                                HStack {
                                    Text(expansion.commitMode.displayName)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(4)

                                    if !expansion.isEnabled {
                                        Text("비활성")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                settings.shortcutExpansionStore.remove(id: expansion.id)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingExpansion = expansion
                            } label: {
                                Label("수정", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                Text("단축어 목록")
            } footer: {
                if !filteredExpansions.isEmpty {
                    Text("탭하여 수정, 왼쪽 스와이프로 삭제")
                }
            }

            Section {
                Button(action: { showingAddSheet = true }) {
                    Label("단축어 추가", systemImage: "plus.circle")
                }
            }

            if !ShortcutExpansion.examples.isEmpty {
                Section {
                    ForEach(ShortcutExpansion.examples) { example in
                        HStack {
                            Text(example.trigger)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(example.replacement)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("예시")
                } footer: {
                    Text("위 예시를 참고하여 자주 쓰는 문구를 등록하세요.")
                }
            }
        }
        .searchable(text: $searchText, prompt: "검색")
        .navigationTitle("단축어")
        .sheet(isPresented: $showingAddSheet) {
            EditAbbreviationView(mode: .add) { newExpansion in
                settings.shortcutExpansionStore.add(newExpansion)
            }
        }
        .sheet(item: $editingExpansion) { expansion in
            EditAbbreviationView(mode: .edit(expansion)) { updated in
                settings.shortcutExpansionStore.update(updated)
            }
        }
    }
}

// MARK: - Edit/Add Abbreviation View

struct EditAbbreviationView: View {
    enum Mode {
        case add
        case edit(ShortcutExpansion)
    }

    let mode: Mode
    let onSave: (ShortcutExpansion) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var trigger = ""
    @State private var replacement = ""
    @State private var commitMode: ShortcutExpansion.CommitMode = .onDelimiter
    @State private var isEnabled: Bool = true

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingId: UUID? {
        if case .edit(let exp) = mode { return exp.id }
        return nil
    }

    /// 트리거가 현재 정책을 통과하지 못하는 사유. 통과하면 `nil`.
    /// 빈 입력은 아직 아무것도 안 친 상태라 사유를 띄우지 않는다.
    private var triggerValidationMessage: String? {
        guard !trigger.isEmpty else { return nil }
        return KeyboardSettings.shared.abbreviationTriggerPolicy.validationMessage(for: trigger)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("예: ㅇㅎ", text: $trigger)
                } header: {
                    Text("트리거")
                } footer: {
                    // 막히는 이유를 반드시 보여준다 — 저장 버튼만 흐려지면
                    // 사용자는 왜 안 되는지 알 수 없다.
                    if let message = triggerValidationMessage {
                        Text(message)
                            .foregroundColor(.red)
                    } else {
                        Text("이 문자를 입력하면 아래 문구로 치환됩니다. 마침표 같은 기호도 넣을 수 있습니다(예: `.ㅎㅌ`). 띄어쓰기는 넣을 수 없습니다.")
                    }
                }

                Section {
                    TextField("예: 확인했습니다.", text: $replacement)
                } header: {
                    Text("치환 문구")
                }

                Section {
                    Picker("확정 방식", selection: $commitMode) {
                        ForEach(ShortcutExpansion.CommitMode.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("확정 방식")
                } footer: {
                    switch commitMode {
                    case .suggestion:
                        Text("트리거 입력 후 후보가 표시되면 탭하여 확정합니다.")
                    case .onDelimiter:
                        Text("트리거 입력 후 스페이스/엔터/문장부호를 누르면 자동 확정됩니다.")
                    }
                }

                if isEditing {
                    Section {
                        Toggle("활성화", isOn: $isEnabled)
                    }
                }
            }
            .navigationTitle(isEditing ? "단축어 수정" : "단축어 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        var expansion = ShortcutExpansion(
                            trigger: trigger,
                            replacement: replacement,
                            commitMode: commitMode,
                            isEnabled: isEnabled
                        )
                        if let id = existingId {
                            expansion.id = id
                        }
                        onSave(expansion)
                        dismiss()
                    }
                    .disabled(replacement.isEmpty
                              || KeyboardSettings.shared.abbreviationTriggerPolicy
                                  .validationMessage(for: trigger) != nil)
                }
            }
            .onAppear {
                if case .edit(let exp) = mode {
                    trigger = exp.trigger
                    replacement = exp.replacement
                    commitMode = exp.commitMode
                    isEnabled = exp.isEnabled
                }
            }
        }
    }
}

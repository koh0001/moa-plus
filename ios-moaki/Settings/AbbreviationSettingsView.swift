//
//  AbbreviationSettingsView.swift
//  ios-moaki
//

import SwiftUI

struct AbbreviationSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @State private var showingAddSheet = false
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
            Section(header: Text("단축어 목록")) {
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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(expansion.trigger)
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(expansion.replacement)
                                    .font(.body)
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
                    .onDelete(perform: deleteExpansions)
                }
            }

            Section {
                Button(action: { showingAddSheet = true }) {
                    Label("단축어 추가", systemImage: "plus.circle")
                }
            }

            if !ShortcutExpansion.examples.isEmpty {
                Section(header: Text("예시")) {
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
                } footer: {
                    Text("위 예시를 참고하여 자주 쓰는 문구를 등록하세요.")
                }
            }
        }
        .searchable(text: $searchText, prompt: "검색")
        .navigationTitle("단축어")
        .sheet(isPresented: $showingAddSheet) {
            AddAbbreviationView { newExpansion in
                settings.shortcutExpansionStore.add(newExpansion)
            }
        }
    }

    private func deleteExpansions(at offsets: IndexSet) {
        for index in offsets {
            let expansion = filteredExpansions[index]
            settings.shortcutExpansionStore.remove(id: expansion.id)
        }
    }
}

/// Sheet for adding a new abbreviation
struct AddAbbreviationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trigger = ""
    @State private var replacement = ""
    @State private var commitMode: ShortcutExpansion.CommitMode = .onDelimiter
    let onSave: (ShortcutExpansion) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("트리거")) {
                    TextField("예: ㅎㅅㅁㅇ", text: $trigger)
                } footer: {
                    Text("이 문자를 입력하면 아래 문구로 치환됩니다.")
                }

                Section(header: Text("치환 문구")) {
                    TextField("예: koh@move.kr", text: $replacement)
                }

                Section(header: Text("확정 방식")) {
                    Picker("확정 방식", selection: $commitMode) {
                        ForEach(ShortcutExpansion.CommitMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    switch commitMode {
                    case .suggestion:
                        Text("트리거 입력 후 후보가 표시되면 탭하여 확정합니다.")
                    case .onDelimiter:
                        Text("트리거 입력 후 스페이스/엔터/문장부호를 누르면 자동 확정됩니다.")
                    }
                }
            }
            .navigationTitle("단축어 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let expansion = ShortcutExpansion(
                            trigger: trigger,
                            replacement: replacement,
                            commitMode: commitMode
                        )
                        onSave(expansion)
                        dismiss()
                    }
                    .disabled(trigger.isEmpty || replacement.isEmpty)
                }
            }
        }
    }
}

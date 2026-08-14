//
//  SettingsMainView.swift
//  MoaPlus
//

import SwiftUI

struct SettingsMainView: View {
    @State private var searchText = ""

    private var results: [SettingsEntry] { SettingsCatalog.search(searchText) }
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        List {
            if isSearching {
                searchResults
            } else {
                browseList
            }
        }
        // 설정이 11개 화면으로 늘면서, 기능의 앱 내부 명칭(멀티스트로크·섹터 각도·
        // 보조 매핑)을 모르면 도달할 방법이 없어졌다. 검색은 그 어휘 다리다 —
        // `SettingsCatalog` 가 "진입앵글"·"지구봉" 같은 사용자 어휘까지 받는다.
        .searchable(text: $searchText, prompt: "설정 검색 (예: 각도, 지구본, 힌트)")
        .navigationTitle("설정")
    }

    @ViewBuilder
    private var searchResults: some View {
        if results.isEmpty {
            Section {
                ContentUnavailableView(
                    "찾는 설정이 없습니다",
                    systemImage: "magnifyingglass",
                    description: Text("‘도움말 › 이럴 때 어떻게 하나요’에서 증상으로 찾아볼 수 있습니다.")
                )
            }
        } else {
            Section {
                ForEach(results) { entry in
                    NavigationLink(destination: entry.destination.view) {
                        HStack {
                            Label(entry.title, systemImage: entry.icon)
                            Spacer()
                            Text(entry.destination.breadcrumb)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("검색 결과 \(results.count)개")
            }
        }
    }

    @ViewBuilder
    private var browseList: some View {
        Section {
            NavigationLink(destination: HelpView()) {
                Label("이럴 때 어떻게 하나요", systemImage: "questionmark.circle")
            }
        } footer: {
            Text("증상으로 설정을 찾습니다. 튜토리얼과 타이핑 연습도 여기 있습니다.")
        }

        Section {
            NavigationLink(destination: KeyboardSettingsView()) {
                Label("키보드", systemImage: "keyboard")
            }
            NavigationLink(destination: AppearanceSettingsView()) {
                Label("외형", systemImage: "paintbrush")
            }
            NavigationLink(destination: FeedbackSettingsView()) {
                Label("소리 · 진동", systemImage: "waveform")
            }
            NavigationLink(destination: AbbreviationSettingsView()) {
                Label("단축어", systemImage: "text.badge.plus")
            }
        }

        Section {
            NavigationLink(destination: DebugBoardView()) {
                Label("입력 기록 보드", systemImage: "note.text")
            }
        } footer: {
            Text("모아+ 키보드로 자유롭게 입력해 보고 오타 사례를 저장해 둘 수 있습니다.")
        }

        Section {
            NavigationLink(destination: AboutView()) {
                Label("앱 정보", systemImage: "info.circle")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsMainView()
    }
}

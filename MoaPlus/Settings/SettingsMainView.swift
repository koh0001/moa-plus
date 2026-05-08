//
//  SettingsMainView.swift
//  MoaPlus
//

import SwiftUI

struct SettingsMainView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(destination: KeyboardSettingsView()) {
                    Label("키보드", systemImage: "keyboard")
                }
                NavigationLink(destination: AppearanceSettingsView()) {
                    Label("외형", systemImage: "paintbrush")
                }
                NavigationLink(destination: FeedbackSettingsView()) {
                    Label("반응", systemImage: "waveform")
                }
                NavigationLink(destination: AbbreviationSettingsView()) {
                    Label("단축어", systemImage: "text.badge.plus")
                }
            }
            Section {
                NavigationLink(destination: HelpView()) {
                    Label("도움말", systemImage: "questionmark.circle")
                }
                NavigationLink(destination: AboutView()) {
                    Label("앱 정보", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("설정")
    }
}

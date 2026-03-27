//
//  SettingsMainView.swift
//  ios-moaki
//

import SwiftUI

struct SettingsMainView: View {
    var body: some View {
        List {
            Section(header: Text("입력")) {
                NavigationLink(destination: InputSettingsView()) {
                    Label("모아키 입력", systemImage: "hand.draw")
                }
                NavigationLink(destination: SecondaryInputSettingsView()) {
                    Label("보조 입력", systemImage: "textformat.123")
                }
                NavigationLink(destination: SpecialCharSettingsView()) {
                    Label("특수문자", systemImage: "character.textbox")
                }
            }

            Section(header: Text("생산성")) {
                NavigationLink(destination: AbbreviationSettingsView()) {
                    Label("단축어 / 약어 확장", systemImage: "text.badge.plus")
                }
            }

            Section(header: Text("외형")) {
                NavigationLink(destination: AppearanceSettingsView()) {
                    Label("외형", systemImage: "paintbrush")
                }
                NavigationLink(destination: FeedbackSettingsView()) {
                    Label("반응", systemImage: "waveform")
                }
            }
        }
        .navigationTitle("설정")
    }
}

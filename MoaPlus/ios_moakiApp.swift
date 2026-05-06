//
//  MoaPlusApp.swift
//  MoaPlus
//
//  Created by Jeffrey Kim on 2026/1/28.
//

import SwiftUI

@main
struct MoaPlusApp: App {
    @State private var appGroupErrorMessage: String? = KeyboardSettings.appGroupSetupErrorMessage()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert(
                    "키보드 설정 동기화 오류",
                    isPresented: Binding(
                        get: { appGroupErrorMessage != nil },
                        set: { if !$0 { appGroupErrorMessage = nil } }
                    ),
                    presenting: appGroupErrorMessage
                ) { _ in
                    Button("확인", role: .cancel) {}
                } message: { message in
                    Text(message)
                }
        }
    }
}

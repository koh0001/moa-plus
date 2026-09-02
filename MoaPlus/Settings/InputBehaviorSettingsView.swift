// InputBehaviorSettingsView.swift
// MoaPlus

import SwiftUI

struct InputBehaviorSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared

    var body: some View {
        List {
            Section {
                Toggle("괄호 자동 닫기", isOn: $settings.autoBracketEnabled)
            } footer: {
                Text("( [ { 등 여는 괄호 입력 시 닫는 괄호를 자동 삽입하고 커서를 가운데에 놓습니다.")
            }

            Section {
                Toggle("더블 스페이스로 마침표 입력", isOn: $settings.periodOnDoubleSpaceEnabled)
            } footer: {
                Text("글자 뒤에서 스페이스를 두 번 누르면 마침표와 공백(. )으로 바꿉니다.")
            }

            Section {
                Toggle("영문 문장 첫 글자 대문자", isOn: $settings.englishAutoCapitalizeEnabled)
                Toggle("영문 키 길게 눌러 대문자", isOn: $settings.englishLongPressUppercaseEnabled)
            } header: {
                Text("영문")
            } footer: {
                Text("문장 첫 글자 대문자를 켜면 문장이 시작될 때(빈 칸이거나 . ! ? 뒤) 시프트가 자동으로 켜집니다. 이메일·비밀번호처럼 대문자를 원하지 않는 입력란에서는 동작하지 않습니다. 길게 눌러 대문자는 시프트를 누르지 않고도 q~m 키를 꾹 눌러 대문자를 입력합니다.")
            }

            Section {
                Toggle("스페이스 드래그로 커서 이동", isOn: $settings.cursorMoveBySpaceDragEnabled)
                if settings.cursorMoveBySpaceDragEnabled {
                    Picker("연속 이동 속도", selection: $settings.cursorRepeatSpeed) {
                        Text("느림").tag(0)
                        Text("보통").tag(1)
                        Text("빠름").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text("스페이스바를 길게 누른 채 드래그하면 커서가 좌우로 이동합니다. 바 양쪽 끝(15%)까지 밀고 유지하면 그 방향으로 연속 이동하며, 속도는 위에서 조절합니다.")
            }

            Section {
                Toggle("마지막 모드 기억", isOn: $settings.rememberLastKeyboardMode)
            } footer: {
                Text("키보드를 닫았다 다시 열 때 마지막으로 쓴 한글/영문 모드를 유지합니다. 끄면 항상 한글로 시작합니다.")
            }
        }
        .navigationTitle("입력 동작")
    }
}

#Preview {
    NavigationStack {
        InputBehaviorSettingsView()
    }
}

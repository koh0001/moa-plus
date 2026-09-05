import SwiftUI

struct FeedbackSettingsView: View {
    @ObservedObject private var settings = KeyboardSettings.shared
    @Environment(\.scenePhase) private var scenePhase
    /// 익스텐션이 남긴 전체 접근 기록. `@Published` 가 아니라 화면이 뜰 때와
    /// 앱이 전면으로 돌아올 때(iOS 설정에서 켜고 온 직후) 다시 읽는다.
    @State private var fullAccessStatus: FullAccessStatus = KeyboardSettings.shared.fullAccessStatus

    var body: some View {
        List {
            // 전체 접근이 꺼진 것을 익스텐션이 확인한 경우에만 경고한다.
            // .unknown(키보드 미기동)에 띄우면 설치 직후 사용자를 겁준다.
            if fullAccessStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("전체 접근이 꺼져 있어 진동과 클릭음이 울리지 않습니다", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.orange)
                        Text("iOS 가 키보드 앱의 진동을 '전체 접근 허용' 없이는 막습니다. 설정 → 일반 → 키보드 → 키보드 → 모아+ → '전체 접근 허용'을 켜 주세요. 키 입력은 외부로 전송되지 않습니다.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("iOS 키보드 설정 열기", systemImage: "arrow.up.right.square")
                                .font(.footnote.weight(.medium))
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("fullAccessDeniedBanner")
                }
            }

            Section {
                Toggle("키 클릭 사운드", isOn: $settings.clickSoundEnabled)
            } header: {
                Text("사운드")
            }

            Section {
                Toggle("햅틱 반응", isOn: $settings.themeSettings.hapticEnabled)

                if settings.themeSettings.hapticEnabled {
                    Picker("햅틱 강도", selection: $settings.themeSettings.hapticStrength) {
                        ForEach(HapticStrength.allCases, id: \.self) { strength in
                            Text(strength.displayName).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("햅틱")
            } footer: {
                // iOS restricts UIImpactFeedbackGenerator inside keyboard
                // extensions unless Full Access is granted. The toggles
                // above stay user-controlled; this footer just explains
                // why vibration may be silent.
                if settings.themeSettings.hapticEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("진동이 느껴지지 않으면 '전체 접근 허용' 권한이 필요합니다.")
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("iOS 키보드 설정 열기", systemImage: "arrow.up.right.square")
                                .font(.footnote)
                        }
                        Text("설정 → 일반 → 키보드 → 키보드 → 모아+ → '전체 접근 허용' 토글을 켜주세요. 키 입력은 외부로 전송되지 않으며, 햅틱 진동·사운드·앱 설정 동기화를 위해서만 사용됩니다.")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if settings.themeSettings.hapticEnabled {
                Section {
                    Toggle("탭", isOn: $settings.themeSettings.hapticOnTap)
                    Toggle("롱프레스 팝업", isOn: $settings.themeSettings.hapticOnLongPress)
                    Toggle("레이어 전환", isOn: $settings.themeSettings.hapticOnLayerSwitch)
                    Toggle("약어 확정", isOn: $settings.themeSettings.hapticOnAbbreviationConfirm)
                } header: {
                    Text("이벤트별 햅틱")
                } footer: {
                    Text("각 이벤트별로 햅틱 반응을 개별 설정할 수 있습니다.")
                }
            }

        }
        // 제목이 "반응"이면 "반응속도가 느리다"는 사용자를 사운드·햅틱 화면으로
        // 끌어들여 빈손으로 돌려보낸다. 설정 루트의 행 레이블과 맞춘다.
        .navigationTitle("소리 · 진동")
        .onAppear { fullAccessStatus = KeyboardSettings.shared.fullAccessStatus }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { fullAccessStatus = KeyboardSettings.shared.fullAccessStatus }
        }
    }
}

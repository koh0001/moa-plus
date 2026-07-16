import SwiftUI

struct ContentView: View {
    private let deepBlue = Color(red: 0.10, green: 0.10, blue: 0.18)
    private let accentBlue = Color(red: 0.26, green: 0.38, blue: 0.93)

    @State private var showFirstLaunchModal = false
    @State private var showWhatsNewModal = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [deepBlue, accentBlue.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Hero
                    VStack(spacing: 10) {
                        Image("AppIconImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: accentBlue.opacity(0.4), radius: 12, y: 4)

                        Text("모아+")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)

                        Text("손끝으로 완성하는 한글")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    // Status card
                    KeyboardStatusCard(accentColor: accentBlue)
                        .padding(.horizontal, 24)

                    Spacer()

                    // Actions
                    VStack(spacing: 12) {
                        NavigationLink(destination: TutorialContainerView()) {
                            Label("제스처 연습하기", systemImage: "hand.draw")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(accentBlue)
                                )
                        }

                        NavigationLink(destination: TypingPracticeListView()) {
                            Label("자판 연습", systemImage: "keyboard")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white.opacity(0.25), lineWidth: 1)
                                        )
                                )
                        }

                        NavigationLink(destination: SettingsMainView()) {
                            Label("모아키 설정", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.25))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            let settings = KeyboardSettings.shared
            if !settings.firstLaunchModalShown {
                // 신규 사용자: 레이아웃 선택 모달만 보여주고, "새로운 기능" 모달은
                // 건너뛴다(이미 모든 기능이 처음이므로). lastSeen 을 현재 버전으로
                // 미리 기록해 다음 실행에서도 What's New 가 뜨지 않게 한다.
                if settings.lastSeenWhatsNewVersion != Self.appVersion {
                    settings.lastSeenWhatsNewVersion = Self.appVersion
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showFirstLaunchModal = true
                }
            } else if settings.lastSeenWhatsNewVersion != Self.appVersion {
                // 업데이트한 기존 사용자: "새로운 기능" 모달을 1회 표시.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showWhatsNewModal = true
                }
            }
        }
        .sheet(isPresented: $showFirstLaunchModal) {
            FirstLaunchLayoutModalView()
        }
        .sheet(isPresented: $showWhatsNewModal) {
            NewFeaturesModalView()
        }
    }

    /// 현재 앱 버전. `NewFeaturesModalView.appVersion` 과 같은 값을 써야 모달이
    /// 닫힌 뒤 재표시되지 않는다.
    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.2"
    }
}

// MARK: - Keyboard Status Card

struct KeyboardStatusCard: View {
    var accentColor: Color = .accentColor

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(accentColor)
                Text("키보드 활성화")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                stepRow(num: 1, text: "설정 → 일반 → 키보드 → 새 키보드 추가")
                stepRow(num: 2, text: "목록에서 '모아+' 선택")
                stepRow(num: 3, text: "🌐 버튼으로 키보드 전환")
            }

            Button(action: openSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("iOS 설정 열기")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.5))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func stepRow(num: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(num)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(accentColor.opacity(0.7)))
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}

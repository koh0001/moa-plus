import SwiftUI

struct ContentView: View {
    private let deepBlue = Color(red: 0.10, green: 0.10, blue: 0.18)
    private let accentBlue = Color(red: 0.26, green: 0.38, blue: 0.93)

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
                stepRow(num: 2, text: "목록에서 '모아+' 선택 → 전체 접근 허용")
                stepRow(num: 3, text: "🌐 버튼으로 키보드 전환")
            }

            // Full access explanation
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("전체 접근이 필요한 이유")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                }
                Text("테마, 배경 이미지, 단축어 등 앱 설정을 키보드에 반영하기 위해 필요합니다. 입력 데이터는 수집하지 않으며 네트워크를 사용하지 않습니다.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.08))
            )

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

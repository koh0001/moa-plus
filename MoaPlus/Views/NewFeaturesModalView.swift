import SwiftUI

/// 업데이트한 기존 사용자에게 1회 표시되는 "새로운 기능" 모달.
/// `FirstLaunchLayoutModalView` 와 같은 sheet 톤(시스템 배경 + 카드)을 따른다.
/// 닫으면 현재 앱 버전을 `lastSeenWhatsNewVersion` 에 기록해 다음 실행부터는
/// 다시 뜨지 않는다. 트리거 분기는 `ContentView.onAppear` 에서 FirstLaunch
/// 모달과 배타적으로 처리한다(신규 사용자는 이 모달을 건너뜀).
struct NewFeaturesModalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = KeyboardSettings.shared

    fileprivate struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let tint: Color
        let title: String
        let detail: String
    }

    private let features: [Feature] = [
        Feature(
            icon: "arrow.up.right",
            tint: .blue,
            title: "자음에서 바로 모음",
            detail: "자음 키를 ㅣ/ㅡ 방향(↗↖ / ↙↘)으로 긋고 이어서 그으면 모음이 완성됩니다. 예: ㄱ을 ↗→ = ‘가’, ↙↑ = ‘고’."
        ),
        Feature(
            icon: "ipad",
            tint: .purple,
            title: "iPad 정식 지원",
            detail: "아이패드 전용 레이아웃과 가로·세로 분리 키보드를 지원합니다. 큰 화면에서 더 편하게 입력하세요."
        ),
        Feature(
            icon: "dial.medium",
            tint: .orange,
            title: "입력 정확도 대폭 개선",
            detail: "8방향 좌·우 각도를 따로 조정하고, 4방향 전용 모드와 멀티스트로크 민감도로 내 손에 맞게 맞출 수 있습니다. 설정 → 긋기 테스트에서 실시간 확인도 가능합니다."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(features) { featureRow($0) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            footer
        }
        .onDisappear { markSeen() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            Text("이번 업데이트")
                .font(.title2.bold())
            Text("모아+ v\(Self.appVersion) 새로운 기능")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                markSeen()
                dismiss()
            } label: {
                Text("시작하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
            }
            Text("홈의 ‘제스처 연습하기’와 ‘자판 연습’에서 새 입력법을 익혀보세요.")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func featureRow(_ f: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: f.icon)
                .font(.system(size: 22))
                .foregroundColor(f.tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(f.tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(f.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(f.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    /// 현재 앱 버전(CFBundleShortVersionString). 트리거 비교와 동일한 값을 써야
    /// 모달이 닫힌 뒤 재표시되지 않는다.
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.7.2"
    }

    private func markSeen() {
        if settings.lastSeenWhatsNewVersion != Self.appVersion {
            settings.lastSeenWhatsNewVersion = Self.appVersion
        }
    }
}

#Preview {
    NewFeaturesModalView()
}

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
            icon: "arrow.up.and.down.and.arrow.left.and.right",
            tint: .blue,
            title: "키보드 높이 조절",
            detail: "설정 → 키보드 → 크기 · 전환 키에서 키보드 높이를 85%~135%로 조절할 수 있습니다. 미리보기를 보면서 맞추고, 언제든 기본값으로 되돌릴 수 있습니다."
        ),
        Feature(
            icon: "globe",
            tint: .green,
            title: "키보드 전환 키",
            detail: "설정 → 키보드 → 크기 · 전환 키에서 '키보드 전환 키 표시'를 켜면 기능 행 맨 왼쪽에 지구본 키가 생겨 애플 기본 키보드 등으로 바로 전환합니다. 기본은 꺼져 있고, iOS 26 아이폰은 시스템이 키보드 아래에 지구본 바를 직접 표시합니다."
        ),
        Feature(
            icon: "dial.medium",
            tint: .orange,
            title: "각도가 안 맞으면 조절하세요",
            detail: "오타가 잦다면 설정 → 키보드 → 제스처에서 8방향 좌·우 각도를 따로 넓히거나 4방향 전용 모드를 켜 보세요. 긋기 테스트에서 실시간으로 확인할 수 있습니다."
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

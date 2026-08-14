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

    fileprivate struct FeatureGroup: Identifiable {
        let id = UUID()
        let title: String
        let features: [Feature]
    }

    /// v2.0 — 갤럭시 순정 모아키 정합 릴리스. 항목이 많아 그룹 헤더로 나눈다.
    private let groups: [FeatureGroup] = [
        FeatureGroup(title: "입력 방식 — 갤럭시 모아키 손버릇 그대로", features: [
            Feature(
                icon: "arrow.uturn.down",
                tint: .blue,
                title: "대각선 왕복으로 ㅐ·ㅔ·ㅢ",
                detail: "↗로 나갔다 ↙로 되돌아오면 ㅐ, ↖↘는 ㅔ, ↙↗는 ㅢ. 갤럭시에서 쓰던 왕복 손버릇이 그대로 통합니다."
            ),
            Feature(
                icon: "arrow.up.arrow.down",
                tint: .indigo,
                title: "ㅚ에서 이어 긋는 세로 체인",
                detail: "위·아래(ㅚ)로 긋고 →면 ㅘ, →←면 ㅙ, ←면 ㅕ. 고→괴→과→괘처럼 떼지 않고 이어집니다."
            ),
            Feature(
                icon: "circle.grid.cross",
                tint: .purple,
                title: "ㆍ 조합 확장",
                detail: "외+ㆍ=와, 위+ㆍ=워, 애+ㆍ=얘, 오+ㆍ=요↔오 토글까지 — 천지인 ㆍ 조합이 순정처럼 이어집니다."
            ),
            Feature(
                icon: "delete.left",
                tint: .teal,
                title: "한 자소씩 지우기",
                detail: "백스페이스가 받침 → 모음 → 자음 순서로 지웁니다. '한'에서 한 번 지우면 '하', '가'에서 지우면 'ㄱ'이 남습니다."
            ),
            Feature(
                icon: "checkmark.shield",
                tint: .green,
                title: "오타 완화",
                detail: "순정 모아키를 실측해 인식 기준을 맞췄습니다. 손을 뗄 때 튕기는 꼬리, 방향을 꺾는 모서리의 흔들림이 엉뚱한 모음으로 바뀌는 오타가 줄었습니다."
            ),
        ]),
        FeatureGroup(title: "새 도구", features: [
            Feature(
                icon: "graduationcap",
                tint: .orange,
                title: "튜토리얼 · 연습 새 단장",
                detail: "새 입력 경로에 맞춰 튜토리얼과 타이핑 연습을 다시 짰습니다. 왕복 ㅐ·ㅔ·ㅢ와 세로 체인을 여기서 익혀보세요."
            ),
            Feature(
                icon: "scope",
                tint: .pink,
                title: "긋기 테스트 — 획별 수치",
                detail: "설정 → 키보드 → 긋기 → 실시간 테스트에서 획마다 방향·각도·길이가 숫자로 보입니다. 어디서 오타가 나는지 직접 확인할 수 있습니다."
            ),
            Feature(
                icon: "note.text",
                tint: .brown,
                title: "입력 기록 보드",
                detail: "설정 하단의 보드에서 자유롭게 입력해 보고, 오타 사례를 저장해 개발자에게 메일로 바로 보낼 수 있습니다. 획별 계측이 함께 담겨 오타 분석이 빨라집니다."
            ),
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups) { group in
                        Text(group.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.top, 6)
                        ForEach(group.features) { featureRow($0) }
                    }
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

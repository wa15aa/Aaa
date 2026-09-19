import SwiftUI

/// 一页式 onboarding（W7，参考 HabitKit 欢迎页卖点卡片结构）：
/// 首启动展示一次；设置页"Replay onboarding"重置 steady.onboarded 后可重看。
/// 卖点顺序对齐 replan-v2 §2 支柱：断签不死 > 买断 > 加密备份 > Quit。
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Steady")
                .font(.system(size: 40, weight: .bold))
            Text("A habit tracker that forgives you.")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                card("checkmark.circle.fill", "Never miss twice",
                     "Miss a day? Your streak survives. Only two misses in a row start a new journey.")
                card("tag.fill", "One purchase, forever",
                     "$12.99 once. No subscription, no tricks.")
                card("lock.shield.fill", "Encrypted iCloud backup",
                     "Your history survives a new phone — encrypted end to end.")
                card("bandage.fill", "Quit habits, too",
                     "Quitting smoking or sugar? A slip day doesn't break you.")
            }
            .padding(.horizontal, 24)

            Spacer()
            Button {
                UserDefaults.standard.set(true, forKey: "steady.onboarded")
                dismiss()
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func card(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
}

import SwiftUI

/// 买断制 paywall（MVP_SPEC §3.6 / DoD#4）：
/// 价格印在首屏第一行，无倒计时/无二次确认套路，第 4 个习惯触发。
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitManager.shared
    var onUnlocked: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            // DoD#4：价格在第一屏第一行位置
            Text(store.product?.displayPrice ?? "$12.99")
                .font(.system(size: 44, weight: .bold))
            Text("一次买断，终身使用。没有订阅，没有套路。")
                .font(.title3)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                feature("无限习惯（免费版 3 个）")
                feature("iCloud 加密备份，删了重装也不丢")
                feature("支持独立开发者继续做这个小工具")
            }
            .padding(.vertical)

            Button {
                Task {
                    if await store.purchase() {
                        onUnlocked?()
                        dismiss()
                    }
                }
            } label: {
                Text("买断 \(store.product?.displayPrice ?? "$12.99")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Button("恢复购买") {
                Task { await store.restore() }
            }
            .font(.footnote)

            Button("先不用") { dismiss() }
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(28)
    }

    private func feature(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
            Text(text)
        }
    }
}

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
            Text("One purchase. Yours forever.\nNo subscription, no tricks.")
                .font(.title3)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                feature("Unlimited habits (free version: 3)")
                feature("Encrypted iCloud backup — survives reinstalls")
                feature("Support an indie maker, not a subscription machine")
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
                Text("Buy once — \(store.product?.displayPrice ?? "$12.99")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Button("Restore purchase") {
                Task { await store.restore() }
            }
            .font(.footnote)

            Button("Not now") { dismiss() }
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

import SwiftUI

/// 买断制 paywall（MVP_SPEC §3.6 / DoD#4 / replan-v2 §5）：
/// 价格印在第一行，无倒计时/无二次确认套路。
/// 双触发：第 4 个习惯数量墙（保留）+ 功能点触发（requestedFeature 置顶，抄 HabitKit 07 页）。
/// 文案纪律：不提"习惯数限制"，主打解锁统计/Quit/加密备份（replan-v2 §5 建议 A）。
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreKitManager.shared
    var onUnlocked: (() -> Void)? = nil
    /// 功能点触发时置顶显示用户刚想用的功能（如 "Detailed stats & full history"）
    var requestedFeature: String? = nil

    @State private var purchaseFailed = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if let requestedFeature {
                VStack(spacing: 4) {
                    Text("UNLOCKS")
                        .font(.caption).bold()
                        .foregroundColor(.secondary)
                    Text(requestedFeature)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(10)
            }
            // DoD#4：价格在第一屏第一行位置
            Text(store.product?.displayPrice ?? "$12.99")
                .font(.system(size: 44, weight: .bold))
            Text("One purchase. Yours forever.\nNo subscription, no tricks.")
                .font(.title3)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                feature("Detailed stats & full history heatmap")
                feature("Quit habits — slip days don't break you")
                feature("Encrypted iCloud backup — survives reinstalls")
            }
            .padding(.vertical)

            Button {
                purchaseFailed = false
                Task {
                    if await store.purchase() {
                        onUnlocked?()
                        dismiss()
                    } else {
                        purchaseFailed = true
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

            // HabitKit 截图实证加载失败态常见：StoreKit 拉不到商品/购买失败都要有文案
            if store.product == nil || purchaseFailed {
                Text("Something went wrong. Try again later.")
                    .font(.footnote)
                    .foregroundColor(.red)
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
        .task {
            if store.product == nil { await store.refresh() }
        }
    }

    private func feature(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
            Text(text)
        }
    }
}

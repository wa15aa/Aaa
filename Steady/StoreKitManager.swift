import Foundation
import StoreKit

/// StoreKit 2 买断制（MVP_SPEC §3.6）：$12.99 lifetime，无订阅。
/// Pro 状态以 Transaction.currentEntitlements 为准，UserDefaults 仅作冷启动缓存。
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    static let lifetimeID = "sh.steadyhabit.lifetime"

    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool

    private init() {
        isPro = UserDefaults.standard.bool(forKey: "steady.isPro")
        Task { await refresh() }
        Task { await listenTransactions() }
    }

    func refresh() async {
        product = try? await Product.products(for: [Self.lifetimeID]).first
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.lifetimeID {
                setPro(true)
            }
        }
    }

    /// 购买。返回是否成功（含"已拥有则恢复"）。
    @discardableResult
    func purchase() async -> Bool {
        guard let product = product else { return false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let t) = verification else { return false }
                await t.finish()
                setPro(true)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func setPro(_ v: Bool) {
        isPro = v
        UserDefaults.standard.set(v, forKey: "steady.isPro")
    }

    private func listenTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let t) = result, t.productID == Self.lifetimeID {
                await t.finish()
                setPro(true)
            }
        }
    }
}

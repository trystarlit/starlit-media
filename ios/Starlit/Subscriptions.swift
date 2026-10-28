import SwiftUI
import RevenueCat

/// The hard paywall: RevenueCat offerings, purchase and restore.
/// Without a RevenueCat key it stays off and every purchase "succeeds", so the app can still be tested end to end.
@MainActor
final class Subscriptions: ObservableObject {
    /// True once the user has the `pro` entitlement (or RevenueCat isn't set up yet).
    @Published private(set) var isActive = !Config.hasRevenueCat
    /// False until the first customer-info check comes back, so we don't flash the paywall on launch.
    @Published private(set) var checked = !Config.hasRevenueCat
    @Published private(set) var annual: Package?
    @Published private(set) var monthly: Package?

    init() {
        guard Config.hasRevenueCat else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.revenueCatKey)
        Task { await refresh() }
    }

    /// Ties purchases to the Supabase user, so a restore on a new phone finds the same customer.
    func logIn(_ userID: String) async {
        guard Config.hasRevenueCat else { return }
        if let result = try? await Purchases.shared.logIn(userID) { apply(result.customerInfo) }
    }

    func refresh() async {
        guard Config.hasRevenueCat else { return }
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
        checked = true
        if let current = try? await Purchases.shared.offerings().current {
            annual = current.annual
            monthly = current.monthly
        }
    }

    /// Returns true when the user now has access. Throws a readable error; a cancel returns false.
    func purchase(annual wantsAnnual: Bool) async throws -> Bool {
        guard Config.hasRevenueCat else { return true }
        guard let package = wantsAnnual ? annual : monthly else { throw SubscriptionError.notLoaded }
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled { return false }
        apply(result.customerInfo)
        return isActive
    }

    func restore() async throws -> Bool {
        guard Config.hasRevenueCat else { return true }
        apply(try await Purchases.shared.restorePurchases())
        return isActive
    }

    #if DEBUG
    /// Debug builds only: get past the paywall until the next launch, so a half-set-up RevenueCat project can't lock us out.
    func skipForTesting() { isActive = true }
    #endif

    private func apply(_ info: CustomerInfo) {
        isActive = info.entitlements[Config.entitlement]?.isActive == true
    }
}

enum SubscriptionError: LocalizedError {
    case notLoaded
    var errorDescription: String? { "couldn't reach the app store. check your connection and try again." }
}

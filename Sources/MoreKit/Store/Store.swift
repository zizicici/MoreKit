//
//  Store.swift
//  MoreKit
//

import Foundation
import StoreKit

extension Notification.Name {
    public static let LifetimeMembership = Notification.Name(rawValue: "com.zizicici.morekit.store.purchase.lifetime")
    public static let StoreInfoLoaded = Notification.Name(rawValue: "com.zizicici.morekit.store.info.loaded")
    public static let StoreProductsLoaded = Notification.Name(rawValue: "com.zizicici.morekit.store.products.loaded")
}

public enum StoreError: Error {
    case failedVerification
    case productsUnavailable
}

extension StoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedVerification:
            return String(localized: "store.error.failedVerification", bundle: .module)
        case .productsUnavailable:
            return String(localized: "store.error.productsUnavailable", bundle: .module)
        }
    }
}

public enum ProTier: Sendable {
    case lifetime
    case none
}

public enum PurchaseOutcome: Sendable {
    case success(Transaction)
    case pending
    case cancelled
    case alreadyOwned
}

private final class StoreStateSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var hasValidMembership = false
    private var membershipDisplayPrice: String?

    func update(hasValidMembership: Bool, membershipDisplayPrice: String?) {
        lock.lock()
        self.hasValidMembership = hasValidMembership
        self.membershipDisplayPrice = membershipDisplayPrice
        lock.unlock()
    }

    func hasValidMembershipValue() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return hasValidMembership
    }

    func membershipDisplayPriceValue() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return membershipDisplayPrice
    }

    func proTierValue() -> ProTier {
        hasValidMembershipValue() ? .lifetime : .none
    }
}

/// Result of reconciling against StoreKit for the registered product.
///
/// `.missing` is deliberately distinct from `.revoked`: a non-consumable can be *temporarily* absent
/// from StoreKit (cold start, offline launch, propagation lag), which must never be mistaken for the
/// user losing the entitlement.
enum EntitlementScanOutcome {
    case owned
    case revoked
    case missing
}

/// # Membership model
///
/// Membership for the lifetime non-consumable is a **latch** that only goes *up* on its own:
/// - set **on** (and kept on) by any positive proof — a purchase, a verified non-revoked
///   `Transaction.updates` delivery, or an `.owned` reconciliation. Granting is immediate and sticky.
/// - set **off** only when a *reconciliation* re-reads StoreKit and observes `.revoked` (a transaction
///   whose `revocationDate` is non-nil — refunds and Family Sharing removal). Reconciliations run at
///   launch, on user-initiated Restore, and when a revoked `Transaction.updates` arrives.
/// - **never** changed by the mere absence of an entitlement (`.missing`) — that is ambiguous (cold
///   start, offline, propagation lag) and must not downgrade a paying user.
///
/// The flow is deliberately simple and biased toward the paying user: a reconciliation returns `.revoked`
/// only when StoreKit genuinely reports the product as revoked, and `Transaction.latest` is consulted so
/// a newer purchase is never mistaken for a stale revocation. A purchase that lands while a reconciliation
/// is mid-scan always wins — a single `grantGeneration` counter makes the reconciliation skip a `.revoked`
/// clear when a grant occurred during its scan — so **an owning/paying user is never downgraded.** Accepted
/// trade-off: a refund is reflected at the next reconciliation (launch / Restore / revoked update) rather
/// than instantly.
@MainActor
public class Store: ObservableObject {
    public nonisolated static let shared = Store()
    private static let syncMissingEntitlementRetryCount = 4
    private static let syncMissingEntitlementRetryDelayNanoseconds: UInt64 = 300_000_000

    @Published public private(set) var memberships: [Product] = []

    @Published public private(set) var purchasedProductIDs: Set<String> = [] {
        didSet {
            // Keep the cross-thread snapshot consistent BEFORE any observer of the notifications below runs,
            // so a `.LifetimeMembership` / `.StoreInfoLoaded` handler reading `proTier()`/`hasValidMembership()`
            // sees the new state. (The notifications themselves are posted from `applyMembership`, in order.)
            refreshSnapshot()
        }
    }

    public var purchasedMemberships: [Product] {
        memberships.filter { purchasedProductIDs.contains($0.id) }
    }

    private var updateListenerTask: Task<Void, Error>? = nil
    private nonisolated let snapshot = StoreStateSnapshot()

    /// Incremented on every positive-proof grant. A reconciliation captures it before scanning and skips
    /// a `.revoked` clear if it changed, so a purchase that lands during the scan is never clobbered.
    private var grantGeneration = 0

    nonisolated init() {}

    private func refreshSnapshot() {
        snapshot.update(
            hasValidMembership: !purchasedProductIDs.isEmpty,
            membershipDisplayPrice: memberships.first?.displayPrice
        )
    }

    internal func start() {
        guard updateListenerTask == nil else { return }
        hydrateMembershipFromCacheIfNeeded()
        refreshSnapshot()
        updateListenerTask = listenForTransactions()
        Task { await updateCustomerProductStatus() }
        Task { await requestProducts() }
    }

    public func retryRequestProducts() {
        Task { await requestProducts() }
    }

    nonisolated func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    // Only finish transactions for the registered product; leave any other IAPs the host
                    // app may sell for its own transaction listener to handle and finish.
                    if await self.applyVerifiedMembershipUpdate(transaction) {
                        await transaction.finish()
                    }
                } catch {
                    // Unverified transactions are intentionally not finished per Apple's guidance;
                    // StoreKit may re-deliver them across launches until they verify or are cleared.
                    print("Transaction failed verification (not finished): \(error)")
                }
            }
        }
    }

    nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func requestProducts() async {
        guard let productID = MoreKit.productID else { return }

        do {
            let products = try await Product.products(for: [productID])
            let filtered = products.filter { $0.type == .nonConsumable }
            if memberships != filtered {
                memberships = filtered
                refreshSnapshot()
                NotificationCenter.default.post(name: .StoreProductsLoaded, object: nil)
            } else {
                refreshSnapshot()
            }
        } catch {
            print(error)
        }
    }

    internal func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            applyVerifiedMembershipTransaction(transaction)
            await transaction.finish()
            return .success(transaction)
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func updateCustomerProductStatus() async {
        await refreshCustomerProductStatus()
    }

    // MARK: - Cache hydration

    private func cachedMembershipValue() -> Bool {
        MoreKit.membershipDefaults?.bool(forKey: MoreKit.membershipKey) == true
    }

    /// Seed in-memory membership from the durable cache so ``hasValidMembership()`` is correct from the
    /// first frame, before StoreKit reports entitlements. Seeds `purchasedProductIDs` directly (not via
    /// ``applyMembership(_:)``): reflecting already-known cached membership is not a new acquisition, so it
    /// must not post `.LifetimeMembership` or re-write the cache.
    private func hydrateMembershipFromCacheIfNeeded() {
        guard purchasedProductIDs.isEmpty,
              cachedMembershipValue(),
              let registeredID = MoreKit.productID else { return }
        purchasedProductIDs.insert(registeredID)
    }

    // MARK: - Membership mutation

    /// The single place membership is written. Posts `.StoreInfoLoaded` only on an actual change, so the
    /// durable cache in ``User`` is not rewritten by redundant signals. (Launch hydration writes
    /// `purchasedProductIDs` directly, with `.LifetimeMembership` suppressed.)
    internal func applyMembership(_ isMember: Bool) {
        guard let registeredID = MoreKit.productID else { return }
        let ids: Set<String> = isMember ? [registeredID] : []
        if isMember {
            grantGeneration &+= 1   // record a positive-proof grant so a concurrent reconcile won't clear over it
        }
        let wasEmpty = purchasedProductIDs.isEmpty
        guard purchasedProductIDs != ids else {
            refreshSnapshot()
            return
        }
        purchasedProductIDs = ids   // didSet refreshes the snapshot
        // `.StoreInfoLoaded` first — that is what writes the durable cache in `User` — then
        // `.LifetimeMembership`, so an observer of "newly a member" sees both the live snapshot AND the
        // durable (app-group) cache already updated.
        NotificationCenter.default.post(name: .StoreInfoLoaded, object: nil)
        if wasEmpty, !ids.isEmpty {
            NotificationCenter.default.post(name: .LifetimeMembership, object: nil)
        }
    }

    /// Latch membership **on** from a verified, non-revoked transaction. Authoritative — no scan needed.
    private func applyVerifiedMembershipTransaction(_ transaction: Transaction) {
        guard let registeredID = MoreKit.productID,
              transaction.productID == registeredID,
              transaction.productType == .nonConsumable,
              transaction.revocationDate == nil else { return }
        applyMembership(true)
    }

    /// Handle a verified `Transaction.updates` delivery. Returns `true` if it was for the registered
    /// product (and therefore handled here and should be finished), `false` if it belongs to some other
    /// IAP the host app sells — those are left untouched for the host's own listener.
    private func applyVerifiedMembershipUpdate(_ transaction: Transaction) async -> Bool {
        guard let registeredID = MoreKit.productID,
              transaction.productID == registeredID,
              transaction.productType == .nonConsumable else { return false }

        if transaction.revocationDate != nil {
            // Revocation is best-effort: re-derive from StoreKit (so a newer repurchase keeps membership)
            // and clear only if the scan confirms `.revoked`. A transient `.missing` does not downgrade —
            // the refund is simply reflected at the next reconciliation instead.
            await refreshCustomerProductStatus()
        } else {
            // A verified non-revoked transaction is positive proof of ownership — grant immediately
            // (Ask-to-Buy approval, cross-device purchase, a pending purchase being approved).
            applyMembership(true)
        }
        return true
    }

    // MARK: - Entitlement reconciliation

    #if DEBUG
    /// Test seam: when set, replaces the real StoreKit scan, letting unit tests drive
    /// `refreshCustomerProductStatus` without a live StoreKit environment. Compiled out of release
    /// builds; never set in production.
    internal var scanOverrideForTesting: (@MainActor () async -> EntitlementScanOutcome)?
    #endif

    private func scanCurrentEntitlements() async -> EntitlementScanOutcome {
        #if DEBUG
        if let scanOverrideForTesting {
            return await scanOverrideForTesting()
        }
        #endif
        guard let registeredID = MoreKit.productID else { return .missing }
        var owned = false
        var sawRevocation = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                guard transaction.productType == .nonConsumable,
                      transaction.productID == registeredID else { continue }
                if transaction.revocationDate == nil {
                    owned = true
                } else {
                    sawRevocation = true
                }
            } catch {
                print(error)
            }
        }
        // A current non-revoked entitlement means the user owns the product — bias toward the paying user
        // and return `.owned`. (If `currentEntitlements` is briefly lagging a refund, that is reflected at
        // the next reconciliation — revocation is best-effort.) Only when `currentEntitlements` shows
        // nothing do we consult `Transaction.latest`, which surfaces a refund (`.revoked`) or a fresh
        // purchase not yet listed (`.owned`).
        if owned {
            return .owned
        }
        if sawRevocation {
            return .revoked
        }
        return await scanLatestMembershipTransaction() ?? .missing
    }

    private func scanLatestMembershipTransaction() async -> EntitlementScanOutcome? {
        guard let registeredID = MoreKit.productID,
              let result = await Transaction.latest(for: registeredID) else { return nil }
        do {
            let transaction = try Self.checkVerified(result)
            guard transaction.productType == .nonConsumable,
                  transaction.productID == registeredID else { return nil }
            return transaction.revocationDate == nil ? .owned : .revoked
        } catch {
            print(error)
            return nil
        }
    }

    /// Reconcile membership from a StoreKit scan, retrying briefly while `.missing` to let a slow-to-
    /// propagate entitlement surface (e.g. right after a restore). It never downgrades on `.missing`.
    @discardableResult
    private func refreshCustomerProductStatus(retryMissingAttempts: Int = 0) async -> EntitlementScanOutcome {
        let grantAtStart = grantGeneration
        var outcome = await scanCurrentEntitlements()
        var remainingAttempts = retryMissingAttempts

        while case .missing = outcome, remainingAttempts > 0, !Task.isCancelled {
            remainingAttempts -= 1
            try? await Task.sleep(nanoseconds: Self.syncMissingEntitlementRetryDelayNanoseconds)
            outcome = await scanCurrentEntitlements()
        }

        // A purchase always wins: if a grant landed while we were scanning, this scan's view is stale,
        // so never clear membership over it. (The refund, if any, is reflected at the next reconciliation.)
        if case .revoked = outcome, grantGeneration != grantAtStart {
            return outcome
        }
        applyReconciledOutcome(outcome)
        return outcome
    }

    /// Apply a reconciliation outcome: `.owned` grants, `.revoked` clears, `.missing` is a no-op (a
    /// lifetime entitlement is never given up just because a scan could not find it).
    internal func applyReconciledOutcome(_ outcome: EntitlementScanOutcome) {
        switch outcome {
        case .owned:
            applyMembership(true)
        case .revoked:
            applyMembership(false)
        case .missing:
            refreshSnapshot()
        }
    }
}

extension Store {
    public func purchaseLifetimeMembership() async throws -> PurchaseOutcome {
        guard purchasedProductIDs.isEmpty else {
            return .alreadyOwned
        }
        guard let membership = memberships.first else {
            throw StoreError.productsUnavailable
        }
        return try await purchase(membership)
    }

    public nonisolated func hasValidMembership() -> Bool {
        return snapshot.hasValidMembershipValue()
    }

    public nonisolated func proTier() -> ProTier {
        return snapshot.proTierValue()
    }

    public func sync() async throws {
        _ = try await syncMembershipStatus()
    }

    func syncMembershipStatus() async throws -> Bool {
        var syncError: Error?
        do {
            try await AppStore.sync()
        } catch {
            syncError = error
        }
        // Retry to find the entitlement only when the refresh itself succeeded; either way a transient
        // miss never downgrades an existing member.
        await refreshCustomerProductStatus(
            retryMissingAttempts: syncError == nil ? Self.syncMissingEntitlementRetryCount : 0
        )
        // If the refresh established membership (e.g. found the purchase locally), report success even
        // when the server sync failed; only surface the sync error if we still cannot confirm membership.
        if let syncError, !hasValidMembership() {
            throw syncError
        }
        return hasValidMembership()
    }

    public nonisolated func membershipDisplayPrice() -> String? {
        return snapshot.membershipDisplayPriceValue()
    }
}

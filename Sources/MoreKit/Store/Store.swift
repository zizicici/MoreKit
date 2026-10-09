//
//  Store.swift
//  MoreKit
//

import Combine
import Foundation
import StoreKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Notification.Name {
    public static let MembershipActivated = Notification.Name(rawValue: "com.zizicici.morekit.store.membership.activated")
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
            return String(localized: "store.error.failedVerification", defaultValue: "Transaction verification failed.", bundle: .module)
        case .productsUnavailable:
            return String(localized: "store.error.productsUnavailable", defaultValue: "Products are not available. Please try again.", bundle: .module)
        }
    }
}

public enum ProTier: Sendable {
    case subscription
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
    private var lifetime = false
    private var subscriptions: [SubscriptionMembership] = []
    private var membershipDisplayPrice: String?

    func update(lifetime: Bool, subscriptions: [SubscriptionMembership], membershipDisplayPrice: String?) {
        lock.lock()
        self.lifetime = lifetime
        self.subscriptions = subscriptions
        self.membershipDisplayPrice = membershipDisplayPrice
        lock.unlock()
    }

    func proTierValue() -> ProTier {
        lock.lock()
        defer { lock.unlock() }
        if lifetime { return .lifetime }
        return subscriptions.contains { $0.isActive() } ? .subscription : .none
    }

    func subscriptionValues() -> [SubscriptionMembership] {
        lock.lock()
        defer { lock.unlock() }
        return subscriptions
    }

    func membershipDisplayPriceValue() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return membershipDisplayPrice
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
    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var productsError: Error?
    private var subscriptions: [String: SubscriptionMembership] = [:]
    private var subscriptionGeneration = 0
    private var subscriptionRefreshTask: Task<Void, Never>?
    private var subscriptionRefreshRequested = false
    private var expirationTask: Task<Void, Never>?
    private var activationObserver: NSObjectProtocol?


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
            lifetime: MoreKit.productID.map { purchasedProductIDs.contains($0) } ?? false,
            subscriptions: Array(subscriptions.values),
            membershipDisplayPrice: memberships.first { $0.id == MoreKit.productID }?.displayPrice
        )
    }

    internal func start() {
        guard updateListenerTask == nil else { return }
        hydrateMembershipFromCacheIfNeeded()
        refreshSnapshot()
        updateListenerTask = listenForTransactions()
        Task { await updateCustomerProductStatus() }
        Task { await requestProducts() }
        #if canImport(UIKit)
        let activation = UIApplication.didBecomeActiveNotification
        #elseif canImport(AppKit)
        let activation = NSApplication.didBecomeActiveNotification
        #endif
        #if canImport(UIKit) || canImport(AppKit)
        activationObserver = NotificationCenter.default.addObserver(forName: activation, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in await self?.updateCustomerProductStatus() }
        }
        #endif
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

    public func requestProducts() async {
        guard !isLoadingProducts, !MoreKit.membershipProductIDs.isEmpty else { return }
        isLoadingProducts = true
        productsError = nil
        NotificationCenter.default.post(name: .StoreProductsLoaded, object: nil)
        do {
            let products = try await Product.products(for: MoreKit.membershipProductIDs)
            memberships = MoreKit.membershipProductIDs.compactMap { id in
                products.first { $0.id == id && isRegisteredProduct(id: id, type: $0.type) }
            }
            if memberships.count != MoreKit.membershipProductIDs.count {
                productsError = StoreError.productsUnavailable
            }
        } catch {
            productsError = error
        }
        isLoadingProducts = false
        refreshSnapshot()
        NotificationCenter.default.post(name: .StoreProductsLoaded, object: nil)
        // Product metadata gives access to renewal status, including billing grace periods.
        await refreshSubscriptions()
    }

    private func isRegisteredProduct(id: String, type: Product.ProductType) -> Bool {
        (id == MoreKit.productID && type == .nonConsumable)
            || (MoreKit.subscriptionProductIDs.contains(id) && type == .autoRenewable)
    }

    /// Purchase a configured product. Lifetime ownership prevents another membership purchase;
    /// subscribers may still buy lifetime access. Plan changes are managed through the App Store.
    public func purchase(productID: String) async throws -> PurchaseOutcome {
        guard let product = memberships.first(where: { $0.id == productID }) else {
            throw StoreError.productsUnavailable
        }
        if proTier() == .lifetime || activeSubscriptions().contains(where: { $0.productID == productID }) {
            return .alreadyOwned
        }
        return try await purchase(product)
    }

    internal func purchase(_ product: Product) async throws -> PurchaseOutcome {
        guard isRegisteredProduct(id: product.id, type: product.type) else { throw StoreError.productsUnavailable }
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            if transaction.productType == .autoRenewable {
                applySubscriptionTransaction(transaction)
                await refreshSubscriptions()
            } else {
                applyVerifiedMembershipTransaction(transaction)
            }
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
        await refreshSubscriptions()
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
        if purchasedProductIDs.isEmpty, cachedMembershipValue(), let registeredID = MoreKit.productID {
            purchasedProductIDs.insert(registeredID)
        }
        if let defaults = MoreKit.membershipDefaults {
            for membership in MembershipCache(defaults: defaults, key: MoreKit.membershipKey).subscriptions
                where MoreKit.subscriptionProductIDs.contains(membership.productID) && membership.isActive() {
                subscriptions[membership.productID] = membership
                purchasedProductIDs.insert(membership.productID)
            }
        }
        refreshSnapshot()
        scheduleSubscriptionExpiration()
    }

    // MARK: - Membership mutation

    /// The single place membership is written. Posts `.StoreInfoLoaded` only on an actual change, so the
    /// durable cache in ``User`` is not rewritten by redundant signals. (Launch hydration writes
    /// `purchasedProductIDs` directly, with `.LifetimeMembership` suppressed.)
    internal func applyMembership(_ isMember: Bool) {
        guard let registeredID = MoreKit.productID else { return }
        var ids = purchasedProductIDs
        if isMember { ids.insert(registeredID) } else { ids.remove(registeredID) }
        if isMember {
            grantGeneration &+= 1   // record a positive-proof grant so a concurrent reconcile won't clear over it
        }
        let hadLifetime = purchasedProductIDs.contains(registeredID)
        let wasMember = hasValidMembership()
        guard purchasedProductIDs != ids else {
            refreshSnapshot()
            return
        }
        purchasedProductIDs = ids   // didSet refreshes the snapshot
        // `.StoreInfoLoaded` first — that is what writes the durable cache in `User` — then
        // `.LifetimeMembership`, so an observer of "newly a member" sees both the live snapshot AND the
        // durable (app-group) cache already updated.
        NotificationCenter.default.post(name: .StoreInfoLoaded, object: nil)
        if !hadLifetime, isMember {
            NotificationCenter.default.post(name: .LifetimeMembership, object: nil)
        }
        if !wasMember, hasValidMembership() {
            NotificationCenter.default.post(name: .MembershipActivated, object: nil)
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
        if MoreKit.subscriptionProductIDs.contains(transaction.productID), transaction.productType == .autoRenewable {
            if transaction.revocationDate == nil, !transaction.isUpgraded {
                applySubscriptionTransaction(transaction)
            }
            await refreshSubscriptions()
            return true
        }
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
    private var subscriptionScanOverride: (@MainActor () async -> [String: SubscriptionScanOutcome])?
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
        if proTier() == .lifetime { return .alreadyOwned }
        guard let productID = MoreKit.productID else { throw StoreError.productsUnavailable }
        return try await purchase(productID: productID)
    }

    public nonisolated func hasValidMembership() -> Bool {
        return snapshot.proTierValue() != .none
    }

    public nonisolated func proTier() -> ProTier {
        return snapshot.proTierValue()
    }

    public func sync() async throws {
        _ = try await syncMembershipStatus()
    }

    public func syncMembershipStatus() async throws -> Bool {
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
        await refreshSubscriptions()
        // If the refresh established membership (e.g. found the purchase locally), report success even
        // when the server sync failed; only surface the sync error if we still cannot confirm membership.
        if let syncError, !hasValidMembership() {
            throw syncError
        }
        return hasValidMembership()
    }

    public nonisolated func activeSubscriptions() -> [SubscriptionMembership] {
        snapshot.subscriptionValues().filter { $0.isActive() }.sorted { $0.productID < $1.productID }
    }

    public nonisolated func membershipDisplayPrice() -> String? {
        return snapshot.membershipDisplayPriceValue()
    }
}

extension Store {
    private func applySubscriptionTransaction(_ transaction: Transaction) {
        guard MoreKit.subscriptionProductIDs.contains(transaction.productID),
              transaction.productType == .autoRenewable,
              transaction.revocationDate == nil, !transaction.isUpgraded,
              let expiration = transaction.expirationDate, expiration > Date() else { return }
        // A delayed update for an older period must not shorten a newer entitlement or grace period.
        if let current = subscriptions[transaction.productID], current.accessExpirationDate >= expiration { return }
        applySubscriptionOutcomes([transaction.productID: .active(.init(
            productID: transaction.productID, expirationDate: expiration
        ))])
    }

    #if DEBUG
    internal var subscriptionScanOverrideForTesting: (@MainActor () async -> [String: SubscriptionScanOutcome])? {
        get { subscriptionScanOverride }
        set { subscriptionScanOverride = newValue }
    }
    #endif

    internal func refreshSubscriptions() async {
        guard !MoreKit.subscriptionProductIDs.isEmpty else { return }
        if let task = subscriptionRefreshTask {
            subscriptionRefreshRequested = true
            await task.value
            return
        }
        // Serialize scans so each can use the previous scan's verified grace period.
        // Coalesce overlapping requests into a follow-up scan; every caller waits
        // for that scan too, including Restore callers that then report membership.
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            repeat {
                self.subscriptionRefreshRequested = false
                await self.scanAndApplySubscriptions()
            } while self.subscriptionRefreshRequested
            self.subscriptionRefreshTask = nil
        }
        subscriptionRefreshTask = task
        await task.value
    }

    private func scanAndApplySubscriptions() async {
        let generation = subscriptionGeneration
        var outcomes: [String: SubscriptionScanOutcome] = [:]
        #if DEBUG
        if let subscriptionScanOverrideForTesting {
            outcomes = await subscriptionScanOverrideForTesting()
        } else {
            for id in MoreKit.subscriptionProductIDs { outcomes[id] = await scanSubscription(productID: id) }
        }
        #else
        for id in MoreKit.subscriptionProductIDs { outcomes[id] = await scanSubscription(productID: id) }
        #endif
        // A direct purchase/update still takes precedence over a pre-purchase scan.
        guard generation == subscriptionGeneration else { return }
        applySubscriptionOutcomes(outcomes)
    }

    private func scanSubscription(productID: String) async -> SubscriptionScanOutcome {
        var fallback: SubscriptionScanOutcome = .missing
        var groupID = memberships.first(where: { $0.id == productID })?.subscription?.subscriptionGroupID
        if let result = await Transaction.latest(for: productID),
           let transaction = try? Self.checkVerified(result), transaction.productType == .autoRenewable {
            groupID = transaction.subscriptionGroupID ?? groupID
            if transaction.revocationDate != nil || transaction.isUpgraded {
                fallback = .inactive
            } else if let expiration = transaction.expirationDate, expiration > Date() {
                // Reuse the cached entry for the same period so an offline scan keeps its renewal info
                // instead of replacing it with a bare transaction and churning the cache.
                if let cached = subscriptions[productID], cached.expirationDate == expiration {
                    fallback = .active(cached)
                } else {
                    fallback = .active(.init(productID: productID, expirationDate: expiration))
                }
            } else if transaction.expirationDate != nil {
                let cachedGrace = subscriptions[productID]?.gracePeriodExpirationDate
                fallback = cachedGrace.map { $0 > Date() } == true ? .missing : .inactive
            }
            // An expired transaction alone does not disprove a previously verified billing grace
            // period. With no renewal status, retain cached access only up to its signed deadline.
        }
        // Transaction metadata is available on a cold/offline launch even when
        // Product.products has not loaded. Grace is carried by the group status.
        guard let groupID,
              let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else { return fallback }
        var best: SubscriptionMembership?
        var observedInactive = false
        for status in statuses {
            guard let transaction = try? Self.checkVerified(status.transaction),
                  transaction.productID == productID,
                  let renewal = try? Self.checkVerified(status.renewalInfo) else { continue }
            guard transaction.revocationDate == nil, !transaction.isUpgraded,
                  let expiration = transaction.expirationDate else {
                observedInactive = true
                continue
            }
            let grace = status.state == .inGracePeriod ? renewal.gracePeriodExpirationDate : nil
            let value = SubscriptionMembership(productID: productID, expirationDate: expiration,
                                               gracePeriodExpirationDate: grace, willAutoRenew: renewal.willAutoRenew)
            if (status.state == .subscribed || status.state == .inGracePeriod), value.isActive() {
                if best == nil || value.accessExpirationDate > best!.accessExpirationDate { best = value }
            } else {
                observedInactive = true
            }
        }
        return Self.resolveSubscriptionScan(transaction: fallback, statusBest: best, statusObservedInactive: observedInactive)
    }

    /// Combine the signed-transaction verdict with the group-status observations. A verified, unexpired,
    /// non-revoked transaction is positive proof of access; group status may extend it (grace period,
    /// renewal info) but a stale `.expired`/`.revoked` status for an older period must never contradict it.
    internal static func resolveSubscriptionScan(transaction: SubscriptionScanOutcome,
                                                 statusBest: SubscriptionMembership?,
                                                 statusObservedInactive: Bool) -> SubscriptionScanOutcome {
        if let statusBest { return .active(statusBest) }
        if case .active = transaction { return transaction }
        return statusObservedInactive ? .inactive : transaction
    }

    internal func applySubscriptionOutcomes(_ outcomes: [String: SubscriptionScanOutcome], now: Date = Date()) {
        let previous = subscriptions
        let wasMember = hasValidMembership()
        subscriptionGeneration &+= 1
        for (id, outcome) in outcomes where MoreKit.subscriptionProductIDs.contains(id) {
            switch outcome {
            case .active(let membership): subscriptions[id] = membership
            case .inactive: subscriptions.removeValue(forKey: id)
            case .missing: break
            }
        }
        subscriptions = subscriptions.filter { $0.value.isActive(at: now) }
        var ids = purchasedProductIDs.subtracting(MoreKit.subscriptionProductIDs)
        ids.formUnion(subscriptions.keys)
        purchasedProductIDs = ids
        scheduleSubscriptionExpiration()
        if subscriptions != previous {
            NotificationCenter.default.post(name: .StoreInfoLoaded, object: nil)
            if !wasMember, hasValidMembership() {
                NotificationCenter.default.post(name: .MembershipActivated, object: nil)
            }
        }
    }

    private func scheduleSubscriptionExpiration() {
        expirationTask?.cancel()
        guard let next = subscriptions.values.map(\.accessExpirationDate).min() else { return }
        // Recheck long subscriptions daily, as well as on app activation and transaction updates.
        let delay = min(max(next.timeIntervalSinceNow, 0.05), 86_400)
        expirationTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            guard let self else { return }
            // Re-read StoreKit before pruning so a renewal that arrived while suspended extends access
            // in one step instead of briefly clearing the cache and re-activating.
            await self.refreshSubscriptions()
            self.applySubscriptionOutcomes([:])
        }
    }
}

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

@MainActor
public class Store: ObservableObject {
    public nonisolated static let shared = Store()

    @Published public private(set) var memberships: [Product] = []

    @Published public private(set) var purchasedProductIDs: Set<String> = [] {
        didSet {
            if oldValue.isEmpty && !purchasedProductIDs.isEmpty {
                NotificationCenter.default.post(name: .LifetimeMembership, object: nil)
            }
        }
    }

    public var purchasedMemberships: [Product] {
        memberships.filter { purchasedProductIDs.contains($0.id) }
    }

    private var updateListenerTask: Task<Void, Error>? = nil
    private nonisolated let snapshot = StoreStateSnapshot()

    nonisolated init() {}

    private func refreshSnapshot() {
        snapshot.update(
            hasValidMembership: !purchasedProductIDs.isEmpty,
            membershipDisplayPrice: memberships.first?.displayPrice
        )
    }

    internal func start() {
        guard updateListenerTask == nil else { return }
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
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
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

    internal func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    public func updateCustomerProductStatus() async {
        guard let registeredID = MoreKit.productID else { return }

        var entitledIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                guard transaction.productType == .nonConsumable else { continue }
                guard transaction.productID == registeredID else { continue }
                entitledIDs.insert(transaction.productID)
            } catch {
                print(error)
            }
        }
        if purchasedProductIDs != entitledIDs {
            purchasedProductIDs = entitledIDs
        }
        refreshSnapshot()

        NotificationCenter.default.post(name: .StoreInfoLoaded, object: nil)
    }
}

extension Store {
    public func purchaseLifetimeMembership() async throws -> Transaction? {
        guard purchasedProductIDs.isEmpty else {
            return nil
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
        var syncError: Error?
        do {
            try await AppStore.sync()
        } catch {
            syncError = error
        }
        await updateCustomerProductStatus()
        if let syncError {
            throw syncError
        }
    }

    public nonisolated func membershipDisplayPrice() -> String? {
        return snapshot.membershipDisplayPriceValue()
    }
}

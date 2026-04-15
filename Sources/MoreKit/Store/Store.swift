//
//  Store.swift
//  MoreKit
//

import Foundation
import StoreKit

extension Notification.Name {
    public static let LifetimeMembership = Notification.Name(rawValue: "com.zizicici.morekit.store.purchase.lifetime")
    public static let StoreInfoLoaded = Notification.Name(rawValue: "com.zizicici.morekit.store.info.loaded")
}

public enum StoreError: Error {
    case failedVerification
}

public enum ProTier {
    case lifetime
    case none
}

public class Store: ObservableObject {
    public static let shared = Store()

    @Published public private(set) var memberships: [Product]

    @Published public private(set) var purchasedMemberships: [Product] = [] {
        didSet {
            if purchasedMemberships.count > 0 {
                NotificationCenter.default.post(name: Notification.Name.LifetimeMembership, object: nil)
            }
        }
    }

    private var updateListenerTask: Task<Void, Error>? = nil
    public private(set) var needRetry = false

    init() {
        memberships = []
    }

    /// Called internally after MoreKit.configure() sets up productIDs
    internal func start() {
        guard updateListenerTask == nil else { return }
        updateListenerTask = listenForTransactions()
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    public func retryRequestProducts() {
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    @MainActor
    func requestProducts() async {
        let productIDs = MoreKit.productIDs
        guard !productIDs.isEmpty else { return }

        do {
            let products = try await Product.products(for: productIDs)

            for product in products {
                switch product.type {
                case .nonConsumable:
                    memberships.append(product)
                default:
                    break
                }
            }

            if memberships.count == 0 {
                needRetry = true
            }
        }
        catch {
            if let error = error as? StoreKit.StoreKitError {
                switch error {
                case .networkError:
                    needRetry = true
                default:
                    break
                }
            }
            print(error)
        }
    }

    public func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }

    @MainActor
    public func updateCustomerProductStatus() async {
        var purchasedMemberships: [Product] = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                switch transaction.productType {
                case .nonConsumable:
                    if let membership = memberships.first(where: { $0.id == transaction.productID }) {
                        purchasedMemberships.append(membership)
                    }
                    break
                default:
                    break
                }
            }
            catch {
                print(error)
            }
        }
        self.purchasedMemberships = purchasedMemberships

        NotificationCenter.default.post(name: NSNotification.Name.StoreInfoLoaded, object: nil)
    }
}

extension Store {
    public func purchaseLifetimeMembership() async throws -> Transaction? {
        guard purchasedMemberships.count == 0 else {
            return nil
        }
        if let membership = memberships.first {
            return try await purchase(membership)
        } else {
            return nil
        }
    }

    public func hasValidMembership() -> Bool {
        return !purchasedMemberships.isEmpty
    }

    public func proTier() -> ProTier {
        if hasValidMembership() {
            return .lifetime
        } else {
            return .none
        }
    }

    public func sync() async {
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }

    public func membershipDisplayPrice() -> String? {
        return memberships.first?.displayPrice
    }
}

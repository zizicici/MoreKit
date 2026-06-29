//
//  User.swift
//  MoreKit
//

import Foundation

public class User {
    public static let shared = User()

    /// Returns the UserDefaults instance used for caching membership state.
    /// - If `appGroupID` was configured, returns the app-group suite. MoreKit.configure crashes if the
    ///   suite could not be opened, so we do not silently fall back to `.standard` here.
    /// - If `appGroupID` was not configured, returns `.standard` as the intended local store.
    private var membershipUserDefaults: UserDefaults? {
        MoreKit.membershipDefaults
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(syncMembershipCache), name: .StoreInfoLoaded, object: nil)
    }

    @objc
    private func syncMembershipCache() {
        // Only the main app writes the shared cache. Read-only consumers (app extensions) may see
        // empty entitlement results for reasons unrelated to the user's actual membership (timing,
        // cold start), so they must never clobber the value written by the main app.
        guard MoreKit.ownsStoreKit else { return }
        guard let defaults = membershipUserDefaults else { return }
        let current = Store.shared.hasValidMembership()
        if defaults.bool(forKey: MoreKit.membershipKey) != current {
            defaults.setValue(current, forKey: MoreKit.membershipKey)
        }
    }

    public func proTier() -> ProTier {
        // In the main app, Store is the live source of truth (hydrated from the cache at launch, then
        // kept current by StoreKit), so trust it directly and avoid depending on cache-write ordering.
        // Guard on a registered product: with no product, Store can't reflect membership, so fall through
        // to the cache for parity. Read-only consumers (extensions) don't run StoreKit, so they too read
        // the cached value the main app wrote.
        if MoreKit.ownsStoreKit, MoreKit.productID != nil {
            return Store.shared.proTier()
        }
        if membershipUserDefaults?.bool(forKey: MoreKit.membershipKey) == true {
            return .lifetime
        }
        return Store.shared.proTier()
    }
}

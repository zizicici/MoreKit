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
        if MoreKit.appGroupID != nil {
            return MoreKit.appGroupUserDefaults
        }
        return .standard
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
        if membershipUserDefaults?.bool(forKey: MoreKit.membershipKey) == true {
            return .lifetime
        }
        return Store.shared.proTier()
    }
}

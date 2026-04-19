//
//  User.swift
//  MoreKit
//

import Foundation

public class User {
    public static let shared = User()

    /// Returns the UserDefaults instance used for caching membership state.
    /// - If `appGroupID` was configured, returns the app-group suite — or nil if opening it failed,
    ///   so we do not silently fall back to `.standard` and pollute it with shared-cache keys.
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

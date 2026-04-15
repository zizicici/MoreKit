//
//  User.swift
//  MoreKit
//

import Foundation

public class User {
    public static let shared = User()

    private var membershipUserDefaults: UserDefaults {
        MoreKit.appGroupUserDefaults ?? .standard
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(lifetimeMembershipDidRegisted), name: Notification.Name.LifetimeMembership, object: nil)
    }

    @objc
    private func lifetimeMembershipDidRegisted() {
        membershipUserDefaults.setValue(true, forKey: MoreKit.membershipKey)
        membershipUserDefaults.synchronize()
    }

    public func proTier() -> ProTier {
        let cached = membershipUserDefaults.bool(forKey: MoreKit.membershipKey)
        if cached {
            return .lifetime
        }
        return Store.shared.proTier()
    }
}

//
//  MoreKit.swift
//  MoreKit
//

import Foundation

public enum MoreKit {
    internal static var productID: String?
    internal static var appGroupID: String?
    internal static var membershipKey: String = "com.zizicici.morekit.Store.LifetimeMembership"
    private static var isConfigured = false

    /// App Group UserDefaults, derived from appGroupID
    public private(set) static var appGroupUserDefaults: UserDefaults?

    /// Configure MoreKit. Must be called exactly once per process, on the main thread, before accessing any MoreKit types.
    @MainActor
    public static func configure(
        productID: String? = nil,
        appGroupID: String? = nil,
        membershipKey: String? = nil
    ) {
        assert(!isConfigured, "MoreKit.configure() must only be called once per process.")
        isConfigured = true

        self.productID = productID
        self.appGroupID = appGroupID
        if let membershipKey {
            self.membershipKey = membershipKey
        }

        if let appGroupID {
            let defaults = UserDefaults(suiteName: appGroupID)
            if defaults == nil {
                print("MoreKit: UserDefaults(suiteName: \"\(appGroupID)\") returned nil — shared membership cache will fall back to standard defaults. Check the app group entitlement.")
                assertionFailure("MoreKit: app group '\(appGroupID)' is not accessible — check the entitlement.")
            }
            self.appGroupUserDefaults = defaults
        }

        // Ensure User's StoreInfoLoaded observer registers before Store.start() broadcasts.
        _ = User.shared
        Store.shared.start()
    }
}

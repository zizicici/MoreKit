//
//  MoreKit.swift
//  MoreKit
//

import Foundation

public enum MoreKit {
    internal static var productIDs: [String] = []
    internal static var appGroupID: String?
    internal static var membershipKey: String = "com.zizicici.morekit.Store.LifetimeMembership"
    private static var isConfigured = false

    /// App Group UserDefaults, derived from appGroupID
    public private(set) static var appGroupUserDefaults: UserDefaults?

    /// Configure MoreKit. Must be called exactly once per process, before accessing any MoreKit types.
    public static func configure(
        productIDs: [String],
        appGroupID: String,
        membershipKey: String
    ) {
        assert(!isConfigured, "MoreKit.configure() must only be called once per process.")
        isConfigured = true

        self.productIDs = productIDs
        self.appGroupID = appGroupID
        self.membershipKey = membershipKey
        self.appGroupUserDefaults = UserDefaults(suiteName: appGroupID)

        Store.shared.start()
    }
}

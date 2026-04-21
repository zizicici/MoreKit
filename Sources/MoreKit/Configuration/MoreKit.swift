//
//  MoreKit.swift
//  MoreKit
//

import Foundation

public enum MoreKit {
    internal static var productID: String?
    internal static var appGroupID: String?
    internal static var membershipKey: String = "com.zizicici.morekit.Store.LifetimeMembership"
    internal private(set) static var ownsStoreKit: Bool = false
    private static var isConfigured = false

    /// App Group UserDefaults, derived from appGroupID
    public private(set) static var appGroupUserDefaults: UserDefaults?

    /// Configure MoreKit in the main app. Must be called exactly once per process, on the main thread,
    /// before accessing any MoreKit types. Starts StoreKit and writes the shared membership cache.
    ///
    /// Unavailable in app extensions — extensions must use `configureForReadOnlyAccess(...)` instead.
    @MainActor
    @available(iOSApplicationExtension, unavailable, message: "App extensions must use MoreKit.configureForReadOnlyAccess(appGroupID:membershipKey:) — extensions cannot run StoreKit.")
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
            openAppGroup(appGroupID)
        }

        ownsStoreKit = true
        // Ensure User's StoreInfoLoaded observer registers before Store.start() broadcasts.
        _ = User.shared
        Store.shared.start()
    }

    /// Configure MoreKit for a read-only consumer — e.g. a widget or other app extension that only needs
    /// to read the membership state written by the main app. Does not start StoreKit and never writes
    /// the shared cache. `appGroupID` is required; if the main app customizes `membershipKey`, pass the
    /// matching value here.
    @MainActor
    public static func configureForReadOnlyAccess(
        appGroupID: String,
        membershipKey: String? = nil
    ) {
        assert(!isConfigured, "MoreKit.configure() must only be called once per process.")
        isConfigured = true

        self.appGroupID = appGroupID
        if let membershipKey {
            self.membershipKey = membershipKey
        }

        openAppGroup(appGroupID)
    }

    private static func openAppGroup(_ appGroupID: String) {
        // Hard-fail (Debug and Release). A nil suite means the app group entitlement is missing or the
        // suite name is wrong — both are setup errors that, if ignored, let the shared cache quietly
        // fall back to the process's own UserDefaults and mark purchased users as free in production.
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            preconditionFailure("MoreKit: UserDefaults(suiteName: \"\(appGroupID)\") returned nil — check the app group entitlement and suite name.")
        }
        self.appGroupUserDefaults = defaults
    }
}

import Foundation
import Testing
@testable import MoreKit
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

@Suite("Cross-platform app information")
struct AppInfoCoreTests {
    @Test("Every app exposes metadata and a packaged image")
    func appMetadataAndImages() {
        #expect(AppInfo.App.allCases.count == 12)
        #expect(AppInfo.App.lemon.name == "A Lemon Diary")
        #expect(AppInfo.App.lemon.subtitle == "A pure text diary")
        for app in AppInfo.App.allCases {
            #expect(!app.name.isEmpty)
            #expect(!app.subtitle.isEmpty)
            #expect(!app.storeId.isEmpty)
            #expect(app.storeURL.absoluteString.hasSuffix(app.storeId))
            #expect(app.image != nil)
        }
    }

    @Test("Showcase resolution remains platform independent")
    func showcaseResolution() {
        let configuration = AppShowcaseConfiguration(
            apps: [.lemon],
            displayCount: 5
        )

        #expect(configuration.resolvedApps(for: .en) == [.lemon])
        #expect(configuration.resolvedApps(for: .zh) == [.lemon, .festivals])
        #expect(configuration.showsDeveloperPageEntry)
    }
}

@Suite("Cross-platform specifications")
struct SpecificationsCoreTests {
    @Test("Configuration exposes localized labels and library URLs")
    func configurationData() {
        let configuration = SpecificationsConfiguration(
            summaryItems: [
                .init(type: .name, value: "Watermelon Backup")
            ],
            thirdPartyLibraries: [
                .init(
                    name: "MoreKit",
                    version: "2.0.1",
                    urlString: "https://github.com/zizicici/MoreKit"
                )
            ]
        )

        #expect(configuration.summaryItems[0].type.localizedLabel == "Name")
        #expect(configuration.thirdPartyLibraries[0].url?.host == "github.com")
        #expect(
            StoreError.productsUnavailable.errorDescription
                == "Products are not available. Please try again."
        )
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@Suite("Native AppKit components")
@MainActor
struct AppKitComponentTests {
    @Test("Showcase presents five icons and pauses for hover details")
    func showcaseInteraction() {
        let showcase = AppShowcaseView(
            apps: Array(AppInfo.App.allCases.prefix(6)),
            visibleIconCount: 5
        )

        #expect(showcase.apps.count == 6)
        #expect(showcase.visibleIconCount == 5)
        #expect(showcase.intrinsicContentSize.width > 0)
        #expect(!showcase.isScrollingPaused)

        showcase.setHoveredApp(.lemon)
        #expect(showcase.isScrollingPaused)
        #expect(showcase.displayedDescription == "A Lemon Diary · A pure text diary")

        showcase.setHoveredApp(nil)
        #expect(!showcase.isScrollingPaused)
        #expect(showcase.displayedDescription.isEmpty)
    }

    @Test("Specifications renders native summary and library grids")
    func specificationsPresentation() {
        let configuration = SpecificationsConfiguration(
            summaryItems: [
                .init(type: .name, value: "Watermelon Backup")
            ],
            thirdPartyLibraries: [
                .init(
                    name: "MoreKit",
                    version: "2.0.1",
                    urlString: "https://github.com/zizicici/MoreKit"
                )
            ]
        )
        let viewController = SpecificationsViewController(
            configuration: configuration
        )

        viewController.loadView()

        #expect(viewController.configuration == configuration)
        #expect(
            findView(
                identifier: "specifications.summaryGrid",
                in: viewController.view
            ) != nil
        )
        #expect(
            findView(
                identifier: "specifications.libraryGrid",
                in: viewController.view
            ) != nil
        )
    }

    private func findView(identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let match = findView(identifier: identifier, in: subview) {
                return match
            }
        }
        return nil
    }
}
#endif

@Suite("Cross-platform membership state", .serialized)
@MainActor
final class StoreCoreTests {
    private let originalProductID = MoreKit.productID
    private let originalSubscriptionIDs = MoreKit.subscriptionProductIDs

    init() {
        MoreKit.productID = "com.test.pro"
        MoreKit.subscriptionProductIDs = ["com.test.pro.monthly", "com.test.pro.yearly"]
    }

    deinit {
        MoreKit.productID = originalProductID
        MoreKit.subscriptionProductIDs = originalSubscriptionIDs
    }

    @Test("Missing entitlement never clears an owned membership")
    func missingEntitlementIsSticky() {
        let store = Store()
        store.applyReconciledOutcome(.owned)
        store.applyReconciledOutcome(.missing)

        #expect(store.hasValidMembership())
        #expect(store.proTier() == .lifetime)
    }

    @Test("Verified revocation clears an owned membership")
    func revocationClearsMembership() {
        let store = Store()
        store.applyReconciledOutcome(.owned)
        store.applyReconciledOutcome(.revoked)

        #expect(!store.hasValidMembership())
        #expect(store.proTier() == .none)
    }
    private func subscription(expires: Date = Date().addingTimeInterval(3600),
                              grace: Date? = nil, renews: Bool? = true) -> SubscriptionMembership {
        .init(productID: "com.test.pro.monthly", expirationDate: expires,
              gracePeriodExpirationDate: grace, willAutoRenew: renews)
    }

    @Test("Subscription access expires even when StoreKit is unavailable")
    func subscriptionsExpire() {
        let store = Store()
        let membership = subscription()
        store.applySubscriptionOutcomes([membership.productID: .active(membership)])
        #expect(store.proTier() == .subscription)
        store.applySubscriptionOutcomes([membership.productID: .missing])
        #expect(store.hasValidMembership())
        store.applySubscriptionOutcomes([membership.productID: .missing], now: membership.expirationDate)
        #expect(!store.hasValidMembership())
        #expect(store.purchasedProductIDs.isEmpty)
    }

    @Test("Canceling renewal retains access until expiration; grace has its own deadline")
    func renewalAndGrace() {
        let now = Date()
        let canceled = subscription(renews: false)
        #expect(canceled.isActive(at: now))
        let grace = subscription(expires: now.addingTimeInterval(-10), grace: now.addingTimeInterval(100))
        #expect(grace.isActive(at: now))
        #expect(!grace.isActive(at: now.addingTimeInterval(100)))
    }

    @Test("Lifetime and subscriptions do not overwrite each other")
    func mixedOwnership() {
        let store = Store()
        let membership = subscription()
        store.applySubscriptionOutcomes([membership.productID: .active(membership)])
        store.applyMembership(true)
        #expect(store.proTier() == .lifetime)
        #expect(store.purchasedProductIDs.count == 2)
        store.applyReconciledOutcome(.revoked)
        #expect(store.proTier() == .subscription)
        store.applyMembership(true)
        store.applySubscriptionOutcomes([membership.productID: .inactive])
        #expect(store.proTier() == .lifetime)
        #expect(store.purchasedProductIDs == ["com.test.pro"])
    }

    @Test("A refund clears only the affected subscription")
    func subscriptionRevocation() {
        let store = Store()
        let monthly = subscription()
        let yearly = SubscriptionMembership(productID: "com.test.pro.yearly", expirationDate: Date().addingTimeInterval(3600))
        store.applySubscriptionOutcomes([monthly.productID: .active(monthly), yearly.productID: .active(yearly)])
        store.applySubscriptionOutcomes([monthly.productID: .inactive])
        #expect(store.hasValidMembership())
        #expect(store.activeSubscriptions().map(\.productID) == [yearly.productID])
        store.applySubscriptionOutcomes([yearly.productID: .inactive])
        #expect(store.proTier() == .none)
    }

    @Test("A purchase during a stale subscription scan wins")
    func concurrentSubscriptionGrant() async {
        let store = Store()
        let membership = subscription()
        store.subscriptionScanOverrideForTesting = {
            store.applySubscriptionOutcomes([membership.productID: .active(membership)])
            return [membership.productID: .inactive]
        }
        await store.refreshSubscriptions()
        #expect(store.proTier() == .subscription)
    }

    @Test("Unregistered products cannot unlock membership")
    func unrelatedProducts() {
        let store = Store()
        let other = SubscriptionMembership(productID: "other", expirationDate: Date().addingTimeInterval(3600))
        store.applySubscriptionOutcomes([other.productID: .active(other)])
        #expect(!store.hasValidMembership())
    }

    @Test("Overlapping refreshes serialize scans, retain evidence, and wait for reconciliation")
    func concurrentSubscriptionScans() async {
        for activeAtStart in [false, true] {
            for authoritativeFirst in [false, true] {
                let store = Store()
                let membership = subscription()
                if activeAtStart { store.applySubscriptionOutcomes([membership.productID: .active(membership)]) }
                var pending: [CheckedContinuation<[String: SubscriptionScanOutcome], Never>] = []
                store.subscriptionScanOverrideForTesting = { await withCheckedContinuation { pending.append($0) } }
                var completed = 0
                var requested = 0
                let old = Task { await store.refreshSubscriptions(); completed += 1 }
                while pending.count < 1 { await Task.yield() }
                let new = Task { requested += 1; await store.refreshSubscriptions(); completed += 1 }
                let coalesced = Task { requested += 1; await store.refreshSubscriptions(); completed += 1 }
                while requested < 2 { await Task.yield() }
                #expect(pending.count == 1)
                let authoritative: SubscriptionScanOutcome = activeAtStart ? .inactive : .active(membership)
                pending[0].resume(returning: [membership.productID: authoritativeFirst ? authoritative : .missing])
                while pending.count < 2 { await Task.yield() }
                #expect(completed == 0)
                #expect(store.hasValidMembership() == (authoritativeFirst ? !activeAtStart : activeAtStart))
                pending[1].resume(returning: [membership.productID: authoritativeFirst ? .missing : authoritative])
                await old.value
                await new.value
                await coalesced.value
                #expect(completed == 3)
                #expect(pending.count == 2)
                #expect(store.hasValidMembership() == !activeAtStart)
            }
        }
    }

    @Test("Subscription cache never writes the lifetime Boolean and expires for extensions")
    func expiringCache() throws {
        let suite = "MoreKit.cache.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = MembershipCache(defaults: defaults, key: "membership")
        let membership = subscription()
        cache.write(lifetime: false, subscriptions: [membership])
        #expect(!defaults.bool(forKey: "membership"))
        #expect(cache.tier() == .subscription)
        #expect(cache.tier(at: membership.expirationDate) == .none)
        cache.write(lifetime: true, subscriptions: [membership])
        #expect(cache.tier(at: membership.expirationDate) == .lifetime)
        defaults.removeObject(forKey: "membership.subscriptions.v1")
        #expect(cache.tier() == .lifetime) // legacy installations have only the Boolean
    }

    @Test("Subscription activation does not emit a lifetime purchase notification")
    func subscriptionNotification() {
        let store = Store()
        var lifetimeEvents = 0
        var activatedEvents = 0
        let lifetime = NotificationCenter.default.addObserver(forName: .LifetimeMembership, object: nil, queue: nil) { _ in lifetimeEvents += 1 }
        let activated = NotificationCenter.default.addObserver(forName: .MembershipActivated, object: nil, queue: nil) { _ in activatedEvents += 1 }
        defer {
            NotificationCenter.default.removeObserver(lifetime)
            NotificationCenter.default.removeObserver(activated)
        }
        let membership = subscription()
        store.applySubscriptionOutcomes([membership.productID: .active(membership)])
        #expect(lifetimeEvents == 0)
        #expect(activatedEvents == 1)
    }

}

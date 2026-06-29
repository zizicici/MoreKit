import Testing
import UIKit
@testable import MoreKit

@Suite("MoreKit Configuration Tests")
struct MoreKitConfigTests {
    @Test("Configure sets productID and appGroupID")
    @MainActor
    func testConfigure() {
        MoreKit.configure(productID: "com.test.pro", appGroupID: "group.com.test")
        #expect(MoreKit.productID == "com.test.pro")
        #expect(MoreKit.appGroupID == "group.com.test")
    }
}

@Suite("MoreKitAppearance Tests")
struct MoreKitAppearanceTests {
    @Test("Default appearance uses system colors")
    func testDefaults() {
        let appearance = MoreKitAppearance()
        #expect(appearance.backgroundColor == .systemGroupedBackground)
        #expect(appearance.tintColor == .tintColor)
    }
}

@Suite("UIColor+Extension Tests")
struct UIColorExtensionTests {
    @Test("Hex 6-digit init")
    func testHex6() {
        let color = UIColor(hex: "FF0000")
        #expect(color != nil)
    }

    @Test("Hex 8-digit init")
    func testHex8() {
        let color = UIColor(hex: "FF0000FF")
        #expect(color != nil)
    }

    @Test("Hex with hash prefix")
    func testHexHash() {
        let color = UIColor(hex: "#00FF00")
        #expect(color != nil)
    }

    @Test("Invalid hex returns nil")
    func testInvalidHex() {
        let color = UIColor(hex: "ZZZ")
        #expect(color == nil)
    }

    @Test("toHexString round-trips")
    func testRoundTrip() {
        let color = UIColor(hex: "FF0000")
        let hex = color?.toHexString()
        #expect(hex != nil)
        #expect(hex?.hasPrefix("FF0000") == true)
    }

    @Test("Light/Dark string generation")
    func testLightDarkString() {
        let color = UIColor.red
        let result = color.generateLightDarkString()
        #expect(result.contains(","))
    }

    @Test("Init from light/dark string")
    func testInitFromString() {
        let color = UIColor(string: "FF0000FF,00FF00FF")
        #expect(color != nil)
    }

    @Test("isSimilar detects similar colors")
    func testSimilar() {
        let red1 = UIColor(hex: "FF0000")!
        let red2 = UIColor(hex: "FE0101")!
        #expect(red1.isSimilar(to: red2))
    }

    @Test("isSimilar rejects different colors")
    func testNotSimilar() {
        let red = UIColor(hex: "FF0000")!
        let blue = UIColor(hex: "0000FF")!
        #expect(!red.isSimilar(to: blue))
    }
}

@Suite("ConsideringUser Tests")
struct ConsideringUserTests {
    @Test("Properties return Bool")
    func testProperties() {
        _ = ConsideringUser.animated
        _ = ConsideringUser.pushAnimated
        _ = ConsideringUser.buttonShapesEnabled
    }
}

@Suite("SpecificationsConfiguration Tests")
struct SpecificationsConfigurationTests {
    @Test("SummaryItem creation")
    func testSummaryItem() {
        let item = SpecificationsConfiguration.SummaryItem(type: .name, value: "TestApp")
        #expect(item.value == "TestApp")
    }

    @Test("ThirdPartyLibrary creation")
    func testThirdParty() {
        let lib = SpecificationsConfiguration.ThirdPartyLibrary(name: "SnapKit", version: "5.7.1", urlString: "https://github.com/SnapKit/SnapKit")
        #expect(lib.name == "SnapKit")
        #expect(lib.version == "5.7.1")
    }

    @Test("Full configuration")
    func testConfiguration() {
        let config = SpecificationsConfiguration(
            summaryItems: [
                .init(type: .name, value: "App"),
                .init(type: .version, value: "1.0"),
            ],
            thirdPartyLibraries: [
                .init(name: "Lib", version: "1.0", urlString: "https://example.com"),
            ]
        )
        #expect(config.summaryItems.count == 2)
        #expect(config.thirdPartyLibraries.count == 1)
        #expect(config.title == nil)
    }
}

@Suite("AppShowcaseConfiguration Tests")
struct AppShowcaseConfigurationTests {
    @Test("Chinese locale injects festivals app once")
    func testResolvedAppsForChineseLocale() {
        let configuration = AppShowcaseConfiguration(apps: [.lemon, .festivals])
        let resolved = configuration.resolvedApps(for: .zh)

        #expect(resolved.filter { $0 == .festivals }.count == 1)
        #expect(resolved.contains(.lemon))
    }

    @Test("Non-Chinese locale does not inject festivals app")
    func testResolvedAppsForNonChineseLocale() {
        let configuration = AppShowcaseConfiguration(apps: [.lemon], automaticallyIncludesFestivalsForChineseLocales: true)
        let resolved = configuration.resolvedApps(for: .en)

        #expect(resolved == [.lemon])
    }

    @Test("Legacy showcase parameters bridge into appShowcase")
    func testLegacyConfigurationBridge() {
        let configuration = MoreViewControllerConfiguration(
            title: "More",
            promotionConfig: PromotionCellConfiguration(
                title: "Upgrade",
                features: ["Feature"]
            ),
            gratefulConfig: GratefulCellConfiguration(
                title: "Thanks",
                content: "Unlocked"
            ),
            email: "support@example.com",
            appStoreId: "123456789",
            specificationsConfig: SpecificationsConfiguration(
                summaryItems: [],
                thirdPartyLibraries: []
            ),
            otherApps: [.lemon],
            otherAppsDisplayCount: 2
        )

        #expect(configuration.appShowcase.apps == [.lemon])
        #expect(configuration.appShowcase.displayCount == 2)
    }
}

@Suite("MoreCustomItem Tests")
struct MoreCustomItemTests {
    @Test("Language settings item uses built-in identifier")
    func testLanguageSettingsItem() {
        let item = MoreCustomItem.languageSettings()

        #expect(item.id == MoreCustomItem.languageSettingsID)
        #expect(!item.title.isEmpty)
        #expect(item.value == Language.currentDisplayName(bundle: .module))
    }
}

@Suite("Settings Notification Tests")
struct SettingsNotificationTests {
    @Test("Settings update notification is delivered on main thread")
    func testSettingsUpdateNotificationIsDeliveredOnMainThread() async {
        ThreadedSetting.userDefaults.removeObject(forKey: ThreadedSetting.getKey())
        defer {
            ThreadedSetting.userDefaults.removeObject(forKey: ThreadedSetting.getKey())
        }

        let deliveredOnMainThread = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(forName: .SettingsUpdate, object: nil, queue: nil) { _ in
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: Thread.isMainThread)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                ThreadedSetting.setValue(.second)
            }
        }

        #expect(deliveredOnMainThread)
    }
}

private enum ThreadedSetting: Int, CaseIterable, UserDefaultSettable {
    case first
    case second

    func getName() -> String {
        String(rawValue)
    }

    static func getTitle() -> String {
        "Threaded Setting"
    }

    static func getOptions() -> [ThreadedSetting] {
        Array(allCases)
    }

    static func getKey() -> String {
        "MoreKitTests.ThreadedSetting"
    }

    static var defaultOption: ThreadedSetting {
        .first
    }
}

@Suite("MoreViewController Membership Tests")
struct MoreViewControllerMembershipTests {
    @Test("Membership configs default to nil")
    func testMembershipConfigsDefaultToNil() {
        let configuration = MoreViewControllerConfiguration(
            title: "More",
            email: "support@example.com",
            appStoreId: "123456789",
            specificationsConfig: SpecificationsConfiguration(
                summaryItems: [],
                thirdPartyLibraries: []
            )
        )

        #expect(configuration.promotionConfig == nil)
        #expect(configuration.gratefulConfig == nil)
    }

    @Test("Free users hide membership item without promotion config")
    @MainActor
    func testMembershipItemSkipsPromotionWhenConfigMissing() {
        let controller = MoreViewController(
            configuration: MoreViewControllerConfiguration(
                title: "More",
                gratefulConfig: GratefulCellConfiguration(
                    title: "Thanks",
                    content: "Unlocked"
                ),
                email: "support@example.com",
                appStoreId: "123456789",
                specificationsConfig: SpecificationsConfiguration(
                    summaryItems: [],
                    thirdPartyLibraries: []
                )
            )
        )

        let item = controller.membershipItem(
            productID: "com.test.pro",
            proTier: .none,
            membershipDisplayPrice: "$9.99"
        )

        #expect(item == nil)
    }

    @Test("Lifetime users hide membership item without grateful config")
    @MainActor
    func testMembershipItemSkipsThanksWhenConfigMissing() {
        let controller = MoreViewController(
            configuration: MoreViewControllerConfiguration(
                title: "More",
                promotionConfig: PromotionCellConfiguration(
                    title: "Upgrade",
                    features: ["Feature"]
                ),
                email: "support@example.com",
                appStoreId: "123456789",
                specificationsConfig: SpecificationsConfiguration(
                    summaryItems: [],
                    thirdPartyLibraries: []
                )
            )
        )

        let item = controller.membershipItem(
            productID: "com.test.pro",
            proTier: .lifetime,
            membershipDisplayPrice: "$9.99"
        )

        #expect(item == nil)
    }

    @Test("Membership item still renders when matching config exists")
    @MainActor
    func testMembershipItemUsesMatchingConfig() {
        let controller = MoreViewController(
            configuration: MoreViewControllerConfiguration(
                title: "More",
                promotionConfig: PromotionCellConfiguration(
                    title: "Upgrade",
                    features: ["Feature"]
                ),
                gratefulConfig: GratefulCellConfiguration(
                    title: "Thanks",
                    content: "Unlocked"
                ),
                email: "support@example.com",
                appStoreId: "123456789",
                specificationsConfig: SpecificationsConfiguration(
                    summaryItems: [],
                    thirdPartyLibraries: []
                )
            )
        )

        let promotionItem = controller.membershipItem(
            productID: "com.test.pro",
            proTier: .none,
            membershipDisplayPrice: "$9.99"
        )
        let gratefulItem = controller.membershipItem(
            productID: "com.test.pro",
            proTier: .lifetime,
            membershipDisplayPrice: "$9.99"
        )

        switch promotionItem {
        case .promotion(let price):
            #expect(price == "$9.99")
        default:
            Issue.record("Expected a promotion item when promotionConfig exists.")
        }

        #expect(gratefulItem == .thanks)
    }
}

@Suite("PromotionCellConfiguration Tests")
struct PromotionCellConfigurationTests {
    @Test("Default values")
    func testDefaults() {
        let config = PromotionCellConfiguration(
            title: "Upgrade",
            features: ["Feature 1", "Feature 2"]
        )
        #expect(config.title == "Upgrade")
        #expect(config.features.count == 2)
        #expect(config.gradientColors.count == 2)
        #expect(config.buttonTitle == String(localized: "store.purchase", bundle: .module))
        #expect(config.buttonIcon == "arrowshape.up.circle")
    }

    @Test("Custom purchase button title")
    func testCustomButtonTitle() {
        let config = PromotionCellConfiguration(
            title: "Upgrade",
            features: ["Feature 1", "Feature 2"],
            buttonTitle: "Buy Now"
        )

        #expect(config.buttonTitle == "Buy Now")
    }
}

@Suite("GratefulCellConfiguration Tests")
struct GratefulCellConfigurationTests {
    @Test("Default values")
    func testDefaults() {
        let config = GratefulCellConfiguration(
            title: "Thanks",
            content: "You are a Pro member"
        )
        #expect(config.title == "Thanks")
        #expect(config.content == "You are a Pro member")
        #expect(config.titleHighlightColor == .systemYellow)
    }
}

@Suite("Helper Tests")
struct HelperTests {
    @Test("getAppVersion returns value or nil")
    func testAppVersion() {
        // In test context, Bundle.main may not have the key
        _ = SpecificationsViewController.getAppVersion()
    }

    @Test("getAppName returns value or nil")
    func testAppName() {
        _ = SpecificationsViewController.getAppName()
    }
}

/// Locks in the membership latch: positive proof grants and is sticky, only an observed `.revoked`
/// reconciliation clears, and `.missing` never downgrades a member.
///
/// Coverage boundary: these drive the in-process apply logic via `applyMembership` /
/// `applyReconciledOutcome` and the `scanOverrideForTesting` seam (no live StoreKit). The thin verified-
/// transaction entry points (`purchase()`, `applyVerifiedMembershipUpdate`) are not driven end-to-end —
/// that would need a StoreKitTest configuration. The suite is `.serialized` because it sets the
/// process-global `MoreKit.productID` and posts on the default `NotificationCenter`.
@Suite("Store Membership Latch Tests", .serialized)
@MainActor
final class StoreMembershipLatchTests {
    private let originalProductID = MoreKit.productID

    init() {
        MoreKit.productID = "com.test.pro"
    }

    deinit {
        // Leave the process-global config as we found it, so this suite can't leak into other suites.
        MoreKit.productID = originalProductID
    }

    private func makeStore() -> Store {
        Store()
    }

    @Test("Positive proof grants membership")
    func grantSetsMember() {
        let store = makeStore()
        store.applyMembership(true)
        #expect(store.hasValidMembership())
    }

    @Test("A reconciliation that observes .revoked clears membership")
    func revokedReconcileClears() {
        let store = makeStore()
        store.applyReconciledOutcome(.owned)
        #expect(store.hasValidMembership())
        store.applyReconciledOutcome(.revoked)
        #expect(!store.hasValidMembership())
    }

    @Test(".missing never downgrades a member")
    func missingNeverDowngrades() {
        let store = makeStore()
        store.applyReconciledOutcome(.owned)
        #expect(store.hasValidMembership())
        store.applyReconciledOutcome(.missing)
        #expect(store.hasValidMembership())   // still a member
    }

    @Test("A real reconciliation does not downgrade a member when StoreKit reports nothing")
    func realReconcileMissingKeepsMember() async {
        let store = makeStore()
        store.applyMembership(true)
        #expect(store.hasValidMembership())
        defer { store.scanOverrideForTesting = nil }
        store.scanOverrideForTesting = { .missing }   // deterministic, independent of ambient StoreKit state
        await store.updateCustomerProductStatus()
        #expect(store.hasValidMembership())            // .missing must never downgrade
    }

    @Test("A purchase that lands during a reconcile scan is not clobbered by a stale .revoked")
    func grantDuringScanSurvivesStaleRevoked() async {
        let store = makeStore()   // non-member (e.g. a previously-refunded user)
        defer { store.scanOverrideForTesting = nil }
        // The scan reads the pre-purchase (revoked) state, but the user purchases mid-scan: the grant
        // lands, then the stale scan resolves .revoked. The purchase must win.
        store.scanOverrideForTesting = {
            store.applyMembership(true)   // a purchase grant lands during the scan
            return .revoked               // ...but the scan had already read the pre-purchase revoked state
        }
        await store.updateCustomerProductStatus()
        #expect(store.hasValidMembership())   // the purchase wins — membership is not cleared
    }

    @Test("hasValidMembership() is already true inside a .LifetimeMembership observer")
    func snapshotIsCurrentWhenLifetimeMembershipPosts() {
        let store = makeStore()
        var observedMember: Bool?
        let token = NotificationCenter.default.addObserver(forName: .LifetimeMembership, object: nil, queue: nil) { _ in
            observedMember = store.hasValidMembership()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        store.applyMembership(true)   // empty → member, posts .LifetimeMembership
        #expect(observedMember == true)
    }

    @Test(".StoreInfoLoaded (which writes the durable cache) is posted before .LifetimeMembership")
    func storeInfoLoadedPostedBeforeLifetimeMembership() {
        let store = makeStore()
        var order: [String] = []
        let infoToken = NotificationCenter.default.addObserver(forName: .StoreInfoLoaded, object: nil, queue: nil) { _ in order.append("info") }
        let lifetimeToken = NotificationCenter.default.addObserver(forName: .LifetimeMembership, object: nil, queue: nil) { _ in order.append("lifetime") }
        defer {
            NotificationCenter.default.removeObserver(infoToken)
            NotificationCenter.default.removeObserver(lifetimeToken)
        }
        store.applyMembership(true)   // empty → member
        #expect(order == ["info", "lifetime"])   // cache write must precede the membership-active event
    }
}

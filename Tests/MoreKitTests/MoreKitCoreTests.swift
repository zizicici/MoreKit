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

    init() {
        MoreKit.productID = "com.test.pro"
    }

    deinit {
        MoreKit.productID = originalProductID
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
}

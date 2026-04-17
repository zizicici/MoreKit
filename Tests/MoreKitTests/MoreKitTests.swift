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
        #expect(config.buttonIcon == "arrowshape.up.circle")
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

# MoreKit

A Swift package for building a fully-featured "More" tab in iOS apps, with built-in support for lifetime membership (StoreKit 2), contact section, app showcase, and specifications page.

## Requirements

- iOS 15.0+
- Swift 5.10+

## Installation

Add MoreKit to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/user/MoreKit.git", from: "1.6.3")
]
```

## Quick Start

### 1. Configure MoreKit

Call `configure()` once at app launch (e.g. in `AppDelegate`):

```swift
import MoreKit

MoreKit.configure(
    productID: "com.example.lifetime",  // optional
    appGroupID: "group.com.example.app",  // optional
    membershipKey: "com.example.Store.LifetimeMembership"  // optional
)
```

### 2. Create the MoreViewController

```swift
let config = MoreViewControllerConfiguration(
    title: "More",
    promotionConfig: PromotionCellConfiguration(
        title: "Unlock All Features",
        features: ["Feature A", "Feature B", "Feature C"],
        buttonTitle: "Go Pro"
    ),
    gratefulConfig: GratefulCellConfiguration(
        title: "Thank You!",
        content: "You've unlocked all features."
    ),
    email: "support@example.com",
    appStoreId: "123456789",
    specificationsConfig: SpecificationsConfiguration(
        summaryItems: [
            .init(type: .name, value: "MyApp"),
            .init(type: .version, value: SpecificationsViewController.getAppVersion() ?? "1.0"),
        ],
        thirdPartyLibraries: [
            .init(name: "SnapKit", version: "5.7.1", urlString: "https://github.com/SnapKit/SnapKit"),
        ]
    )
)

let moreVC = MoreViewController(configuration: config)
```

`PromotionCellConfiguration.buttonTitle` lets you override the purchase button text; if omitted, MoreKit keeps using the localized default purchase label.

## Configuration

### MoreViewControllerConfiguration

| Parameter | Type | Default | Description |
|---|---|---|---|
| `title` | `String` | Required | Tab bar and navigation title |
| `tabBarImage` | `UIImage?` | `ellipsis` | Tab bar icon |
| `promotionConfig` | `PromotionCellConfiguration` | Required | Promotion cell appearance |
| `gratefulConfig` | `GratefulCellConfiguration` | Required | Post-purchase cell appearance |
| `email` | `String` | Required | Contact email address |
| `showContactImages` | `Bool` | `true` | Show/hide contact item icons |
| `appStoreId` | `String` | Required | App Store ID for share/review |
| `privacyPolicyURL` | `String?` | `nil` | Privacy policy URL |
| `specificationsConfig` | `SpecificationsConfiguration` | Required | Specifications page content |
| `appShowcase` | `AppShowcaseConfiguration` | `AppShowcaseConfiguration()` | App showcase section configuration |

The EULA link uses the [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) by default and is always displayed. Share and Review entries are automatically shown only when the app is live on the App Store.

`AppShowcaseConfiguration` centralizes what used to be `otherApps` and `otherAppsDisplayCount`, and also lets you override or disable the developer-page entry:

```swift
appShowcase: AppShowcaseConfiguration(
    apps: [.lemon, .coconut, .tagDay],
    displayCount: 2,
    developerPageURL: AppInfo.Developer.pageURL
)
```

### Appearance

```swift
MoreKitAppearance.shared = MoreKitAppearance(
    backgroundColor: .systemGroupedBackground,
    tintColor: .tintColor
)
```

### Custom Sections

Implement `MoreViewControllerDataSource` to add custom sections and control section order:

```swift
extension MyClass: MoreViewControllerDataSource {
    func sections(for controller: MoreViewController) -> [MoreSectionType] {
        [.membership, .custom(settingsSection), .contact, .appjun, .about]
    }

    func moreViewController(_ controller: MoreViewController, didSelectCustomItem item: MoreCustomItem) {
        switch item.id {
        case "theme":
            controller.enterSettings(ThemeSetting.self)
        default:
            break
        }
    }
}
```

### Custom Promotion / Grateful Cells

Conform to `PromotionCellConfigurable` or `GratefulCellConfigurable` to provide fully custom cell implementations:

```swift
let config = MoreViewControllerConfiguration(
    // ...
    promotionCellClass: MyPromotionCell.self,
    gratefulCellClass: MyGratefulCell.self,
    // ...
)
```

### Settings

Define settings by conforming to `SettingsOption` (or `UserDefaultSettable` for automatic persistence):

```swift
enum ThemeSetting: String, UserDefaultSettable {
    case system, light, dark

    static func getKey() -> String { "theme" }
    static func getTitle() -> String { "Theme" }
    static func getOptions() -> [ThemeSetting] { [.system, .light, .dark] }
    static var defaultOption: ThemeSetting { .system }

    func getName() -> String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
```

## Built-in Sections

| Section | Description |
|---|---|
| **Membership** | Promotion cell (with purchase/restore) or grateful cell based on membership status |
| **Contact** | Email and Xiaohongshu links |
| **App Showcase** | Showcase other apps with in-app Store pages |
| **About** | Specifications, Share, Review, EULA, Privacy Policy |

## Localization

MoreKit includes localizations for: English, Simplified Chinese, Traditional Chinese (Taiwan & Hong Kong), Arabic, German, Spanish (Spain & Latin America), French, Italian, Japanese, Korean, Portuguese (Brazil & Portugal), Russian, and Ukrainian.

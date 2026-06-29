# MoreKit

A Swift package for building a fully-featured "More" tab in iOS apps, with built-in support for lifetime membership (StoreKit 2), contact section, app showcase, and specifications page.

## Requirements

- iOS 15.0+
- Swift 5.10+

## Installation

Add MoreKit to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/user/MoreKit.git", from: "2.0.0")
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

#### Widget / App Extension

From a widget or other read-only extension, call `configureForReadOnlyAccess(...)`. MoreKit attaches the shared app-group cache and does not start StoreKit in the extension process:

```swift
MoreKit.configureForReadOnlyAccess(
    appGroupID: "group.com.example.app",
    membershipKey: "com.example.Store.LifetimeMembership"  // must match the main app
)
```

If the main app passes a custom `membershipKey` to its `configure(...)` call, the extension must pass the exact same value; otherwise the two processes read and write different keys in the shared suite and the extension will never see the main app's membership state.

The main app remains responsible for populating the cache via the standard `configure(...)` call above. The extension reads membership state through `User.shared.proTier()`.

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
| `promotionConfig` | `PromotionCellConfiguration?` | `nil` | Promotion cell appearance for non-members |
| `gratefulConfig` | `GratefulCellConfiguration?` | `nil` | Post-purchase cell appearance for members |
| `email` | `String` | Required | Contact email address |
| `showContactImages` | `Bool` | `true` | Show/hide contact item icons |
| `appStoreId` | `String` | Required | App Store ID for share/review |
| `privacyPolicyURL` | `String?` | `nil` | Privacy policy URL |
| `specificationsConfig` | `SpecificationsConfiguration` | Required | Specifications page content |
| `appShowcase` | `AppShowcaseConfiguration` | `AppShowcaseConfiguration()` | App showcase section configuration |

The EULA link uses the [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) by default and is always displayed. Share and Review entries are automatically shown only when the app is live on the App Store.

The membership section is shown only when `MoreKit.productID` is configured and the current membership state has a matching config:

- free users require `promotionConfig`
- lifetime users require `gratefulConfig`

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
private func generalSection() -> MoreCustomSection {
    MoreCustomSection(
        id: "general",
        header: "General",
        items: [
            .languageSettings(),
            MoreCustomItem(
                id: "theme",
                title: "Theme",
                value: currentThemeName
            ),
        ]
    )
}

extension MyClass: MoreViewControllerDataSource {
    func sections(for controller: MoreViewController) -> [MoreSectionType] {
        [.membership, .custom(generalSection()), .contact, .appjun, .about]
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

`MoreCustomItem.languageSettings()` is handled by MoreKit and opens the app's system settings page after `didSelectCustomItem` is called. Its value defaults to the current language name resolved from the same localization bundle as its title.

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

## Membership & Entitlements

MoreKit manages a single **lifetime non-consumable** purchase (StoreKit 2) and exposes the result as a `ProTier` (`.lifetime` / `.none`). The membership section, purchase flow, and restore are wired up automatically once `productID` is configured.

### Reading membership state

Prefer `User.shared.proTier()`. It is backed by a durable cache and is correct on the first frame at launch and from read-only extensions:

```swift
if User.shared.proTier() == .lifetime {
    // unlock pro features
}
```

`Store.shared.hasValidMembership()` and `Store.shared.proTier()` reflect the live StoreKit state within the main app process.

### How state is determined (latch model)

Membership is a **latch**, driven only by unambiguous signals:

- **Granted** by positive, verified proof: a completed purchase, a verified transaction from `Transaction.updates`, or a reconciliation that finds the entitlement owned.
- **Cleared** only when a reconciliation observes the entitlement as **revoked** — a transaction whose `revocationDate` is set. Apple sets this for refunds and for loss of access through Family Sharing, and delivers it via `Transaction.updates`.
- **Never** changed by the mere *absence* of an entitlement. `Transaction.currentEntitlements` can be transiently empty (cold start, offline launch, server propagation lag); treating that as "not a member" is exactly what would wrongly downgrade a paying user, so MoreKit ignores it.

The single invariant: **positive proof is sticky; only an observed revocation clears membership.**

### Durable cache & launch hydration

The last known membership is mirrored to `UserDefaults` — the app-group suite when `appGroupID` is configured, otherwise `.standard`, under `membershipKey`. At launch MoreKit hydrates in-memory state from this cache, so membership is correct immediately, before StoreKit responds, and is visible to read-only extensions through `User.shared.proTier()`. Only the main app writes the cache; extensions never clobber it.

### Restore

`Store.shared.sync()` forces an `AppStore.sync()` and re-reconciles, retrying briefly while the entitlement is still propagating. A restore can only **grant/confirm** membership, or clear it on a **real revocation** — a transient miss never downgrades an existing member, even offline. The built-in restore button uses this.

### Revocation

Refunds and Family Sharing removal arrive as revoked transactions on `Transaction.updates`. A verified revoked transaction triggers a reconciliation (a fresh StoreKit scan) rather than clearing blindly — membership is keyed to the product, so a newer in-app repurchase is kept, and `Transaction.latest` surfaces a revoked transaction even though `currentEntitlements` omits it. Membership clears only when that scan reports `.revoked`; a transient `.missing` never downgrades. And a purchase that completes while a reconciliation is scanning always wins — the reconciliation will not clear membership over it. Revocation is intentionally **best-effort**: a refund is reflected at the next reconciliation (launch, Restore, or the revoked update) rather than instantly. This keeps the flow simple and biased toward the paying user — an owning or paying user is never shown as a non-member. MoreKit does **not** revoke a cached membership merely because a restore was performed under a different Apple ID.

### Notifications

| Name | Posted when |
|---|---|
| `.LifetimeMembership` | Membership becomes active — `purchasedProductIDs` transitions from empty to non-empty (a purchase, or a restore/reconciliation that first finds the entitlement). Not posted on launch cache hydration. |
| `.StoreInfoLoaded` | Membership state changes (granted or cleared). |
| `.StoreProductsLoaded` | Products load / price becomes available. |

```swift
NotificationCenter.default.addObserver(
    forName: .LifetimeMembership, object: nil, queue: .main
) { _ in
    // celebrate the purchase
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

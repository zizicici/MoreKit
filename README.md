# MoreKit

A Swift package for StoreKit 2 lifetime and subscription membership, app metadata, localized resources, and a fully-featured UIKit "More" tab. The StoreKit and data APIs support both iOS and macOS; UIKit controllers remain iOS-specific.

## Requirements

- iOS 15.0+
- macOS 12.0+
- Swift 5.10+

## Installation

Add MoreKit to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/zizicici/MoreKit.git", from: "2.0.0")
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

The same configuration starts StoreKit 2 in an AppKit app. MoreKit also provides native `AppShowcaseView` and `SpecificationsViewController` components on macOS; they use AppKit rather than wrapping UIKit.

```swift
MoreKit.configure(productID: "com.example.lifetime")

let tier = User.shared.proTier()
let price = Store.shared.membershipDisplayPrice()
let otherApps = AppInfo.App.allCases.filter { $0 != .watermelon }

let showcase = AppShowcaseView(
    apps: otherApps,
    visibleIconCount: 5
)

let specifications = SpecificationsViewController(
    configuration: SpecificationsConfiguration(
        summaryItems: [
            .init(type: .name, value: "Watermelon Backup"),
            .init(type: .version, value: "1.0")
        ],
        thirdPartyLibraries: []
    )
)
```

The showcase scrolls continuously, pauses while the pointer is over an icon, shows the app description, and opens the App Store when clicked. App names, descriptions, icons, and Store IDs remain packaged in MoreKit instead of being copied into each macOS app.

`MoreViewController`, promotion cells, and the built-in settings controllers use UIKit and are available only on iOS and Mac Catalyst.

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

To append app-specific rows to the built-in About section, implement
`additionalAboutItems(for:)` on the data source. It defaults to an empty array.
These rows use the same rendering and `didSelectCustomItem` callback as custom
sections, and their IDs must be unique across the page. They appear only when
the data source includes `.about` in its sections.

For a host-owned membership card or another custom row, implement
`moreViewController(_:cellFor:)` and return a `UITableViewCell`. Return `nil`
to keep MoreKit's standard rendering. Row selection still uses
`didSelectCustomItem`; embedded buttons should route through the host's same
navigation action. Include changing display state in the `MoreCustomItem`
value so snapshot updates refresh the card.

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

On iOS, options can also conform to `SettingsOptionBadgeProviding` and return a
`MoreBadgeStyle?` from `getBadge()`. `SettingOptionsViewController` displays the
badge beside the option title while preserving its selection checkmark. Return
`nil` for ordinary options, and enforce access in `setCurrent(_:)`; badges are
presentation only. The list refreshes when settings or membership status changes.

Set `MoreViewController.settingsErrorHandler` to offer host-owned recovery UI,
such as an upgrade choice for a restricted option. It receives the options
controller and error; return `true` when handled, or `false` for the standard
alert. `enterSettings(_:)` forwards this handler to the options page. A directly
created `SettingOptionsViewController` can use its `errorHandler` property.

## Membership & Entitlements

MoreKit supports an optional **lifetime non-consumable** and any number of **auto-renewable subscriptions** that unlock the same membership. `ProTier` is `.lifetime`, `.subscription`, or `.none`; lifetime takes precedence when both are owned. Callers with exhaustive switches must handle the new `.subscription` case.

Existing lifetime-only apps keep using `configure(productID:)`, `purchaseLifetimeMembership()`, and their existing promotion/grateful cells unchanged. Subscriptions are opt-in; paywall UI belongs to the host app. Non-renewing subscriptions and consumables are not membership products.

```swift
// Lifetime only: existing configuration still works.
MoreKit.configure(productID: "com.example.lifetime")

// Alternatively, configure lifetime plus subscriptions:
MoreKit.configure(
    productID: "com.example.lifetime",
    subscriptionProductIDs: ["com.example.monthly", "com.example.yearly"],
    appGroupID: "group.com.example.app"
)
// For subscription-only apps, omit productID.
// These are alternatives: call configure exactly once.
```

Subscriptions must be set up in App Store Connect. MoreKit does not create products, choose prices, or update a host app's server-side receipt validation. All registered products must grant the same access; put interchangeable subscription plans in the same subscription group.

### Host-owned paywall

MoreKit supplies purchasing and entitlement capabilities. The host app owns its paywall controller, layout, copy, plan order, and navigation. A lifetime-only app may keep its existing MoreKit promotion/grateful cells, or replace the `.membership` section with a `.custom` section using the existing `MoreViewControllerDataSource` API to open its own page. Apps offering subscriptions should provide their own plan-selection UI; MoreKit does not ship a paywall.

```swift
await Store.shared.requestProducts()
let products = Store.shared.memberships // configured order, verified product types
let outcome = try await Store.shared.purchase(productID: selectedProduct.id)
switch outcome {
case .success: /* refresh or dismiss your UI */ break
case .pending: /* explain pending approval without granting access */ break
case .cancelled: break
case .alreadyOwned: break
}
let restored = try await Store.shared.syncMembershipStatus()
```

Use `isLoadingProducts`, `productsError`, and `.StoreProductsLoaded` for loading/retry UI. Display StoreKit's `Product.displayPrice` and `subscription.subscriptionPeriod`, and supply your app's privacy policy and terms. `membershipDisplayPrice()` continues to mean the lifetime product's price. Use `supportsSubscriptions` to avoid subscription copy and controls in lifetime-only apps. `AppStore.showManageSubscriptions(in:)` opens Apple's management UI.

Buying lifetime access does not cancel an existing subscription. A host paywall should make that clear and let existing subscribers manage renewal. Introductory-offer copy requires checking eligibility; product metadata alone is not proof of eligibility.

### Subscription state

`activeSubscriptions()` exposes verified expiration, optional grace-period expiration, and optional auto-renewal intent. Canceling renewal keeps access through the paid period. A verified billing grace period grants access until its own deadline; billing retry without grace does not. Missing StoreKit data can preserve cached subscription access only until the known expiration, never indefinitely. Refunds and upgrades are reconciled per product and cannot clear separately owned lifetime access.

The store refreshes on launch, transactions, app activation, restore, and expiration. Synchronous membership reads also check the clock, including in read-only extensions. Subscription cache data is stored separately under `membershipKey + ".subscriptions.v1"`; the existing Boolean remains **lifetime only**, so an older lifetime-only reader cannot mistake a subscription for a permanent purchase. Upgrade extensions to this MoreKit version to recognize subscription access.

The rules below concerning sticky ownership apply specifically to the **lifetime product**.

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
| `.LifetimeMembership` | Lifetime ownership is first established, including upgrading from a subscription. Not posted on cache hydration. |
| `.MembershipActivated` | Access changes from no active membership to active lifetime or subscription access. Not posted on cache hydration. |
| `.StoreInfoLoaded` | Membership state changes (granted or cleared). |
| `.StoreProductsLoaded` | Product loading state changes, including load failures, for retry/loading UI. |

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

`MoreCustomItem(showsDisclosureIndicator: false)` 用于只读状态行：隐藏箭头和选中效果，并忽略点击。默认值为 `true`，保持原有导航行为。

## Membership verification

`swift test --no-parallel` covers cross-platform membership/cache rules. Use the MoreKit Xcode scheme on an iOS simulator for the existing UIKit and lifetime compatibility tests. StoreKit integration tests need an app-hosted test target: Passcord's `MembershipPurchaseTests` uses a local catalog to exercise purchase, cancellation of renewal, expiration, restore, pending approval, lifetime upgrades, and refunds without real purchases. Final release validation should also use the host app's actual App Store Connect products in Sandbox.

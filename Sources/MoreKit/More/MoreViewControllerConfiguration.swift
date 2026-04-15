//
//  MoreViewControllerConfiguration.swift
//  MoreKit
//

import UIKit
import AppInfo

public struct MoreViewControllerConfiguration {
    public let title: String
    public let tabBarImage: UIImage?

    // Membership
    public let promotionCellClass: (UITableViewCell & PromotionCellConfigurable).Type
    public let promotionConfig: PromotionCellConfiguration
    public let gratefulCellClass: (UITableViewCell & GratefulCellConfigurable).Type
    public let gratefulConfig: GratefulCellConfiguration

    // Contact
    public let email: String
    public let showContactImages: Bool

    // About
    public let appStoreId: String
    public let eulaURL: String = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    public let privacyPolicyURL: String?
    public let specificationsConfig: SpecificationsConfiguration

    // AppJun
    public let otherApps: [AppInfo.App]
    public let otherAppsDisplayCount: Int

    var contactItems: [ContactItemConfiguration] {
        [
            ContactItemConfiguration(
                id: "email",
                title: String(localized: "more.contact.email", bundle: .module),
                value: email,
                image: showContactImages ? UIImage(systemName: "envelope.circle") : nil,
                handler: .email(email)
            ),
            ContactItemConfiguration(
                id: "xiaohongshu",
                title: String(localized: "more.contact.xiaohongshu", bundle: .module),
                image: showContactImages ? UIImage(systemName: "book.closed.circle") : nil,
                handler: .url("https://www.xiaohongshu.com/user/profile/63f05fc5000000001001e524")
            ),
        ]
    }

    public init(
        title: String,
        tabBarImage: UIImage? = UIImage(systemName: "ellipsis"),
        promotionCellClass: (UITableViewCell & PromotionCellConfigurable).Type = PromotionCell.self,
        promotionConfig: PromotionCellConfiguration,
        gratefulCellClass: (UITableViewCell & GratefulCellConfigurable).Type = GratefulCell.self,
        gratefulConfig: GratefulCellConfiguration,
        email: String,
        showContactImages: Bool = true,
        appStoreId: String,
        privacyPolicyURL: String? = nil,
        specificationsConfig: SpecificationsConfiguration,
        otherApps: [AppInfo.App] = [],
        otherAppsDisplayCount: Int = 3
    ) {
        self.title = title
        self.tabBarImage = tabBarImage
        self.promotionCellClass = promotionCellClass
        self.promotionConfig = promotionConfig
        self.gratefulCellClass = gratefulCellClass
        self.gratefulConfig = gratefulConfig
        self.email = email
        self.showContactImages = showContactImages
        self.appStoreId = appStoreId
        self.privacyPolicyURL = privacyPolicyURL
        self.specificationsConfig = specificationsConfig
        self.otherApps = otherApps
        self.otherAppsDisplayCount = otherAppsDisplayCount
    }
}

struct ContactItemConfiguration: Hashable {
    let id: String
    let title: String
    let value: String?
    let image: UIImage?
    let handler: ContactHandler

    enum ContactHandler: Hashable {
        case email(String)
        case url(String)
    }

    init(
        id: String,
        title: String,
        value: String? = nil,
        image: UIImage? = nil,
        handler: ContactHandler
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.image = image
        self.handler = handler
    }
}

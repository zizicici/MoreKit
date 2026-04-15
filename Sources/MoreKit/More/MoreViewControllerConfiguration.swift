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
    public let promotionConfig: PromotionCellConfiguration
    public let gratefulConfig: GratefulCellConfiguration

    // Contact
    public let contactItems: [ContactItemConfiguration]

    // About
    public let appStoreId: String
    public let eulaURL: String?
    public let privacyPolicyURL: String?
    public let specificationsConfig: SpecificationsConfiguration

    // AppJun
    public let otherApps: [AppInfo.App]
    public let otherAppsDisplayCount: Int

    public init(
        title: String,
        tabBarImage: UIImage? = UIImage(systemName: "ellipsis"),
        promotionConfig: PromotionCellConfiguration,
        gratefulConfig: GratefulCellConfiguration,
        contactItems: [ContactItemConfiguration],
        appStoreId: String,
        eulaURL: String? = nil,
        privacyPolicyURL: String? = nil,
        specificationsConfig: SpecificationsConfiguration,
        otherApps: [AppInfo.App] = [],
        otherAppsDisplayCount: Int = 3
    ) {
        self.title = title
        self.tabBarImage = tabBarImage
        self.promotionConfig = promotionConfig
        self.gratefulConfig = gratefulConfig
        self.contactItems = contactItems
        self.appStoreId = appStoreId
        self.eulaURL = eulaURL
        self.privacyPolicyURL = privacyPolicyURL
        self.specificationsConfig = specificationsConfig
        self.otherApps = otherApps
        self.otherAppsDisplayCount = otherAppsDisplayCount
    }
}

public struct ContactItemConfiguration: Hashable {
    public let id: String
    public let title: String
    public let value: String?
    public let image: UIImage?
    public let handler: ContactHandler

    public enum ContactHandler: Hashable {
        case email(String)
        case url(String)
    }

    public init(
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

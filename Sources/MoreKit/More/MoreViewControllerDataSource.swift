//
//  MoreViewControllerDataSource.swift
//  MoreKit
//

import UIKit

public struct MoreCustomSection: Hashable {
    public let id: String
    public let header: String?
    public let footer: String?
    public let items: [MoreCustomItem]

    public init(
        id: String,
        header: String? = nil,
        footer: String? = nil,
        items: [MoreCustomItem]
    ) {
        self.id = id
        self.header = header
        self.footer = footer
        self.items = items
    }
}

public struct MoreCustomItem: Hashable {
    enum BuiltInAction: Hashable {
        case openLanguageSettings
    }

    public let id: String
    public let title: String
    public let value: String?
    public let badge: MoreBadgeStyle?
    let builtInAction: BuiltInAction?

    public init(
        id: String,
        title: String,
        value: String? = nil,
        badge: MoreBadgeStyle? = nil
    ) {
        self.init(
            id: id,
            title: title,
            value: value,
            badge: badge,
            builtInAction: nil
        )
    }

    init(
        id: String,
        title: String,
        value: String? = nil,
        badge: MoreBadgeStyle? = nil,
        builtInAction: BuiltInAction? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.badge = badge
        self.builtInAction = builtInAction
    }
}

public extension MoreCustomItem {
    static let languageSettingsID = "settings.language"

    static func languageSettings(
        title: String? = nil,
        value: String? = nil,
        badge: MoreBadgeStyle? = nil
    ) -> MoreCustomItem {
        let bundle = Bundle.module

        return MoreCustomItem(
            id: languageSettingsID,
            title: title ?? String(localized: "more.item.settings.language", bundle: bundle),
            value: value ?? Language.currentDisplayName(bundle: bundle),
            badge: badge,
            builtInAction: .openLanguageSettings
        )
    }
}

public enum MoreSectionType {
    case membership
    case custom(MoreCustomSection)
    case contact
    case appjun
    case about
}

public protocol MoreViewControllerDataSource: AnyObject {
    func sections(for controller: MoreViewController) -> [MoreSectionType]
    func moreViewController(_ controller: MoreViewController, didSelectCustomItem item: MoreCustomItem)
    func additionalReloadNotifications() -> [Notification.Name]
}

extension MoreViewControllerDataSource {
    public func additionalReloadNotifications() -> [Notification.Name] {
        return []
    }
}

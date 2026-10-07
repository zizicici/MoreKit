//
//  MoreViewControllerDataSource.swift
//  MoreKit
//

#if canImport(UIKit)
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
    public let showsDisclosureIndicator: Bool
    let builtInAction: BuiltInAction?

    public init(
        id: String,
        title: String,
        value: String? = nil,
        badge: MoreBadgeStyle? = nil,
        showsDisclosureIndicator: Bool = true
    ) {
        self.init(
            id: id,
            title: title,
            value: value,
            badge: badge,
            showsDisclosureIndicator: showsDisclosureIndicator,
            builtInAction: nil
        )
    }

    init(
        id: String,
        title: String,
        value: String? = nil,
        badge: MoreBadgeStyle? = nil,
        showsDisclosureIndicator: Bool = true,
        builtInAction: BuiltInAction? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.badge = badge
        self.showsDisclosureIndicator = showsDisclosureIndicator
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
    /// Return a host-owned cell, or nil to use the standard custom row.
    func moreViewController(_ controller: MoreViewController, cellFor item: MoreCustomItem) -> UITableViewCell?
    func moreViewController(_ controller: MoreViewController, didSelectCustomItem item: MoreCustomItem)
    func additionalReloadNotifications() -> [Notification.Name]
    /// Custom rows appended to the built-in About section. Selection uses didSelectCustomItem.
    func additionalAboutItems(for controller: MoreViewController) -> [MoreCustomItem]
}

extension MoreViewControllerDataSource {
    public func moreViewController(_ controller: MoreViewController, cellFor item: MoreCustomItem) -> UITableViewCell? {
        nil
    }

    public func additionalAboutItems(for controller: MoreViewController) -> [MoreCustomItem] {
        []
    }

    public func additionalReloadNotifications() -> [Notification.Name] {
        return []
    }
}
#endif

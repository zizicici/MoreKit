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
    public let id: String
    public let title: String
    public let value: String?
    public let badge: MoreBadgeStyle?

    public init(
        id: String,
        title: String,
        value: String? = nil,
        badge: MoreBadgeStyle? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.badge = badge
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

//
//  MoreKitAppearance.swift
//  MoreKit
//

import UIKit

public struct MoreKitAppearance {
    public static var shared = MoreKitAppearance()

    public var backgroundColor: UIColor
    public var tintColor: UIColor

    public init(
        backgroundColor: UIColor = .systemGroupedBackground,
        tintColor: UIColor = .tintColor
    ) {
        self.backgroundColor = backgroundColor
        self.tintColor = tintColor
    }
}

//
//  MoreBadgeStyle.swift
//  MoreKit
//

import UIKit

public struct MoreBadgeStyle: Hashable {
    public var text: String
    public var textColor: UIColor
    public var backgroundColor: UIColor
    public var font: UIFont
    public var cornerRadius: CGFloat
    public var contentInsets: UIEdgeInsets

    public init(
        text: String,
        textColor: UIColor = .white,
        backgroundColor: UIColor = .systemGreen,
        font: UIFont = .systemFont(ofSize: 10, weight: .bold),
        cornerRadius: CGFloat = 4,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)
    ) {
        self.text = text
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.font = font
        self.cornerRadius = cornerRadius
        self.contentInsets = contentInsets
    }

    public static func == (lhs: MoreBadgeStyle, rhs: MoreBadgeStyle) -> Bool {
        lhs.text == rhs.text
            && lhs.textColor == rhs.textColor
            && lhs.backgroundColor == rhs.backgroundColor
            && lhs.font == rhs.font
            && lhs.cornerRadius == rhs.cornerRadius
            && lhs.contentInsets == rhs.contentInsets
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(textColor)
        hasher.combine(backgroundColor)
        hasher.combine(font)
        hasher.combine(cornerRadius)
        hasher.combine(contentInsets.top)
        hasher.combine(contentInsets.left)
        hasher.combine(contentInsets.bottom)
        hasher.combine(contentInsets.right)
    }
}

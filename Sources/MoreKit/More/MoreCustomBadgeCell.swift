//
//  MoreCustomBadgeCell.swift
//  MoreKit
//

import UIKit

final class MoreCustomBadgeCell: UITableViewCell {
    static let reuseIdentifier = "MoreCustomBadgeCell"

    private var pendingItem: MoreCustomItem?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: MoreCustomItem) {
        pendingItem = item
        setNeedsUpdateConfiguration()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pendingItem = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard let previousTraitCollection else { return }
        let contentSizeCategoryChanged = traitCollection.preferredContentSizeCategory != previousTraitCollection.preferredContentSizeCategory
        let colorAppearanceChanged = traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection)
        if contentSizeCategoryChanged || colorAppearanceChanged {
            setNeedsUpdateConfiguration()
        }
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        guard let item = pendingItem else { return }

        var content = UIListContentConfiguration.valueCell().updated(for: state)
        content.secondaryText = item.value

        if let badge = item.badge {
            content.text = nil
            content.attributedText = Self.makeAttributedTitle(
                title: item.title,
                badge: badge,
                titleFont: content.textProperties.font,
                titleColor: content.textProperties.resolvedColor(),
                traitCollection: traitCollection
            )
        } else {
            content.attributedText = nil
            content.text = item.title
        }

        contentConfiguration = content
    }
}

private extension MoreCustomBadgeCell {
    static func makeAttributedTitle(
        title: String,
        badge: MoreBadgeStyle,
        titleFont: UIFont,
        titleColor: UIColor,
        traitCollection: UITraitCollection
    ) -> NSAttributedString {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor
        ]
        let result = NSMutableAttributedString(string: title, attributes: titleAttributes)
        result.append(NSAttributedString(string: " ", attributes: titleAttributes))

        let attachment = NSTextAttachment()
        let image = makeBadgeImage(style: badge, traitCollection: traitCollection)
        let yOffset = round((titleFont.capHeight - image.size.height) / 2)
        attachment.image = image
        attachment.bounds = CGRect(origin: CGPoint(x: 0, y: yOffset), size: image.size)
        result.append(NSAttributedString(attachment: attachment))
        return result
    }

    static func makeBadgeImage(
        style: MoreBadgeStyle,
        traitCollection: UITraitCollection
    ) -> UIImage {
        let metrics = UIFontMetrics(forTextStyle: .caption2)
        let font = metrics.scaledFont(for: style.font, compatibleWith: traitCollection)
        let insets = UIEdgeInsets(
            top: metrics.scaledValue(for: style.contentInsets.top, compatibleWith: traitCollection),
            left: metrics.scaledValue(for: style.contentInsets.left, compatibleWith: traitCollection),
            bottom: metrics.scaledValue(for: style.contentInsets.bottom, compatibleWith: traitCollection),
            right: metrics.scaledValue(for: style.contentInsets.right, compatibleWith: traitCollection)
        )
        let cornerRadius = metrics.scaledValue(for: style.cornerRadius, compatibleWith: traitCollection)

        let text = style.text as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = text.size(withAttributes: textAttributes)
        let size = CGSize(
            width: ceil(textSize.width + insets.left + insets.right),
            height: ceil(textSize.height + insets.top + insets.bottom)
        )

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = traitCollection.displayScale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let backgroundColor = style.backgroundColor.resolvedColor(with: traitCollection)
        let textColor = style.textColor.resolvedColor(with: traitCollection)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(
                roundedRect: rect,
                cornerRadius: min(cornerRadius, size.height / 2)
            )
            backgroundColor.setFill()
            path.fill()

            let textRect = CGRect(
                x: insets.left,
                y: insets.top,
                width: ceil(textSize.width),
                height: ceil(textSize.height)
            )
            text.draw(
                in: textRect,
                withAttributes: [
                    .font: font,
                    .foregroundColor: textColor
                ]
            )
        }
    }
}

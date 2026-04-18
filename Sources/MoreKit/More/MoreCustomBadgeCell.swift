//
//  MoreCustomBadgeCell.swift
//  MoreKit
//

import UIKit

final class MoreCustomBadgeCell: UITableViewCell {
    static let reuseIdentifier = "MoreCustomBadgeCell"

    private static func baseContentConfiguration() -> UIListContentConfiguration {
        .valueCell()
    }

    private lazy var listContentView = UIListContentView(configuration: Self.baseContentConfiguration())
    private let badgeContainer = UIView()
    private let badgeLabel = UILabel()
    private let valueLabel = UILabel()

    private var pendingItem: MoreCustomItem?

    private static let badgeToTitleSpacing: CGFloat = 6

    private var spacingConstraints: (
        valueLeading: NSLayoutConstraint,
        valueTrailing: NSLayoutConstraint
    )?
    private var badgeLeadingConstraint: NSLayoutConstraint?
    private var badgeInsetConstraints: (
        top: NSLayoutConstraint,
        leading: NSLayoutConstraint,
        trailing: NSLayoutConstraint,
        bottom: NSLayoutConstraint
    )?

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

    private func setupViewsIfNeeded() {
        guard spacingConstraints == nil else { return }

        contentView.addSubview(listContentView)
        contentView.addSubview(badgeContainer)
        contentView.addSubview(valueLabel)
        badgeContainer.addSubview(badgeLabel)

        listContentView.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        // Let title region shrink first so the value/badge stay pinned.
        let defaultComp = listContentView.contentCompressionResistancePriority(for: .horizontal)
        listContentView.setContentCompressionResistancePriority(defaultComp - 1, for: .horizontal)

        badgeContainer.layer.masksToBounds = true
        badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
        badgeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let valueLeading = valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: badgeContainer.trailingAnchor)
        let valueTrailing = contentView.trailingAnchor.constraint(equalTo: valueLabel.trailingAnchor)

        NSLayoutConstraint.activate([
            listContentView.topAnchor.constraint(equalTo: contentView.topAnchor),
            listContentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            listContentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            listContentView.trailingAnchor.constraint(greaterThanOrEqualTo: badgeContainer.leadingAnchor),
            badgeContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLeading,
            valueTrailing
        ])

        let top = badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor)
        let leading = badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor)
        let trailing = badgeContainer.trailingAnchor.constraint(equalTo: badgeLabel.trailingAnchor)
        let bottom = badgeContainer.bottomAnchor.constraint(equalTo: badgeLabel.bottomAnchor)
        NSLayoutConstraint.activate([top, leading, trailing, bottom])

        spacingConstraints = (valueLeading, valueTrailing)
        badgeInsetConstraints = (top, leading, trailing, bottom)
    }

    private func updateBadgeLeadingConstraintIfNeeded() {
        guard let textLayoutGuide = listContentView.textLayoutGuide else { return }
        if badgeLeadingConstraint?.isActive == true { return }
        let constraint = badgeContainer.leadingAnchor.constraint(
            equalTo: textLayoutGuide.trailingAnchor,
            constant: Self.badgeToTitleSpacing
        )
        constraint.isActive = true
        badgeLeadingConstraint = constraint
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        guard let item = pendingItem else { return }
        setupViewsIfNeeded()

        // Base list content view carries only the title — inherits valueCell metrics.
        var content = Self.baseContentConfiguration().updated(for: state)
        content.text = item.title
        content.secondaryText = nil
        content.axesPreservingSuperviewLayoutMargins = []
        listContentView.configuration = content

        // Copy system styling + metrics from the reference valueCell configuration.
        let reference = UIListContentConfiguration.valueCell().updated(for: state)
        valueLabel.text = item.value
        valueLabel.font = reference.secondaryTextProperties.font
        valueLabel.textColor = reference.secondaryTextProperties.resolvedColor()
        valueLabel.adjustsFontForContentSizeCategory = reference.secondaryTextProperties.adjustsFontForContentSizeCategory

        spacingConstraints?.valueLeading.constant = reference.textToSecondaryTextHorizontalPadding
        spacingConstraints?.valueTrailing.constant = content.directionalLayoutMargins.trailing

        updateBadgeLeadingConstraintIfNeeded()

        guard let style = item.badge else {
            badgeContainer.isHidden = true
            return
        }
        badgeContainer.isHidden = false
        badgeContainer.backgroundColor = style.backgroundColor
        badgeContainer.layer.cornerRadius = style.cornerRadius
        badgeLabel.text = style.text
        badgeLabel.textColor = style.textColor
        badgeLabel.font = style.font
        badgeLabel.adjustsFontForContentSizeCategory = true

        badgeInsetConstraints?.top.constant = style.contentInsets.top
        badgeInsetConstraints?.leading.constant = style.contentInsets.left
        badgeInsetConstraints?.trailing.constant = style.contentInsets.right
        badgeInsetConstraints?.bottom.constant = style.contentInsets.bottom
    }
}

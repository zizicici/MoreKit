//
//  PromotionCell.swift
//  MoreKit
//

import UIKit
import SnapKit

public struct PromotionCellConfiguration {
    public let title: String
    public let titleHighlight: String?
    public let features: [String]
    public let gradientColors: [UIColor]
    public let titleColor: UIColor
    public let titleHighlightColor: UIColor
    public let featureColor: UIColor
    public let buttonTintColor: UIColor
    public let buttonTextColor: UIColor
    public let buttonTitle: String
    public let buttonIcon: String?

    public init(
        title: String,
        titleHighlight: String? = nil,
        features: [String],
        gradientColors: [UIColor] = [UIColor(hex: "44B97B")!, UIColor(hex: "009E4D")!],
        titleColor: UIColor = .white,
        titleHighlightColor: UIColor = .white,
        featureColor: UIColor = .white.withAlphaComponent(0.8),
        buttonTintColor: UIColor = .white,
        buttonTextColor: UIColor = .black,
        buttonTitle: String? = nil,
        buttonIcon: String? = "arrowshape.up.circle"
    ) {
        self.title = title
        self.titleHighlight = titleHighlight
        self.features = features
        self.gradientColors = gradientColors
        self.titleColor = titleColor
        self.titleHighlightColor = titleHighlightColor
        self.featureColor = featureColor
        self.buttonTintColor = buttonTintColor
        self.buttonTextColor = buttonTextColor
        self.buttonTitle = buttonTitle ?? String(localized: "store.purchase", bundle: .module)
        self.buttonIcon = buttonIcon
    }
}

public class PromotionCell: UITableViewCell, PromotionCellConfigurable {
    public var purchaseClosure: (() -> ())?
    public var restoreClosure: (() -> ())?

    private let gradientView = GradientView()

    private var topLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textAlignment = .natural
        label.textColor = .white
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let featureStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        return stack
    }()

    private var purchaseButton: UIButton!
    private var buttonTextColor: UIColor = .black

    private var priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textAlignment = .center
        label.textColor = .white.withAlphaComponent(0.9)
        label.numberOfLines = 1
        label.text = "?.??"
        return label
    }()

    private var restoreButton: UIButton!

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupPurchaseButton()
        setupRestoreButton()

        contentView.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        // Button Part
        contentView.addSubview(priceLabel)
        contentView.addSubview(purchaseButton)
        purchaseButton.snp.makeConstraints { make in
            make.bottom.equalTo(priceLabel.snp.top).offset(-6)
            make.trailing.equalTo(contentView).inset(20)
        }
        priceLabel.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.centerY)
            make.leading.trailing.equalTo(purchaseButton)
        }
        contentView.addSubview(restoreButton)
        restoreButton.snp.makeConstraints { make in
            make.bottom.equalTo(contentView).inset(20)
            make.trailing.lessThanOrEqualTo(contentView).inset(18)
            make.centerX.equalTo(priceLabel).priority(.medium)
            make.top.greaterThanOrEqualTo(priceLabel.snp.bottom).offset(10)
        }
        restoreButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Text Part
        contentView.addSubview(topLabel)
        topLabel.snp.makeConstraints { make in
            make.top.equalTo(contentView).inset(20)
            make.leading.equalTo(contentView).inset(20)
            make.trailing.equalTo(purchaseButton.snp.leading).offset(-10)
        }
        topLabel.setContentHuggingPriority(.defaultLow, for: .vertical)

        contentView.addSubview(featureStackView)
        featureStackView.snp.makeConstraints { make in
            make.top.equalTo(topLabel.snp.bottom).offset(12)
            make.leading.equalTo(contentView).inset(22)
            make.trailing.equalTo(restoreButton.snp.leading).offset(-4)
            make.bottom.equalTo(contentView).inset(20)
        }

        let view = UIView()
        selectedBackgroundView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupPurchaseButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = String(localized: "store.purchase", bundle: .module)
        configuration.titleAlignment = .center
        configuration.imagePadding = 6.0
        configuration.cornerStyle = .large
        configuration.titlePadding = 10.0
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer({ incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            return outgoing
        })

        purchaseButton = UIButton(configuration: configuration)
        purchaseButton.tintColor = .white
        purchaseButton.setContentHuggingPriority(.required, for: .horizontal)
        purchaseButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        purchaseButton.addTarget(self, action: #selector(purchaseAction), for: .touchUpInside)
    }

    private func setupRestoreButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = String(localized: "store.restore", bundle: .module)
        configuration.titleAlignment = .center
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer({ incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
            outgoing.underlineStyle = [.single]
            outgoing.underlineColor = .white.withAlphaComponent(0.8)
            return outgoing
        })
        configuration.contentInsets = .init(top: 0, leading: 4, bottom: 0, trailing: 4)

        restoreButton = UIButton(configuration: configuration)
        restoreButton.tintColor = .white.withAlphaComponent(0.8)
        restoreButton.addTarget(self, action: #selector(restoreAction), for: .touchUpInside)
    }

    @objc
    func restoreAction() {
        restoreClosure?()
    }

    @objc
    func purchaseAction() {
        purchaseClosure?()
    }

    public func update(configuration config: PromotionCellConfiguration) {
        gradientView.gradientColors = config.gradientColors
        buttonTextColor = config.buttonTextColor

        // Title
        let text = config.title
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.foregroundColor, value: config.titleColor, range: NSRange(location: 0, length: text.count))
        if let highlight = config.titleHighlight, let range = text.range(of: highlight) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.foregroundColor, value: config.titleHighlightColor, range: nsRange)
        }
        topLabel.attributedText = attributedString

        // Features (rebuild stack view)
        featureStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for feature in config.features {
            let label = UILabel()
            label.font = UIFont.preferredFont(forTextStyle: .footnote)
            label.textAlignment = .natural
            label.textColor = config.featureColor
            label.numberOfLines = 0
            label.text = feature
            featureStackView.addArrangedSubview(label)
        }

        // Button colors
        purchaseButton.tintColor = config.buttonTintColor
        priceLabel.textColor = config.buttonTintColor.withAlphaComponent(0.9)

        var btnConfig = purchaseButton.configuration
        btnConfig?.title = config.buttonTitle
        if let iconName = config.buttonIcon {
            btnConfig?.image = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))?.withTintColor(config.buttonTextColor, renderingMode: .alwaysOriginal)
        } else {
            btnConfig?.image = nil
        }
        btnConfig?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer({ incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            outgoing.foregroundColor = config.buttonTextColor
            return outgoing
        })
        purchaseButton.configuration = btnConfig
    }

    public func update(price: String) {
        priceLabel.text = price
    }
}

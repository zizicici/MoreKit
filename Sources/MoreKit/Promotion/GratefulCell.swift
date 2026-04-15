//
//  GratefulCell.swift
//  MoreKit
//

import UIKit
import SnapKit

public struct GratefulCellConfiguration {
    public let title: String
    public let titleHighlight: String?
    public let content: String
    public let gradientColors: [UIColor]
    public let titleColor: UIColor
    public let titleHighlightColor: UIColor
    public let contentColor: UIColor

    public init(
        title: String,
        titleHighlight: String? = nil,
        content: String,
        gradientColors: [UIColor] = [UIColor(hex: "44B97B")!, UIColor(hex: "009E4D")!],
        titleColor: UIColor = .white,
        titleHighlightColor: UIColor = .systemYellow,
        contentColor: UIColor = .white.withAlphaComponent(0.8)
    ) {
        self.title = title
        self.titleHighlight = titleHighlight
        self.content = content
        self.gradientColors = gradientColors
        self.titleColor = titleColor
        self.titleHighlightColor = titleHighlightColor
        self.contentColor = contentColor
    }
}

public class GratefulCell: UITableViewCell {
    private let gradientView = GradientView()

    private var topLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.textColor = .white
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private var contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textAlignment = .center
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        contentView.addSubview(topLabel)
        topLabel.snp.makeConstraints { make in
            make.top.equalTo(contentView).inset(20)
            make.leading.equalTo(contentView).inset(20)
            make.trailing.equalTo(contentView).inset(20)
        }
        topLabel.setContentHuggingPriority(.defaultLow, for: .vertical)

        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(topLabel.snp.bottom).offset(12)
            make.bottom.equalTo(contentView).inset(20)
            make.leading.trailing.equalTo(contentView).inset(20)
        }

        let view = UIView()
        selectedBackgroundView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(configuration: GratefulCellConfiguration) {
        gradientView.gradientColors = configuration.gradientColors

        let text = configuration.title
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.foregroundColor, value: configuration.titleColor, range: NSRange(location: 0, length: text.count))
        if let highlight = configuration.titleHighlight, let range = text.range(of: highlight) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.foregroundColor, value: configuration.titleHighlightColor, range: nsRange)
        }
        topLabel.attributedText = attributedString

        contentLabel.text = configuration.content
        contentLabel.textColor = configuration.contentColor
    }
}

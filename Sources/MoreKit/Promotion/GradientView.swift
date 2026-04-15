//
//  GradientView.swift
//  MoreKit
//

import UIKit

public class GradientView: UIView {
    public var gradientColors: [UIColor] = [
        UIColor(hex: "44B97B")!,
        UIColor(hex: "009E4D")!
    ] {
        didSet { updateGradient() }
    }

    override public class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    public init(colors: [UIColor]? = nil) {
        super.init(frame: .zero)
        if let colors = colors {
            gradientColors = colors
        }
        setupGradient()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupGradient()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    private func setupGradient() {
        let gradientLayer = self.layer as! CAGradientLayer
        gradientLayer.colors = gradientColors.map { $0.cgColor }
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.2, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.8, y: 1.0)
    }

    private func updateGradient() {
        let gradientLayer = self.layer as! CAGradientLayer
        gradientLayer.colors = gradientColors.map { $0.cgColor }
    }
}

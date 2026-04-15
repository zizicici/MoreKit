//
//  OverlayViewController.swift
//  MoreKit
//

import UIKit

public class OverlayViewController: UIViewController {
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        activityIndicator.startAnimating()
    }
}

extension UIViewController {
    public func showOverlayViewController() {
        let overlayVC = OverlayViewController()

        overlayVC.modalPresentationStyle = .overCurrentContext
        overlayVC.modalTransitionStyle = .crossDissolve

        navigationController?.present(overlayVC, animated: ConsideringUser.animated, completion: nil)
    }

    public func hideOverlayViewController() {
        navigationController?.dismiss(animated: ConsideringUser.animated, completion: nil)
    }
}

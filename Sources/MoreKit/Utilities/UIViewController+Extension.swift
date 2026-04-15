//
//  UIViewController+Extension.swift
//  MoreKit
//

import UIKit
import SafariServices

extension UIViewController {
    public func openSF(with url: URL) {
        let safariViewController = SFSafariViewController(url: url)
        navigationController?.present(safariViewController, animated: ConsideringUser.animated)
    }
}

extension UIViewController {
    public func showAlert(title: String?, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: String(localized: "common.ok", bundle: .module), style: .cancel)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}

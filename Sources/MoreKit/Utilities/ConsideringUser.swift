//
//  ConsideringUser.swift
//  MoreKit
//

import UIKit

public struct ConsideringUser {
    public static var animated: Bool {
        return UIAccessibility.isReduceMotionEnabled ? false : true
    }

    public static var pushAnimated: Bool {
        return UIAccessibility.prefersCrossFadeTransitions ? false : true
    }

    public static var buttonShapesEnabled: Bool {
        return UIAccessibility.buttonShapesEnabled
    }
}

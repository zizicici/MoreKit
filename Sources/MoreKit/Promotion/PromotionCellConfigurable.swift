//
//  PromotionCellConfigurable.swift
//  MoreKit
//

import UIKit

public protocol PromotionCellConfigurable: AnyObject {
    var purchaseClosure: (() -> ())? { get set }
    var restoreClosure: (() -> ())? { get set }
    func update(configuration: PromotionCellConfiguration)
    func update(price: String)
}

public protocol GratefulCellConfigurable: AnyObject {
    func update(configuration: GratefulCellConfiguration)
}

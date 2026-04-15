//
//  Array+Extension.swift
//  MoreKit
//

import Foundation

extension Array {
    public func randomElements(_ count: Int) -> [Element] {
        guard count <= self.count else {
            return self.shuffled()
        }
        return Array(self.shuffled().prefix(count))
    }
}

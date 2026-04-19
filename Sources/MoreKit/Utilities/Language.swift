//
//  Language.swift
//  MoreKit
//

import Foundation

public struct Language {
    public enum LanguageType: Equatable {
        case zh
        case en
        case ja
    }

    public static func type() -> LanguageType {
        guard let preferred = Locale.preferredLanguages.first else { return .en }
        if preferred.hasPrefix("zh") {
            return .zh
        } else if preferred.hasPrefix("ja") {
            return .ja
        } else {
            return .en
        }
    }
}

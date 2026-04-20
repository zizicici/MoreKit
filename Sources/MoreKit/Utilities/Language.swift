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

    public static func currentDisplayName(bundle: Bundle = .main) -> String {
        let identifier = bundle.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        return displayName(for: identifier)
    }

    public static func displayName(for identifier: String) -> String {
        let locale = Locale(identifier: identifier)
        if let displayName = locale.localizedString(forIdentifier: identifier), !displayName.isEmpty {
            return displayName
        }

        let languageCode = identifier.split(separator: "-").first.map(String.init) ?? identifier
        if let displayName = locale.localizedString(forLanguageCode: languageCode), !displayName.isEmpty {
            return displayName
        }

        return identifier
    }
}

import Foundation

public struct AppShowcaseConfiguration: Hashable {
    public let apps: [AppInfo.App]
    public let displayCount: Int
    public let developerPageURL: String?
    public let automaticallyIncludesFestivalsForChineseLocales: Bool

    public init(
        apps: [AppInfo.App] = [],
        displayCount: Int = 3,
        developerPageURL: String? = AppInfo.Developer.pageURL,
        automaticallyIncludesFestivalsForChineseLocales: Bool = true
    ) {
        self.apps = apps
        self.displayCount = max(0, displayCount)
        self.developerPageURL = developerPageURL
        self.automaticallyIncludesFestivalsForChineseLocales = automaticallyIncludesFestivalsForChineseLocales
    }

    var showsDeveloperPageEntry: Bool {
        developerPageURL != nil
    }

    func resolvedApps(for language: Language.LanguageType) -> [AppInfo.App] {
        var resolved = apps
        if automaticallyIncludesFestivalsForChineseLocales,
           language == .zh,
           !resolved.contains(.festivals) {
            resolved.append(.festivals)
        }
        return resolved
    }

    func displayedApps(for language: Language.LanguageType) -> [AppInfo.App] {
        resolvedApps(for: language).randomElements(displayCount)
    }
}

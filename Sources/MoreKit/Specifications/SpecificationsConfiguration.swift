import Foundation

public struct SpecificationsConfiguration: Hashable, Sendable {
    public struct SummaryItem: Hashable, Sendable {
        public enum ItemType: Hashable, Sendable {
            case name
            case version
            case manufacturer
            case publisher
            case dateOfProduction
            case license
            case custom(String)

            public var localizedLabel: String {
                switch self {
                case .name:
                    String(localized: "specifications.name", defaultValue: "Name", bundle: .module)
                case .version:
                    String(localized: "specifications.version", defaultValue: "Version", bundle: .module)
                case .manufacturer:
                    String(localized: "specifications.manufacturer", defaultValue: "Manufacturer", bundle: .module)
                case .publisher:
                    String(localized: "specifications.publisher", defaultValue: "Publisher", bundle: .module)
                case .dateOfProduction:
                    String(localized: "specifications.dateOfProduction", defaultValue: "Date of Production", bundle: .module)
                case .license:
                    String(localized: "specifications.license", defaultValue: "ICP Filing Number", bundle: .module)
                case .custom(let title):
                    title
                }
            }
        }

        public let type: ItemType
        public let value: String

        public init(type: ItemType, value: String) {
            self.type = type
            self.value = value
        }
    }

    public struct ThirdPartyLibrary: Hashable, Sendable {
        public let name: String
        public let version: String
        public let urlString: String

        public init(name: String, version: String, urlString: String) {
            self.name = name
            self.version = version
            self.urlString = urlString
        }

        public var url: URL? {
            URL(string: urlString)
        }
    }

    public let summaryItems: [SummaryItem]
    public let thirdPartyLibraries: [ThirdPartyLibrary]
    public let title: String?

    public init(
        summaryItems: [SummaryItem],
        thirdPartyLibraries: [ThirdPartyLibrary],
        title: String? = nil
    ) {
        self.summaryItems = summaryItems
        self.thirdPartyLibraries = thirdPartyLibraries
        self.title = title
    }
}

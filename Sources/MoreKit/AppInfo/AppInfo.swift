import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum AppInfo {
    public enum Developer {
        public static let pageURL = "https://apps.apple.com/developer/zizicici-limited/id1564555697"
    }

    public enum App: CaseIterable, Hashable, Sendable {
        case lemon
        case moontake
        case coconut
        case festivals
        case pigeon
        case one
        case offDay
        case tagDay
        case pin
        case campfire
        case watermelon
        case doufu

        public var imageName: String {
            switch self {
            case .lemon:
                "LemonIcon"
            case .moontake:
                "MoontakeIcon"
            case .coconut:
                "CoconutIcon"
            case .festivals:
                "FestivalsIcon"
            case .pigeon:
                "PigeonIcon"
            case .one:
                "OneOneIcon"
            case .offDay:
                "OffDayIcon"
            case .tagDay:
                "TagDayIcon"
            case .pin:
                "PinItIcon"
            case .campfire:
                "CampfireIcon"
            case .watermelon:
                "WatermelonIcon"
            case .doufu:
                "DoufuIcon"
            }
        }

        private var imageFileName: String {
            switch self {
            case .moontake:
                "moontake.png"
            case .festivals, .pigeon:
                "AppIcon.png"
            case .offDay:
                "zzz.png"
            default:
                "\(imageName).png"
            }
        }

        #if canImport(UIKit)
        public var image: UIImage? {
            UIImage(named: imageName, in: .module, compatibleWith: nil)
        }
        #elseif canImport(AppKit)
        public var image: NSImage? {
            if let image = Bundle.module.image(
                forResource: NSImage.Name(imageName)
            ) {
                return image
            }
            guard let url = Bundle.module.url(
                forResource: imageFileName,
                withExtension: nil,
                subdirectory: "AppInfoAssets.xcassets/\(imageName).imageset"
            ) else {
                return nil
            }
            return NSImage(contentsOf: url)
        }
        #endif

        public var name: String {
            switch self {
            case .lemon:
                String(localized: "app.lemon.title", defaultValue: "A Lemon Diary", bundle: .module)
            case .moontake:
                "moontake"
            case .coconut:
                String(localized: "app.coconut.title", defaultValue: "Calendar Island", bundle: .module)
            case .festivals:
                String(localized: "app.festivals.title", defaultValue: "China Festivals", bundle: .module)
            case .pigeon:
                String(localized: "app.pigeon.title", defaultValue: "Air Pigeon", bundle: .module)
            case .one:
                "1/1"
            case .offDay:
                String(localized: "app.offDay.title", defaultValue: "Off Day", bundle: .module)
            case .tagDay:
                String(localized: "app.tagDay.title", defaultValue: "Tag Day", bundle: .module)
            case .pin:
                String(localized: "app.pin.title", defaultValue: "Pin It", bundle: .module)
            case .campfire:
                String(localized: "app.campfire.title", defaultValue: "Campfire", bundle: .module)
            case .watermelon:
                String(localized: "app.watermelon.title", defaultValue: "Watermelon", bundle: .module)
            case .doufu:
                String(localized: "app.doufu.title", defaultValue: "Doufu", bundle: .module)
            }
        }

        public var subtitle: String {
            switch self {
            case .lemon:
                String(localized: "app.lemon.subtitle", defaultValue: "A pure text diary", bundle: .module)
            case .moontake:
                String(localized: "app.moontake.subtitle", defaultValue: "A camera for moon", bundle: .module)
            case .coconut:
                String(localized: "app.coconut.subtitle", defaultValue: "Calendar + Dynamic Island", bundle: .module)
            case .festivals:
                String(localized: "app.festivals.subtitle", defaultValue: "What festival is it today?", bundle: .module)
            case .pigeon:
                String(localized: "app.pigeon.subtitle", defaultValue: "Focus Mode On", bundle: .module)
            case .one:
                String(localized: "app.one.subtitle", defaultValue: "Life Grid", bundle: .module)
            case .offDay:
                String(localized: "app.offDay.subtitle", defaultValue: "Disable Alarms in Off Day", bundle: .module)
            case .tagDay:
                String(localized: "app.tagDay.subtitle", defaultValue: "Add Tags Day by Day", bundle: .module)
            case .pin:
                String(localized: "app.pin.subtitle", defaultValue: "Pin Images in Dynamic Island", bundle: .module)
            case .campfire:
                String(localized: "app.campfire.subtitle", defaultValue: "Write, Talk and Burn them all", bundle: .module)
            case .watermelon:
                String(localized: "app.watermelon.subtitle", defaultValue: "Photos Backup Master", bundle: .module)
            case .doufu:
                String(localized: "app.doufu.subtitle", defaultValue: "LLM+HTML+CSS+JS", bundle: .module)
            }
        }

        public var storeId: String {
            switch self {
            case .lemon:
                "6449700998"
            case .moontake:
                "6451189717"
            case .coconut:
                "6469671638"
            case .festivals:
                "6460976841"
            case .pigeon:
                "6473819512"
            case .one:
                "6474681491"
            case .offDay:
                "6501973975"
            case .tagDay:
                "6745145597"
            case .pin:
                "6753946385"
            case .campfire:
                "6758535659"
            case .watermelon:
                "6762260596"
            case .doufu:
                "6760194187"
            }
        }

        public var storeURL: URL {
            URL(string: "https://apps.apple.com/app/id\(storeId)")!
        }
    }

    #if canImport(UIKit)
    public class AppCell: UITableViewCell {
        private var icon: UIImageView = {
            let imageView = UIImageView()
            return imageView
        }()

        private var firstLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.textAlignment = .natural
            label.textColor = .label
            label.numberOfLines = 1
            return label
        }()

        private var secondLabel: UILabel = {
            let label = UILabel()
            label.font = UIFont.preferredFont(forTextStyle: .callout)
            label.textAlignment = .natural
            label.textColor = .secondaryLabel
            label.numberOfLines = 1
            return label
        }()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            contentView.addSubview(icon)
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                icon.widthAnchor.constraint(equalToConstant: 50),
                icon.heightAnchor.constraint(equalToConstant: 50),
                icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])

            contentView.addSubview(firstLabel)
            firstLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                firstLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
                firstLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                firstLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12)
            ])

            contentView.addSubview(secondLabel)
            secondLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                secondLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
                secondLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                secondLabel.topAnchor.constraint(equalTo: firstLabel.bottomAnchor, constant: 10),
                secondLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public func update(_ app: App) {
            icon.image = app.image
            firstLabel.text = app.name
            secondLabel.text = app.subtitle
        }
    }
    #endif
}

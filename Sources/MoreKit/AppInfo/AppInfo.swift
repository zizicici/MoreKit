import UIKit

public enum AppInfo {
    public enum Developer {
        public static let pageURL = "https://apps.apple.com/developer/zizicici-limited/id1564555697"
    }

    public enum App: Hashable {
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

        var image: UIImage? {
            switch self {
            case .lemon:
                UIImage(named: "LemonIcon", in: .module, compatibleWith: nil)
            case .moontake:
                UIImage(named: "MoontakeIcon", in: .module, compatibleWith: nil)
            case .coconut:
                UIImage(named: "CoconutIcon", in: .module, compatibleWith: nil)
            case .festivals:
                UIImage(named: "FestivalsIcon", in: .module, compatibleWith: nil)
            case .pigeon:
                UIImage(named: "PigeonIcon", in: .module, compatibleWith: nil)
            case .one:
                UIImage(named: "OneOneIcon", in: .module, compatibleWith: nil)
            case .offDay:
                UIImage(named: "OffDayIcon", in: .module, compatibleWith: nil)
            case .tagDay:
                UIImage(named: "TagDayIcon", in: .module, compatibleWith: nil)
            case .pin:
                UIImage(named: "PinItIcon", in: .module, compatibleWith: nil)
            case .campfire:
                UIImage(named: "CampfireIcon", in: .module, compatibleWith: nil)
            case .watermelon:
                UIImage(named: "WatermelonIcon", in: .module, compatibleWith: nil)
            case .doufu:
                UIImage(named: "DoufuIcon", in: .module, compatibleWith: nil)
            }
        }

        var name: String {
            switch self {
            case .lemon:
                String(localized: "app.lemon.title", bundle: .module, comment: "A Lemon Diary")
            case .moontake:
                "moontake"
            case .coconut:
                String(localized: "app.coconut.title", bundle: .module, comment: "Calendar Island")
            case .festivals:
                String(localized: "app.festivals.title", bundle: .module, comment: "China Festivals")
            case .pigeon:
                String(localized: "app.pigeon.title", bundle: .module, comment: "Air Pigeon")
            case .one:
                "1/1"
            case .offDay:
                String(localized: "app.offDay.title", bundle: .module, comment: "Off Day")
            case .tagDay:
                String(localized: "app.tagDay.title", bundle: .module)
            case .pin:
                String(localized: "app.pin.title", bundle: .module)
            case .campfire:
                String(localized: "app.campfire.title", bundle: .module)
            case .watermelon:
                String(localized: "app.watermelon.title", bundle: .module)
            case .doufu:
                String(localized: "app.doufu.title", bundle: .module)
            }
        }

        var subtitle: String {
            switch self {
            case .lemon:
                String(localized: "app.lemon.subtitle", bundle: .module, comment: "A pure text diary")
            case .moontake:
                String(localized: "app.moontake.subtitle", bundle: .module, comment: "A camera for moon")
            case .coconut:
                String(localized: "app.coconut.subtitle", bundle: .module, comment: "Calendar + Dynamic Island")
            case .festivals:
                String(localized: "app.festivals.subtitle", bundle: .module, comment: "What festival is it today?")
            case .pigeon:
                String(localized: "app.pigeon.subtitle", bundle: .module, comment: "Focus Mode On")
            case .one:
                String(localized: "app.one.subtitle", bundle: .module, comment: "1/1")
            case .offDay:
                String(localized: "app.offDay.subtitle", bundle: .module)
            case .tagDay:
                String(localized: "app.tagDay.subtitle", bundle: .module)
            case .pin:
                String(localized: "app.pin.subtitle", bundle: .module)
            case .campfire:
                String(localized: "app.campfire.subtitle", bundle: .module)
            case .watermelon:
                String(localized: "app.watermelon.subtitle", bundle: .module)
            case .doufu:
                String(localized: "app.doufu.subtitle", bundle: .module)
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
    }

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
}

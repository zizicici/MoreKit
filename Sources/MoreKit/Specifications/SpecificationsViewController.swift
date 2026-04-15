//
//  SpecificationsViewController.swift
//  MoreKit
//

import UIKit
import SnapKit
import SafariServices

// MARK: - Configuration

public struct SpecificationsConfiguration {
    public struct SummaryItem: Hashable {
        public enum ItemType: Hashable {
            case name
            case version
            case manufacturer
            case publisher
            case dateOfProduction
            case license
            case custom(String)

            var localizedLabel: String {
                switch self {
                case .name:
                    return String(localized: "specifications.name", bundle: .module)
                case .version:
                    return String(localized: "specifications.version", bundle: .module)
                case .manufacturer:
                    return String(localized: "specifications.manufacturer", bundle: .module)
                case .publisher:
                    return String(localized: "specifications.publisher", bundle: .module)
                case .dateOfProduction:
                    return String(localized: "specifications.dateOfProduction", bundle: .module)
                case .license:
                    return String(localized: "specifications.license", bundle: .module)
                case .custom(let title):
                    return title
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

    public struct ThirdPartyLibrary: Hashable {
        public let name: String
        public let version: String
        public let urlString: String

        public init(name: String, version: String, urlString: String) {
            self.name = name
            self.version = version
            self.urlString = urlString
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

// MARK: - ViewController

public class SpecificationsViewController: UIViewController {
    private let configuration: SpecificationsConfiguration
    private var tableView: UITableView!
    private var dataSource: DataSource!

    enum Section: Int, Hashable {
        case summary
        case thirdParty

        func headerTitle() -> String? {
            switch self {
            case .summary:
                return nil
            case .thirdParty:
                return String(localized: "specifications.thirdParty.header", bundle: .module)
            }
        }

        func footerTitle() -> String? {
            switch self {
            case .thirdParty:
                return String(localized: "specifications.thirdParty.footer", bundle: .module)
            default:
                return nil
            }
        }
    }

    enum Item: Hashable {
        case summary(SpecificationsConfiguration.SummaryItem)
        case thirdParty(SpecificationsConfiguration.ThirdPartyLibrary)
    }

    class DataSource: UITableViewDiffableDataSource<Section, Item> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            let sectionKind = sectionIdentifier(for: section)
            return sectionKind?.headerTitle()
        }

        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            let sectionKind = sectionIdentifier(for: section)
            return sectionKind?.footerTitle()
        }
    }

    public init(configuration: SpecificationsConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        title = configuration.title ?? String(localized: "specifications.title", bundle: .module)
        navigationItem.largeTitleDisplayMode = .never

        view.backgroundColor = MoreKitAppearance.shared.backgroundColor

        configureHierarchy()
        configureDataSource()
        loadData()
    }

    func configureHierarchy() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .secondarySystemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(view)
            make.bottom.equalTo(view)
        }
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

// MARK: - UITableViewDelegate

extension SpecificationsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return }
        switch identifier {
        case .thirdParty(let item):
            if let url = URL(string: item.urlString) {
                openSF(with: url)
            }
        default:
            break
        }
    }
}

// MARK: - DataSource

extension SpecificationsViewController {
    func configureDataSource() {
        dataSource = DataSource(tableView: tableView) { [weak self] (tableView, indexPath, item) -> UITableViewCell? in
            guard let self = self else { return nil }
            guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return nil }
            switch identifier {
            case .summary(let item):
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                var content = UIListContentConfiguration.valueCell()
                content.text = item.type.localizedLabel
                content.textProperties.color = .label
                content.secondaryText = item.value
                cell.contentConfiguration = content
                cell.accessoryType = .none
                return cell
            case .thirdParty(let item):
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                var content = UIListContentConfiguration.valueCell()
                content.text = item.name
                content.textProperties.color = .label
                content.secondaryText = item.version
                cell.contentConfiguration = content
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        }
    }

    func loadData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        snapshot.appendSections([.summary])
        snapshot.appendItems(configuration.summaryItems.map { Item.summary($0) })

        if !configuration.thirdPartyLibraries.isEmpty {
            snapshot.appendSections([.thirdParty])
            snapshot.appendItems(configuration.thirdPartyLibraries.map { Item.thirdParty($0) })
        }

        dataSource.apply(snapshot)
    }
}

// MARK: - Helpers

extension SpecificationsViewController {
    public static func getAppVersion() -> String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }

    public static func getAppName() -> String? {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = Bundle.main.localizedInfoDictionary?[key] as? String {
                return name
            }
            if let name = Bundle.main.infoDictionary?[key] as? String {
                return name
            }
        }
        return nil
    }
}

//
//  MoreViewController.swift
//  MoreKit
//

import UIKit
import SnapKit
import SafariServices
import StoreKit
import AppInfo

public class MoreViewController: UIViewController {

    private let configuration: MoreViewControllerConfiguration
    private let dataSource: MoreViewControllerDataSource?

    private var tableView: UITableView!
    private var diffableDataSource: DiffableDataSource!
    private var isAppOnStore: Bool = false

    // MARK: - Section / Item

    enum Section: Hashable {
        case membership
        case custom(String)
        case contact
        case appjun
        case about

        var header: String? {
            switch self {
            case .membership:
                return nil
            case .custom:
                return nil // set via sectionHeaders dict
            case .contact:
                return String(localized: "more.contact", bundle: .module)
            case .appjun:
                return String(localized: "more.appjun", bundle: .module)
            case .about:
                return String(localized: "more.about", bundle: .module)
            }
        }
    }

    enum Item: Hashable {
        case promotion(String)
        case thanks
        case custom(MoreCustomItem)
        case contact(ContactItemConfiguration)
        case appjunApp(AppInfo.App)
        case appjunMore
        case aboutSpecifications
        case aboutShare
        case aboutReview
        case aboutEULA
        case aboutPrivacyPolicy

        var title: String {
            switch self {
            case .promotion, .thanks:
                return ""
            case .custom(let item):
                return item.title
            case .contact(let item):
                return item.title
            case .appjunApp:
                return ""
            case .appjunMore:
                return String(localized: "more.appjun.explore", bundle: .module)
            case .aboutSpecifications:
                return String(localized: "more.about.specifications", bundle: .module)
            case .aboutShare:
                return String(localized: "more.about.share", bundle: .module)
            case .aboutReview:
                return String(localized: "more.about.review", bundle: .module)
            case .aboutEULA:
                return String(localized: "more.about.eula", bundle: .module)
            case .aboutPrivacyPolicy:
                return String(localized: "more.about.privacyPolicy", bundle: .module)
            }
        }
    }

    class DiffableDataSource: UITableViewDiffableDataSource<Section, Item> {
        var sectionHeaders: [Section: String?] = [:]
        var sectionFooters: [Section: String?] = [:]

        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            guard let sectionKind = sectionIdentifier(for: section) else { return nil }
            if let stored = sectionHeaders[sectionKind] {
                return stored
            }
            return sectionKind.header
        }

        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            guard let sectionKind = sectionIdentifier(for: section) else { return nil }
            if let stored = sectionFooters[sectionKind] {
                return stored
            }
            return nil
        }
    }

    // MARK: - Init

    public init(configuration: MoreViewControllerConfiguration, dataSource: MoreViewControllerDataSource? = nil) {
        self.configuration = configuration
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)

        title = configuration.title
        tabBarItem = UITabBarItem(title: configuration.title, image: configuration.tabBarImage, tag: 4)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = MoreKitAppearance.shared.backgroundColor
        navigationController?.navigationBar.tintColor = MoreKitAppearance.shared.tintColor

        configureHierarchy()
        configureDataSource()

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .SettingsUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .StoreInfoLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .StoreProductsLoaded, object: nil)

        for name in dataSource?.additionalReloadNotifications() ?? [] {
            NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: name, object: nil)
        }

        reloadData()

        if Store.shared.membershipDisplayPrice() == nil {
            Store.shared.retryRequestProducts()
        }

        checkAppStoreAvailability()
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Table View Setup

    func configureHierarchy() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = MoreKitAppearance.shared.backgroundColor
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        tableView.register(MoreCustomBadgeCell.self, forCellReuseIdentifier: MoreCustomBadgeCell.reuseIdentifier)
        tableView.register(AppCell.self, forCellReuseIdentifier: NSStringFromClass(AppCell.self))
        tableView.register(configuration.promotionCellClass, forCellReuseIdentifier: "PromotionCell")
        tableView.register(configuration.gratefulCellClass, forCellReuseIdentifier: "GratefulCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        tableView.contentInset = .zero
    }

    func configureDataSource() {
        diffableDataSource = DiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, item) -> UITableViewCell? in
            guard let self = self else { return nil }
            guard let identifier = diffableDataSource.itemIdentifier(for: indexPath) else { return nil }

            switch identifier {
            case .promotion(let price):
                let cell = tableView.dequeueReusableCell(withIdentifier: "PromotionCell", for: indexPath)
                if let promotionCell = cell as? PromotionCellConfigurable {
                    promotionCell.update(configuration: configuration.promotionConfig)
                    promotionCell.update(price: price)
                    promotionCell.purchaseClosure = { [weak self] in
                        self?.lifetimeAction()
                    }
                    promotionCell.restoreClosure = { [weak self] in
                        self?.restorePurchases()
                    }
                }
                return cell

            case .thanks:
                let cell = tableView.dequeueReusableCell(withIdentifier: "GratefulCell", for: indexPath)
                if let gratefulCell = cell as? GratefulCellConfigurable {
                    gratefulCell.update(configuration: configuration.gratefulConfig)
                }
                return cell

            case .custom(let item):
                if item.badge != nil {
                    let cell = tableView.dequeueReusableCell(withIdentifier: MoreCustomBadgeCell.reuseIdentifier, for: indexPath) as! MoreCustomBadgeCell
                    cell.configure(item: item)
                    return cell
                }
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                cell.accessoryType = .disclosureIndicator
                var content = UIListContentConfiguration.valueCell()
                content.text = item.title
                content.textProperties.color = .label
                content.secondaryText = item.value
                cell.contentConfiguration = content
                return cell

            case .contact(let item):
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                cell.accessoryType = .disclosureIndicator
                var content = UIListContentConfiguration.valueCell()
                content.text = item.title
                content.textProperties.color = .label
                content.secondaryText = item.value
                content.image = item.image
                content.imageProperties.tintColor = .label.withAlphaComponent(0.8)
                cell.contentConfiguration = content
                return cell

            case .appjunApp(let app):
                let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(AppCell.self), for: indexPath)
                if let cell = cell as? AppCell {
                    cell.update(app)
                }
                cell.accessoryType = .disclosureIndicator
                return cell

            case .appjunMore:
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                cell.accessoryType = .disclosureIndicator
                var content = UIListContentConfiguration.valueCell()
                content.text = identifier.title
                content.textProperties.color = .label
                cell.contentConfiguration = content
                return cell

            case .aboutSpecifications, .aboutShare, .aboutReview, .aboutEULA, .aboutPrivacyPolicy:
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                cell.accessoryType = .disclosureIndicator
                var content = UIListContentConfiguration.valueCell()
                content.text = identifier.title
                content.textProperties.color = .label
                cell.contentConfiguration = content
                return cell
            }
        }
    }

    // MARK: - Reload

    @objc
    public func reloadData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        var headers: [Section: String?] = [:]
        var footers: [Section: String?] = [:]

        let sectionTypes = dataSource?.sections(for: self) ?? [.membership, .contact, .appjun, .about]

        for sectionType in sectionTypes {
            switch sectionType {
            case .membership:
                guard MoreKit.productID != nil else { continue }
                snapshot.appendSections([.membership])
                switch User.shared.proTier() {
                case .lifetime:
                    snapshot.appendItems([.thanks], toSection: .membership)
                case .none:
                    snapshot.appendItems([.promotion(Store.shared.membershipDisplayPrice() ?? "?.??")], toSection: .membership)
                }

            case .custom(let section):
                guard !section.items.isEmpty else { continue }
                let sectionId = Section.custom(section.id)
                snapshot.appendSections([sectionId])
                headers[sectionId] = section.header
                footers[sectionId] = section.footer
                snapshot.appendItems(section.items.map { .custom($0) }, toSection: sectionId)

            case .contact:
                guard !configuration.contactItems.isEmpty else { continue }
                snapshot.appendSections([.contact])
                snapshot.appendItems(configuration.contactItems.map { .contact($0) }, toSection: .contact)

            case .appjun:
                var appItems: [Item] = []
                var apps = configuration.otherApps
                if Language.type() == .zh {
                    if !apps.contains(.festivals) {
                        apps.append(.festivals)
                    }
                }
                appItems.append(contentsOf: apps.randomElements(configuration.otherAppsDisplayCount).map { .appjunApp($0) })
                appItems.append(.appjunMore)
                guard !appItems.isEmpty else { continue }
                snapshot.appendSections([.appjun])
                snapshot.appendItems(appItems, toSection: .appjun)

            case .about:
                snapshot.appendSections([.about])
                var aboutItems: [Item] = [.aboutSpecifications]
                if isAppOnStore {
                    aboutItems.append(contentsOf: [.aboutShare, .aboutReview])
                }
                aboutItems.append(.aboutEULA)
                if configuration.privacyPolicyURL != nil {
                    aboutItems.append(.aboutPrivacyPolicy)
                }
                snapshot.appendItems(aboutItems, toSection: .about)
            }
        }

        diffableDataSource.sectionHeaders = headers
        diffableDataSource.sectionFooters = footers
        diffableDataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Public Methods (for DataSource to call)

    public func jumpToSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    public func enterSettings<T: SettingsOption>(_ type: T.Type) {
        let vc = SettingOptionsViewController<T>()
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: ConsideringUser.pushAnimated)
    }

    public func pushViewController(_ viewController: UIViewController, animated: Bool = true) {
        viewController.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(viewController, animated: animated ? ConsideringUser.pushAnimated : false)
    }
}

// MARK: - UITableViewDelegate

extension MoreViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .promotion, .thanks:
            break
        case .custom(let customItem):
            dataSource?.moreViewController(self, didSelectCustomItem: customItem)
        case .contact(let contactItem):
            handleContact(contactItem)
        case .appjunApp(let app):
            openStorePage(for: app)
        case .appjunMore:
            openStoreDeveloperPage()
        case .aboutSpecifications:
            enterSpecifications()
        case .aboutShare:
            shareApp()
        case .aboutReview:
            openAppStoreForReview()
        case .aboutEULA:
            openEULA()
        case .aboutPrivacyPolicy:
            openPrivacyPolicy()
        }
    }
}

// MARK: - Built-in Actions

extension MoreViewController {
    func lifetimeAction() {
        showOverlayViewController()
        Task {
            do {
                if let _ = try await Store.shared.purchaseLifetimeMembership() {
                    reloadData()
                }
            } catch {
                showAlert(title: String(localized: "store.orderFailure", bundle: .module), message: error.localizedDescription)
            }
            hideOverlayViewController()
        }
    }

    func restorePurchases() {
        Task {
            showOverlayViewController()
            do {
                try await Store.shared.sync()
            } catch {
                showAlert(title: String(localized: "store.orderFailure", bundle: .module), message: error.localizedDescription)
            }
            hideOverlayViewController()
        }
    }

    func handleContact(_ contact: ContactItemConfiguration) {
        switch contact.handler {
        case .email(let address):
            guard let urlString = "mailto:\(address)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: urlString) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
        case .url(let urlString):
            if let url = URL(string: urlString) {
                openSF(with: url)
            }
        }
    }

    func enterSpecifications() {
        let vc = SpecificationsViewController(configuration: configuration.specificationsConfig)
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: ConsideringUser.pushAnimated)
    }

    func shareApp() {
        if let url = URL(string: "https://apps.apple.com/app/id\(configuration.appStoreId)") {
            let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(controller, animated: ConsideringUser.animated)
        }
    }

    func openAppStoreForReview() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(configuration.appStoreId)?action=write-review") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    func openEULA() {
        if let url = URL(string: configuration.eulaURL) {
            openSF(with: url)
        }
    }

    func openPrivacyPolicy() {
        if let urlString = configuration.privacyPolicyURL, let url = URL(string: urlString) {
            openSF(with: url)
        }
    }

    func openStorePage(for app: App) {
        let storeVC = SKStoreProductViewController()
        storeVC.delegate = self
        let parameters = [SKStoreProductParameterITunesItemIdentifier: app.storeId]
        storeVC.loadProduct(withParameters: parameters) { [weak self] (loaded, error) in
            if loaded {
                self?.present(storeVC, animated: ConsideringUser.animated)
            } else if let _ = error {
                self?.jumpToAppStorePage(for: app)
            }
        }
    }

    func jumpToAppStorePage(for app: App) {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/" + app.storeId) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    func openStoreDeveloperPage() {
        guard let url = URL(string: AppInfo.Developer.pageURL) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    func checkAppStoreAvailability() {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(configuration.appStoreId)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let count = json["resultCount"] as? Int,
                  count > 0 else { return }
            DispatchQueue.main.async {
                self?.isAppOnStore = true
                self?.reloadData()
            }
        }.resume()
    }
}

// MARK: - SKStoreProductViewControllerDelegate

extension MoreViewController: SKStoreProductViewControllerDelegate {
    public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: ConsideringUser.animated)
    }
}

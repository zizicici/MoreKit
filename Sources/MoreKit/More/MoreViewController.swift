//
//  MoreViewController.swift
//  MoreKit
//

import UIKit
import SnapKit
import SafariServices
import StoreKit

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
        case showcase
        case about

        var header: String? {
            switch self {
            case .membership:
                return nil
            case .custom:
                return nil // set via sectionHeaders dict
            case .contact:
                return String(localized: "more.contact", bundle: .module)
            case .showcase:
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
        case showcaseApp(AppInfo.App)
        case showcaseMore
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
            case .showcaseApp:
                return ""
            case .showcaseMore:
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
        tableView.register(AppInfo.AppCell.self, forCellReuseIdentifier: NSStringFromClass(AppInfo.AppCell.self))
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
                if let promotionConfig = configuration.promotionConfig,
                   let promotionCell = cell as? PromotionCellConfigurable {
                    promotionCell.update(configuration: promotionConfig)
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
                if let gratefulConfig = configuration.gratefulConfig,
                   let gratefulCell = cell as? GratefulCellConfigurable {
                    gratefulCell.update(configuration: gratefulConfig)
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

            case .showcaseApp(let app):
                let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(AppInfo.AppCell.self), for: indexPath)
                if let cell = cell as? AppInfo.AppCell {
                    cell.update(app)
                }
                cell.accessoryType = .disclosureIndicator
                return cell

            case .showcaseMore:
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
                appendMembershipSection(to: &snapshot)

            case .custom(let section):
                appendCustomSection(section, to: &snapshot, headers: &headers, footers: &footers)

            case .contact:
                appendContactSection(to: &snapshot)

            case .appjun:
                appendShowcaseSection(to: &snapshot)

            case .about:
                appendAboutSection(to: &snapshot)
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

    func membershipItem(
        productID: String?,
        proTier: ProTier,
        membershipDisplayPrice: String?
    ) -> Item? {
        guard productID != nil else { return nil }

        switch proTier {
        case .lifetime:
            guard configuration.gratefulConfig != nil else { return nil }
            return .thanks
        case .none:
            guard configuration.promotionConfig != nil else { return nil }
            return .promotion(membershipDisplayPrice ?? "?.??")
        }
    }

    func appendMembershipSection(to snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>) {
        guard let membershipItem = membershipItem(
            productID: MoreKit.productID,
            proTier: User.shared.proTier(),
            membershipDisplayPrice: Store.shared.membershipDisplayPrice()
        ) else { return }
        snapshot.appendSections([.membership])
        snapshot.appendItems([membershipItem], toSection: .membership)
    }

    func appendCustomSection(
        _ section: MoreCustomSection,
        to snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>,
        headers: inout [Section: String?],
        footers: inout [Section: String?]
    ) {
        guard !section.items.isEmpty else { return }

        let sectionID = Section.custom(section.id)
        snapshot.appendSections([sectionID])
        headers[sectionID] = section.header
        footers[sectionID] = section.footer
        snapshot.appendItems(section.items.map { .custom($0) }, toSection: sectionID)
    }

    func appendContactSection(to snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>) {
        guard !configuration.contactItems.isEmpty else { return }

        snapshot.appendSections([.contact])
        snapshot.appendItems(configuration.contactItems.map { .contact($0) }, toSection: .contact)
    }

    func appendShowcaseSection(to snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>) {
        let showcase = configuration.appShowcase
        let language = Language.type()
        var items = showcase.displayedApps(for: language).map { Item.showcaseApp($0) }
        if showcase.showsDeveloperPageEntry {
            items.append(.showcaseMore)
        }
        guard !items.isEmpty else { return }

        snapshot.appendSections([.showcase])
        snapshot.appendItems(items, toSection: .showcase)
    }

    func appendAboutSection(to snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>) {
        snapshot.appendSections([.about])

        var items: [Item] = [.aboutSpecifications]
        if isAppOnStore {
            items.append(contentsOf: [.aboutShare, .aboutReview])
        }
        items.append(.aboutEULA)
        if configuration.privacyPolicyURL != nil {
            items.append(.aboutPrivacyPolicy)
        }

        snapshot.appendItems(items, toSection: .about)
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
            if handleBuiltInAction(for: customItem) {
                return
            }
        case .contact(let contactItem):
            handleContact(contactItem)
        case .showcaseApp(let app):
            openStorePage(for: app)
        case .showcaseMore:
            openShowcaseDeveloperPage()
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
    func handleBuiltInAction(for item: MoreCustomItem) -> Bool {
        switch item.builtInAction {
        case .openLanguageSettings:
            jumpToSettings()
            return true
        case .none:
            return false
        }
    }

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

    func openStorePage(for app: AppInfo.App) {
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

    func jumpToAppStorePage(for app: AppInfo.App) {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/" + app.storeId) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        }
    }

    func openShowcaseDeveloperPage() {
        guard let urlString = configuration.appShowcase.developerPageURL,
              let url = URL(string: urlString) else { return }
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

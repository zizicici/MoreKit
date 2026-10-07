//
//  SettingOptionsViewController.swift
//  MoreKit
//

#if canImport(UIKit)
import UIKit
import SnapKit

/// Adopt to show an optional badge beside individual settings options.
public protocol SettingsOptionBadgeProviding: SettingsOption {
    func getBadge() -> MoreBadgeStyle?
}

public class SettingOptionsViewController<T: SettingsOption>: UIViewController, UITableViewDelegate {
    /// Return true when the host has presented its own recovery UI.
    public var errorHandler: ((UIViewController, Error) -> Bool)?
    private var tableView: UITableView!
    private var dataSource: DataSource!

    enum Section: Hashable {
        case main

        var header: String? {
            return T.getHeader()
        }

        var footer: String? {
            return T.getFooter()
        }
    }

    enum Item: Hashable {
        case option(T, Bool)
    }

    class DataSource: UITableViewDiffableDataSource<Section, Item> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            let sectionKind = sectionIdentifier(for: section)
            return sectionKind?.header
        }

        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            let sectionKind = sectionIdentifier(for: section)
            return sectionKind?.footer
        }
    }

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.title = T.getTitle()

        view.backgroundColor = MoreKitAppearance.shared.backgroundColor
        navigationItem.largeTitleDisplayMode = .never

        configureHierarchy()
        configureDataSource()
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(observedDataChanged), name: .SettingsUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(observedDataChanged), name: .StoreInfoLoaded, object: nil)
    }

    func configureHierarchy() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = MoreKitAppearance.shared.backgroundColor
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
        tableView.register(MoreCustomBadgeCell.self, forCellReuseIdentifier: MoreCustomBadgeCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    func configureDataSource() {
        dataSource = DataSource(tableView: tableView) { [weak self] (tableView, indexPath, item) -> UITableViewCell? in
            guard let self = self else { return nil }
            guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return nil }
            switch identifier {
            case .option(let item, let isSelected):
                if let badge = (item as? any SettingsOptionBadgeProviding)?.getBadge(),
                   let cell = tableView.dequeueReusableCell(withIdentifier: MoreCustomBadgeCell.reuseIdentifier, for: indexPath) as? MoreCustomBadgeCell {
                    cell.configure(item: MoreCustomItem(id: "option", title: item.getName(), badge: badge))
                    cell.accessoryType = isSelected ? .checkmark : .none
                    cell.tintColor = MoreKitAppearance.shared.tintColor
                    cell.accessibilityLabel = "\(item.getName()), \(badge.text)"
                    return cell
                }
                let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
                cell.accessoryType = isSelected ? .checkmark : .none
                cell.tintColor = MoreKitAppearance.shared.tintColor
                var content = UIListContentConfiguration.valueCell()
                content.text = item.getName()
                content.textProperties.color = .label
                cell.contentConfiguration = content
                return cell
            }
        }
    }

    @objc nonisolated private func observedDataChanged() {
        Task { @MainActor [weak self] in self?.reloadData() }
    }

    @objc
    func reloadData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])

        let currentOption = T.current
        let options: [T] = T.getOptions()
        snapshot.appendItems(options.map{ Item.option($0, $0 == currentOption) })

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return }
        switch identifier {
        case .option(let item, _):
            do {
                try T.setCurrent(item)
            } catch {
                if errorHandler?(self, error) == true { return }
                showAlert(title: nil, message: error.localizedDescription)
                return
            }
        }

        self.reloadData()
    }
}
#endif

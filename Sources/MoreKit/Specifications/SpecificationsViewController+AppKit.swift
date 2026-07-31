#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@MainActor
public final class SpecificationsViewController: NSViewController {
    public let configuration: SpecificationsConfiguration

    public init(configuration: SpecificationsConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = NSView(
            frame: NSRect(x: 0, y: 0, width: 560, height: 450)
        )

        let titleLabel = NSTextField(
            labelWithString: configuration.title
                ?? String(
                    localized: "specifications.title",
                    defaultValue: "Specifications",
                    bundle: .module
                )
        )
        titleLabel.font = .systemFont(
            ofSize: NSFont.systemFontSize + 5,
            weight: .semibold
        )
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView(
            views: makeContentViews()
        )
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = NSButton(
            title: String(
                localized: "common.done",
                defaultValue: "Done",
                bundle: .module
            ),
            target: self,
            action: #selector(close(_:))
        )
        doneButton.keyEquivalent = "\r"
        doneButton.bezelStyle = .rounded
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(contentStack)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentStack.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: 22
            ),
            contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentStack.widthAnchor.constraint(equalToConstant: 440),
            doneButton.topAnchor.constraint(
                greaterThanOrEqualTo: contentStack.bottomAnchor,
                constant: 22
            ),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -20
            )
        ])
    }

    private func makeContentViews() -> [NSView] {
        var views: [NSView] = [makeSummaryGrid()]
        guard !configuration.thirdPartyLibraries.isEmpty else {
            return views
        }

        let header = NSTextField(
            labelWithString: String(
                localized: "specifications.thirdParty.header",
                defaultValue: "Acknowledgments",
                bundle: .module
            )
        )
        header.font = .systemFont(
            ofSize: NSFont.systemFontSize,
            weight: .semibold
        )
        views.append(header)
        views.append(makeLibraryGrid())
        return views
    }

    private func makeSummaryGrid() -> NSGridView {
        let rows = configuration.summaryItems.map { item in
            let label = NSTextField(
                labelWithString: item.type.localizedLabel
            )
            label.alignment = .right
            let value = NSTextField(labelWithString: item.value)
            value.textColor = .secondaryLabelColor
            value.alignment = .left
            return [label, value]
        }
        let grid = NSGridView(views: rows)
        grid.identifier = NSUserInterfaceItemIdentifier(
            "specifications.summaryGrid"
        )
        grid.rowSpacing = 10
        grid.columnSpacing = 18
        if !rows.isEmpty {
            grid.column(at: 0).xPlacement = .trailing
            grid.column(at: 1).xPlacement = .leading
        }
        grid.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return grid
    }

    private func makeLibraryGrid() -> NSGridView {
        let rows = configuration.thirdPartyLibraries.map { library in
            let button = SpecificationLinkButton(
                title: library.name,
                url: library.url
            )
            button.target = self
            button.action = #selector(openLibrary(_:))
            button.bezelStyle = .inline
            button.isBordered = false
            button.alignment = .left

            let version = NSTextField(labelWithString: library.version)
            version.textColor = .secondaryLabelColor
            version.alignment = .left
            return [button, version]
        }
        let grid = NSGridView(views: rows)
        grid.identifier = NSUserInterfaceItemIdentifier(
            "specifications.libraryGrid"
        )
        grid.rowSpacing = 10
        grid.columnSpacing = 18
        if !rows.isEmpty {
            grid.column(at: 0).xPlacement = .leading
            grid.column(at: 1).xPlacement = .leading
        }
        grid.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return grid
    }

    @objc private func openLibrary(_ sender: SpecificationLinkButton) {
        guard let url = sender.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func close(_ sender: Any?) {
        guard let window = view.window else { return }
        if let sheetParent = window.sheetParent {
            sheetParent.endSheet(window)
        } else {
            window.performClose(sender)
        }
    }

    public static func getAppVersion(bundle: Bundle = .main) -> String? {
        bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    public static func getAppName(bundle: Bundle = .main) -> String? {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = bundle.localizedInfoDictionary?[key] as? String {
                return name
            }
            if let name = bundle.infoDictionary?[key] as? String {
                return name
            }
        }
        return nil
    }
}

@MainActor
private final class SpecificationLinkButton: NSButton {
    let url: URL?

    init(title: String, url: URL?) {
        self.url = url
        super.init(frame: .zero)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif

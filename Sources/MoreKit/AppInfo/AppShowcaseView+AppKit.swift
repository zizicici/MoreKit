#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@MainActor
public final class AppShowcaseView: NSView {
    public let apps: [AppInfo.App]
    public let visibleIconCount: Int

    public private(set) var hoveredApp: AppInfo.App?

    public var isScrollingPaused: Bool {
        hoveredApp != nil
    }

    public var displayedDescription: String {
        descriptionLabel.stringValue
    }

    public override var intrinsicContentSize: NSSize {
        let iconCount = min(visibleIconCount, max(apps.count, 1))
        let width = CGFloat(iconCount) * Self.iconSize
            + CGFloat(max(iconCount - 1, 0)) * Self.iconSpacing
        return NSSize(width: width, height: Self.iconSize + 28)
    }

    private static let iconSize: CGFloat = 48
    private static let iconSpacing: CGFloat = 16
    private static let pointsPerSecond: CGFloat = 10

    private let iconClipView = NSView()
    private let iconStack = NSStackView()
    private let descriptionLabel = NSTextField(labelWithString: "")
    private var iconStackLeadingConstraint: NSLayoutConstraint!
    private var timer: Timer?
    private var scrollOffset: CGFloat = 0

    public init(
        apps: [AppInfo.App],
        visibleIconCount: Int = 5
    ) {
        self.apps = apps
        self.visibleIconCount = max(1, visibleIconCount)
        super.init(frame: .zero)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopScrolling()
        } else {
            startScrolling()
        }
    }

    func setHoveredApp(_ app: AppInfo.App?) {
        hoveredApp = app
        guard let app else {
            descriptionLabel.stringValue = ""
            return
        }
        descriptionLabel.stringValue = "\(app.name) · \(app.subtitle)"
    }

    private func configureView() {
        iconClipView.wantsLayer = true
        iconClipView.layer?.masksToBounds = true
        iconClipView.translatesAutoresizingMaskIntoConstraints = false

        iconStack.orientation = .horizontal
        iconStack.alignment = .centerY
        iconStack.spacing = Self.iconSpacing
        iconStack.translatesAutoresizingMaskIntoConstraints = false
        iconClipView.addSubview(iconStack)

        for app in apps + apps {
            iconStack.addArrangedSubview(makeIconButton(for: app))
        }

        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.font = .systemFont(
            ofSize: NSFont.smallSystemFontSize
        )
        descriptionLabel.alignment = .center
        descriptionLabel.lineBreakMode = .byTruncatingTail
        descriptionLabel.usesSingleLineMode = true
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconClipView)
        addSubview(descriptionLabel)

        iconStackLeadingConstraint = iconStack.leadingAnchor.constraint(
            equalTo: iconClipView.leadingAnchor
        )
        NSLayoutConstraint.activate([
            iconClipView.topAnchor.constraint(equalTo: topAnchor),
            iconClipView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconClipView.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconClipView.heightAnchor.constraint(equalToConstant: Self.iconSize),
            iconStackLeadingConstraint,
            iconStack.centerYAnchor.constraint(equalTo: iconClipView.centerYAnchor),
            descriptionLabel.topAnchor.constraint(
                equalTo: iconClipView.bottomAnchor,
                constant: 7
            ),
            descriptionLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 4
            ),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -4
            ),
            descriptionLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor
            )
        ])
    }

    private func makeIconButton(for app: AppInfo.App) -> AppShowcaseIconButton {
        let button = AppShowcaseIconButton(app: app)
        button.image = app.image
        button.imageScaling = .scaleProportionallyUpOrDown
        button.isBordered = false
        button.toolTip = app.name
        button.target = self
        button.action = #selector(openAppStore(_:))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        button.onHover = { [weak self, weak button] isInside in
            guard let self, let button else { return }
            if isInside {
                self.setHoveredApp(button.app)
            } else if self.hoveredApp == button.app {
                self.setHoveredApp(nil)
            }
        }
        return button
    }

    private func startScrolling() {
        guard timer == nil, apps.count > 1 else { return }
        var previousTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let currentTime = ProcessInfo.processInfo.systemUptime
                let elapsed = currentTime - previousTime
                previousTime = currentTime
                self.advanceScrolling(by: elapsed)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopScrolling() {
        timer?.invalidate()
        timer = nil
    }

    private func advanceScrolling(by elapsed: TimeInterval) {
        guard !isScrollingPaused else { return }
        let loopWidth = CGFloat(apps.count)
            * (Self.iconSize + Self.iconSpacing)
        guard loopWidth > 0 else { return }
        scrollOffset += Self.pointsPerSecond * elapsed
        if scrollOffset >= loopWidth {
            scrollOffset.formTruncatingRemainder(dividingBy: loopWidth)
        }
        iconStackLeadingConstraint.constant = -scrollOffset
    }

    @objc private func openAppStore(_ sender: AppShowcaseIconButton) {
        NSWorkspace.shared.open(sender.app.storeURL)
    }
}

@MainActor
private final class AppShowcaseIconButton: NSButton {
    let app: AppInfo.App
    var onHover: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    init(app: AppInfo.App) {
        self.app = app
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }
}
#endif

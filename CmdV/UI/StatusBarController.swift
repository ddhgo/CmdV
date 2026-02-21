import AppKit
import Carbon.HIToolbox
import Foundation
import ImageIO

private final class MenuActivationHeaderView: NSView {
    private static let preferredSize = NSSize(width: 244, height: 54)

    var onToggleChanged: ((Bool) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let activationToggle = NSSwitch()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize))
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        Self.preferredSize
    }

    func update(title: String, subtitle: String, isEnabled: Bool) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        subtitleLabel.textColor = .secondaryLabelColor
        activationToggle.state = isEnabled ? .on : .off
        needsLayout = true
        layoutSubtreeIfNeeded()
        displayIfNeeded()
    }

    private func setupUI() {
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        activationToggle.target = self
        activationToggle.action = #selector(handleToggleChanged)
        activationToggle.isEnabled = true
        activationToggle.controlSize = .small
        activationToggle.translatesAutoresizingMaskIntoConstraints = false
        activationToggle.setContentHuggingPriority(.required, for: .horizontal)
        activationToggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        let spacer = NSView(frame: .zero)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let rowStack = NSStackView(views: [textStack, spacer, activationToggle])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.distribution = .fill
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @objc private func handleToggleChanged() {
        onToggleChanged?(activationToggle.state == .on)
    }
}

final class StatusBarController: NSObject, NSMenuDelegate {
    var onTogglePopup: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onSetRecordingEnabled: ((Bool) -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: 36)
    private let menu = NSMenu()
    private var menuKeyMonitor: Any?
    private var menuGlobalKeyMonitor: Any?
    private var didHandleMenuHotkey = false
    private var isMenuOpen = false

    private var activationHeaderItem: NSMenuItem!
    private var openItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var quitItem: NSMenuItem!
    private lazy var activationHeaderView: MenuActivationHeaderView = {
        let view = MenuActivationHeaderView(frame: NSRect(origin: .zero, size: NSSize(width: 244, height: 54)))
        view.onToggleChanged = { [weak self] isEnabled in
            self?.handleRecordingToggleChange(isEnabled: isEnabled)
        }
        return view
    }()

    private var appLanguage: AppLanguage = .english
    private var hotkeyConfiguration: HotkeyConfiguration = .default
    private var isRecordingPaused = false
    private let menuBarIconSize = NSSize(width: 20, height: 20)
    private lazy var activeMenuBarIcon = makeColoredMenuBarIcon(color: NSColor(white: 1.0, alpha: 1.0))
    private lazy var pausedMenuBarIcon = makeColoredMenuBarIcon(color: NSColor(white: 0.62, alpha: 1.0))

    override init() {
        super.init()
        configureStatusItem()
        configureMenu()
    }

    func updateHotkey(_ hotkey: HotkeyConfiguration) {
        hotkeyConfiguration = hotkey
        applyLocalizedText()
    }

    func updateLanguage(_ language: AppLanguage) {
        appLanguage = language
        applyLocalizedText()
    }

    func updateRecordingPaused(_ paused: Bool) {
        isRecordingPaused = paused
        applyStatusIconAppearance()
        updateActivationHeader()
    }

    private func configureStatusItem() {
        statusItem.menu = menu

        if let button = statusItem.button {
            button.image = activeMenuBarIcon
            button.imageScaling = .scaleProportionallyUpOrDown
            button.imagePosition = .imageOnly
            button.toolTip = "CmdV"
            applyStatusIconAppearance()
        }
    }

    private func applyStatusIconAppearance() {
        guard let button = statusItem.button else {
            return
        }

        if isRecordingPaused {
            button.image = pausedMenuBarIcon
        } else {
            button.image = activeMenuBarIcon
        }

        button.contentTintColor = nil
        button.alphaValue = 1.0
    }

    private func makeColoredMenuBarIcon(color: NSColor) -> NSImage {
        guard let baseCGImage = loadBaseMenuBarCGImage() else {
            let fallback = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "CmdV"
            ) ?? NSImage(size: menuBarIconSize)
            fallback.size = menuBarIconSize
            fallback.isTemplate = false
            return fallback
        }

        let width = baseCGImage.width
        let height = baseCGImage.height
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            let fallback = NSImage(cgImage: baseCGImage, size: menuBarIconSize)
            fallback.isTemplate = false
            return fallback
        }

        context.interpolationQuality = .high
        // Preserve source alpha when tinting so dark logos don't turn transparent.
        context.draw(baseCGImage, in: rect)
        context.setBlendMode(.sourceIn)
        context.setFillColor(color.cgColor)
        context.fill(rect)

        guard let tintedCGImage = context.makeImage() else {
            let fallback = NSImage(cgImage: baseCGImage, size: menuBarIconSize)
            fallback.isTemplate = false
            return fallback
        }

        let result = NSImage(cgImage: tintedCGImage, size: menuBarIconSize)
        result.size = menuBarIconSize
        result.isTemplate = false
        return result
    }

    private func loadBaseMenuBarCGImage() -> CGImage? {
        if
            let url2x = Bundle.main.url(forResource: "CmdVMenuBarTemplate@2x", withExtension: "png"),
            let source2x = CGImageSourceCreateWithURL(url2x as CFURL, nil),
            let image2x = CGImageSourceCreateImageAtIndex(source2x, 0, nil)
        {
            return image2x
        }

        if
            let url = Bundle.main.url(forResource: "CmdVMenuBarTemplate", withExtension: "png"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            return image
        }

        if
            let image = NSImage(named: NSImage.Name("CmdVMenuBarTemplate")),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        {
            return cgImage
        }

        return nil
    }

    private func configureMenu() {
        menu.autoenablesItems = false
        menu.minimumWidth = 236
        menu.delegate = self

        activationHeaderItem = NSMenuItem()
        activationHeaderItem.view = activationHeaderView
        activationHeaderView.frame = NSRect(x: 0, y: 0, width: 244, height: 54)
        activationHeaderItem.isEnabled = true
        activationHeaderItem.isHidden = false
        activationHeaderItem.target = self
        activationHeaderItem.action = #selector(handleActivationHeaderClick)

        openItem = NSMenuItem(title: "", action: #selector(openHistory), keyEquivalent: "")
        openItem.target = self

        settingsItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        quitItem = NSMenuItem(title: "", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self

        menu.addItem(activationHeaderItem)
        menu.addItem(.separator())
        menu.addItem(openItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        applyLocalizedText()
    }

    private func applyLocalizedText() {
        openItem.title = AppText.value(.menuOpenClipboardHistory, language: appLanguage)
        openItem.keyEquivalent = keyEquivalent(for: hotkeyConfiguration.keyCode)
        openItem.keyEquivalentModifierMask = hotkeyConfiguration.modifiers
        settingsItem.title = AppText.value(.menuSettings, language: appLanguage)
        quitItem.title = AppText.value(.menuQuitCmdV, language: appLanguage)
        updateActivationHeader()
    }

    private func updateActivationHeader() {
        let subtitleKey: AppTextKey = isRecordingPaused
            ? .menuActivationStatusDisabled
            : .menuActivationStatusEnabled
        activationHeaderView.update(
            title: AppText.value(.menuActivationTitle, language: appLanguage),
            subtitle: AppText.value(subtitleKey, language: appLanguage),
            isEnabled: !isRecordingPaused
        )
    }

    private func handleRecordingToggleChange(isEnabled: Bool) {
        isRecordingPaused = !isEnabled
        applyStatusIconAppearance()
        updateActivationHeader()
        onSetRecordingEnabled?(isEnabled)
    }

    private func keyEquivalent(for keyCode: UInt32) -> String {
        let keyLabel = HotkeyCatalog.label(for: keyCode)

        if keyLabel == "Space" {
            return " "
        }

        if keyLabel.count == 1 {
            return keyLabel.lowercased()
        }

        return ""
    }

    @objc private func openHistory() {
        onTogglePopup?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        onQuit?()
    }

    @objc private func handleActivationHeaderClick() {}

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        didHandleMenuHotkey = false
        if activationHeaderItem.view == nil {
            activationHeaderItem.view = activationHeaderView
        }
        activationHeaderView.frame = NSRect(x: 0, y: 0, width: 244, height: 54)
        activationHeaderItem.isHidden = false
        activationHeaderItem.isEnabled = true
        activationHeaderItem.target = self
        activationHeaderItem.action = #selector(handleActivationHeaderClick)
        updateActivationHeader()
        installMenuHotkeyMonitor()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        didHandleMenuHotkey = false
        removeMenuHotkeyMonitor()
    }

    func dismissMenuIfOpen() {
        menu.cancelTracking()
    }

    func handleGlobalHotkeyWhileMenuOpen() -> Bool {
        guard isMenuOpen else {
            return false
        }

        triggerOpenHistoryFromMenuHotkey()
        return true
    }

    func menuHasKeyEquivalent(
        _ menu: NSMenu,
        for event: NSEvent,
        target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
        action: UnsafeMutablePointer<Selector?>
    ) -> Bool {
        guard matchesConfiguredHotkey(event) else {
            return false
        }

        triggerOpenHistoryFromMenuHotkey()
        return true
    }

    private func installMenuHotkeyMonitor() {
        removeMenuHotkeyMonitor()

        menuKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            if self.matchesConfiguredHotkey(event) {
                self.triggerOpenHistoryFromMenuHotkey()
                return nil
            }

            if Int(event.keyCode) == kVK_Escape {
                self.menu.cancelTracking()
                return nil
            }

            return event
        }

        menuGlobalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return
            }

            guard self.matchesConfiguredHotkey(event) else {
                return
            }

            self.triggerOpenHistoryFromMenuHotkey()
        }
    }

    private func triggerOpenHistoryFromMenuHotkey() {
        guard !didHandleMenuHotkey else {
            return
        }

        didHandleMenuHotkey = true
        menu.cancelTracking()
        DispatchQueue.main.async { [weak self] in
            self?.openHistory()
        }
    }

    private func removeMenuHotkeyMonitor() {
        if let menuKeyMonitor {
            NSEvent.removeMonitor(menuKeyMonitor)
            self.menuKeyMonitor = nil
        }

        if let menuGlobalKeyMonitor {
            NSEvent.removeMonitor(menuGlobalKeyMonitor)
            self.menuGlobalKeyMonitor = nil
        }
    }

    private func matchesConfiguredHotkey(_ event: NSEvent) -> Bool {
        let supportedFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let inputModifiers = event.modifierFlags.intersection(supportedFlags)
        return UInt32(event.keyCode) == hotkeyConfiguration.keyCode &&
            inputModifiers == hotkeyConfiguration.modifiers
    }
}

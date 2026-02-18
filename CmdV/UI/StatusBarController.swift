import AppKit
import Foundation

final class StatusBarController: NSObject {
    var onTogglePopup: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    private var openItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var quitItem: NSMenuItem!

    private var appLanguage: AppLanguage = .english
    private var hotkeyConfiguration: HotkeyConfiguration = .default
    private let menuBarIconSize = NSSize(width: 20, height: 20)

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

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = makeMenuBarIcon()
            button.imageScaling = .scaleProportionallyUpOrDown
            button.toolTip = "CmdV"
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func makeMenuBarIcon() -> NSImage {
        if let customIcon = NSImage(named: NSImage.Name("CmdVMenuBarTemplate")) {
            customIcon.isTemplate = true
            customIcon.size = menuBarIconSize
            return customIcon
        }

        if
            let url = Bundle.main.url(forResource: "CmdVMenuBarTemplate", withExtension: "png"),
            let customIcon = NSImage(contentsOf: url)
        {
            customIcon.isTemplate = true
            customIcon.size = menuBarIconSize
            return customIcon
        }

        let fallback = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "CmdV"
        ) ?? NSImage(size: menuBarIconSize)
        fallback.isTemplate = true
        fallback.size = menuBarIconSize
        return fallback
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        openItem = NSMenuItem(title: "", action: #selector(openHistory), keyEquivalent: "")
        openItem.target = self

        settingsItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        quitItem = NSMenuItem(title: "", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self

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

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        showMenu(anchor: sender)
    }

    private func showMenu(anchor button: NSStatusBarButton) {
        button.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 4), in: button)
        button.highlight(false)
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
}

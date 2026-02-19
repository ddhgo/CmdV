import AppKit
import Foundation
import ImageIO

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
    private var isRecordingPaused = false
    private let menuBarIconSize = NSSize(width: 20, height: 20)
    private lazy var activeMenuBarIcon = makeColoredMenuBarIcon(color: NSColor(white: 1.0, alpha: 1.0))
    private lazy var pausedMenuBarIcon = makeColoredMenuBarIcon(color: NSColor(white: 0.46, alpha: 1.0))

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
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = activeMenuBarIcon
            button.imageScaling = .scaleProportionallyUpOrDown
            button.imagePosition = .imageOnly
            button.toolTip = "CmdV"
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        context.clip(to: rect, mask: baseCGImage)
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

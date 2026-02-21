import AppKit
import SwiftUI

final class SettingsWindowController {
    private let settings: SettingsStore
    private let permissions: PermissionsService
    private let runtimeState: AppRuntimeState
    private let onClearHistory: () -> Void

    private var window: NSWindow?
    private var lastAppliedContentSize: CGSize?
    private let minimumWindowSize = CGSize(width: 320, height: 270)
    private let maximumWindowSize = CGSize(width: 620, height: 540)
    private let fixedWindowWidth = SettingsView.fixedWindowWidth

    init(
        settings: SettingsStore,
        permissions: PermissionsService,
        runtimeState: AppRuntimeState,
        onClearHistory: @escaping () -> Void
    ) {
        self.settings = settings
        self.permissions = permissions
        self.runtimeState = runtimeState
        self.onClearHistory = onClearHistory
    }

    func show() {
        if window == nil {
            createWindow()
        }

        settings.refreshLaunchAtLoginStatus()
        applyPreferredSize()
        window?.title = AppText.value(.settingsTitle, language: settings.appLanguage)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        clearInitialFieldFocus()
    }

    private func createWindow() {
        let rootView = SettingsView(
            settings: settings,
            permissions: permissions,
            runtimeState: runtimeState,
            onClearHistory: onClearHistory,
            onClose: { [weak self] in
                self?.window?.orderOut(nil)
            },
            onContentSizeChange: { [weak self] contentSize in
                self?.applyPreferredSize(for: contentSize)
            }
        )

        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = AppText.value(.settingsTitle, language: settings.appLanguage)
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable])
        window.backgroundColor = settingsWindowBackgroundColor
        window.isOpaque = true
        applyPreferredSize(for: CGSize(width: 360, height: 320), to: window)

        self.window = window
    }

    private func applyPreferredSize() {
        guard let window else {
            return
        }

        if let lastSize = lastAppliedContentSize {
            applyPreferredSize(for: lastSize, to: window)
            return
        }

        let fallbackSize = CGSize(width: 360, height: 320)
        applyPreferredSize(for: fallbackSize, to: window)
    }

    private func applyPreferredSize(for contentSize: CGSize) {
        guard let window else {
            return
        }

        applyPreferredSize(for: contentSize, to: window)
    }

    private func applyPreferredSize(for contentSize: CGSize, to window: NSWindow) {
        let wasVisible = window.isVisible
        let currentFrame = window.frame
        let targetWidth = max(
            minimumWindowSize.width,
            fixedWindowWidth
        )
        let targetHeight = min(
            maximumWindowSize.height,
            max(minimumWindowSize.height, contentSize.height)
        )
        let preferredSize = CGSize(width: targetWidth, height: targetHeight)

        if let lastAppliedContentSize,
           abs(lastAppliedContentSize.width - preferredSize.width) < 0.5,
           abs(lastAppliedContentSize.height - preferredSize.height) < 0.5 {
            return
        }

        lastAppliedContentSize = preferredSize

        window.setContentSize(preferredSize)
        window.minSize = CGSize(width: targetWidth, height: minimumWindowSize.height)
        window.maxSize = CGSize(width: targetWidth, height: maximumWindowSize.height)

        if !wasVisible {
            window.center()
            return
        }

        let centeredOrigin = NSPoint(
            x: currentFrame.midX - (targetWidth / 2),
            y: currentFrame.midY - (targetHeight / 2)
        )
        window.setFrameOrigin(centeredOrigin)
    }

    private func clearInitialFieldFocus() {
        guard let window else {
            return
        }

        DispatchQueue.main.async { [weak window] in
            _ = window?.makeFirstResponder(nil)
        }
    }

    private var settingsWindowBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(srgbRed: 0.22, green: 0.22, blue: 0.23, alpha: 1)
            }
            return NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
        }
    }
}

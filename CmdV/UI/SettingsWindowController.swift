import AppKit
import SwiftUI

final class SettingsWindowController {
    private let settings: SettingsStore
    private let permissions: PermissionsService
    private let runtimeState: AppRuntimeState
    private let onClearHistory: () -> Void

    private var window: NSWindow?

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
            }
        )

        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = AppText.value(.settingsTitle, language: settings.appLanguage)
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable])
        window.backgroundColor = settingsWindowBackgroundColor
        window.isOpaque = true
        applyPreferredSize(for: window)

        self.window = window
    }

    private func applyPreferredSize() {
        guard let window else {
            return
        }

        applyPreferredSize(for: window)
    }

    private func applyPreferredSize(for window: NSWindow) {
        let preferredSize = SettingsView.preferredWindowSize(for: settings.appLanguage)
        let wasVisible = window.isVisible
        let currentFrame = window.frame

        window.setContentSize(preferredSize)
        window.minSize = preferredSize
        window.maxSize = preferredSize

        if !wasVisible {
            window.center()
            return
        }

        let centeredOrigin = NSPoint(
            x: currentFrame.midX - (window.frame.width / 2),
            y: currentFrame.midY - (window.frame.height / 2)
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

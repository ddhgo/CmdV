import AppKit
import ApplicationServices
import Combine
import Darwin
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let lastSeenBootSessionKey = "runtime.lastSeenBootSession"

    private let settings = SettingsStore()
    private let permissions = PermissionsService()

    private var historyStore: HistoryStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var pasteService: PasteService?
    private var popupViewModel: PopupViewModel?
    private var popupPanelController: PopupPanelController?
    private var settingsWindowController: SettingsWindowController?
    private var statusBarController: StatusBarController?
    private let spotlightAliasIndexer = SpotlightAliasIndexer()
    private let hotkeyManager = HotkeyManager()

    private var previousActiveApplication: NSRunningApplication?
    private var previousFocusedElement: AXUIElement?
    private var previousFocusedWindow: AXUIElement?
    private var lastNonSelfActiveApplication: NSRunningApplication?
    private var workspaceActivationObserver: Any?
    private var cancellables: Set<AnyCancellable> = []
    private var hasRequestedAccessibilityPromptThisLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard enforceSingleInstance() else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        spotlightAliasIndexer.indexAppAliasKeywords()
        startTrackingLastActiveApplication()

        do {
            historyStore = try HistoryStore(settings: settings)
        } catch {
            presentFatalStartupError(error)
            NSApp.terminate(nil)
            return
        }

        guard let historyStore else {
            NSApp.terminate(nil)
            return
        }

        pasteService = PasteService(permissions: permissions)
        popupViewModel = PopupViewModel(historyStore: historyStore, settings: settings, permissions: permissions)

        if let popupViewModel {
            popupPanelController = PopupPanelController(viewModel: popupViewModel)
            popupPanelController?.onConfirm = { [weak self] item in
                self?.handleSelection(item)
            }
            popupPanelController?.onCopyOnly = { [weak self] item in
                self?.handleCopyOnly(item)
            }
            popupPanelController?.onClose = { [weak self] in
                self?.restorePreviousActiveApplication()
            }
        }

        settingsWindowController = SettingsWindowController(
            settings: settings,
            permissions: permissions,
            onClearHistory: { [weak self] in
                self?.historyStore?.clearHistory()
            }
        )

        statusBarController = StatusBarController()
        statusBarController?.onTogglePopup = { [weak self] in
            self?.togglePopup()
        }
        statusBarController?.onOpenSettings = { [weak self] in
            self?.settingsWindowController?.show()
        }
        statusBarController?.onSetRecordingEnabled = { [weak self] isEnabled in
            self?.settings.isRecordingPaused = !isEnabled
        }
        statusBarController?.onQuit = {
            NSApp.terminate(nil)
        }
        statusBarController?.updateLanguage(settings.appLanguage)
        statusBarController?.updateHotkey(settings.hotkey)
        statusBarController?.updateRecordingPaused(settings.isRecordingPaused)

        handleHistoryCleanupAfterSystemRestart()

        clipboardMonitor = ClipboardMonitor(historyStore: historyStore, settings: settings)
        clipboardMonitor?.start()

        historyStore.loadInitialHistory()
        permissions.refreshStatus()

        bindState()
        registerHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        hotkeyManager.unregister()
        stopTrackingLastActiveApplication()
    }

    private func bindState() {
        settings.$hotkey
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hotkey in
                guard let self else {
                    return
                }

                self.statusBarController?.updateHotkey(hotkey)
                self.registerHotkey()
            }
            .store(in: &cancellables)

        settings.$appLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] language in
                guard let self else {
                    return
                }

                self.statusBarController?.updateLanguage(language)
                self.statusBarController?.updateHotkey(self.settings.hotkey)
            }
            .store(in: &cancellables)

        settings.$isRecordingPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaused in
                self?.statusBarController?.updateRecordingPaused(isPaused)
            }
            .store(in: &cancellables)

        permissions.$accessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                guard granted else {
                    return
                }

                self?.hasRequestedAccessibilityPromptThisLaunch = false
            }
            .store(in: &cancellables)

    }

    private func registerHotkey() {
        let hotkey = settings.hotkey
        _ = hotkeyManager.register(hotkey: hotkey) { [weak self] in
            guard let self else {
                return
            }

            if self.statusBarController?.handleGlobalHotkeyWhileMenuOpen() == true {
                return
            }

            self.togglePopup()
        }
    }

    private func togglePopup() {
        guard let popupPanelController else {
            return
        }

        if popupPanelController.isVisible {
            popupPanelController.hide(triggerOnClose: false)
            restorePreviousActiveApplication()
            return
        }

        clipboardMonitor?.pollNow()
        historyStore?.loadInitialHistory()
        capturePreviousActiveApplication()
        popupPanelController.show()
    }

    private func handleSelection(_ item: ClipboardItem) {
        guard let pasteService else {
            restorePreviousActiveApplication()
            return
        }

        popupPanelController?.hide(triggerOnClose: false)

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            pasteService.paste(
                item: item,
                targetApplication: self.previousActiveApplication,
                targetFocusedElement: self.previousFocusedElement,
                targetFocusedWindow: self.previousFocusedWindow,
                completion: { [weak self] outcome in
                    if case .failedToCopy = outcome {
                        self?.restorePreviousActiveApplication()
                        NSSound.beep()
                    }

                    if case .failedToSendShortcut = outcome {
                        if
                            let self,
                            !self.permissions.accessibilityGrantedNow,
                            !self.hasRequestedAccessibilityPromptThisLaunch
                        {
                            self.hasRequestedAccessibilityPromptThisLaunch = true
                            self.permissions.requestAccessibilityPermission()
                        }

                        self?.popupViewModel?.showPermissionBannerIfNeeded()
                        NSSound.beep()
                    }

                    if case .copiedOnlyNeedsAccessibility = outcome {
                        if
                            let self,
                            !self.permissions.accessibilityGrantedNow,
                            !self.hasRequestedAccessibilityPromptThisLaunch
                        {
                            self.hasRequestedAccessibilityPromptThisLaunch = true
                            self.permissions.requestAccessibilityPermission()
                        }

                        self?.popupViewModel?.showPermissionBannerIfNeeded()
                        NSSound.beep()
                    }

                    self?.previousActiveApplication = nil
                    self?.previousFocusedElement = nil
                    self?.previousFocusedWindow = nil
                }
            )
        }
    }

    private func handleCopyOnly(_ item: ClipboardItem) {
        popupPanelController?.hide(triggerOnClose: false)

        guard let pasteService else {
            restorePreviousActiveApplication()
            return
        }

        if !pasteService.copyToPasteboard(item: item) {
            NSSound.beep()
        }

        restorePreviousActiveApplication()
        previousFocusedElement = nil
        previousFocusedWindow = nil
    }

    private func capturePreviousActiveApplication() {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let currentFrontmost = NSWorkspace.shared.frontmostApplication

        if let currentFrontmost,
           !currentFrontmost.isTerminated,
           currentFrontmost.processIdentifier != selfPID
        {
            previousActiveApplication = currentFrontmost
            lastNonSelfActiveApplication = currentFrontmost
            previousFocusedElement = focusedElement(for: currentFrontmost)
            previousFocusedWindow = focusedWindow(for: currentFrontmost)
            return
        }

        guard let lastNonSelfActiveApplication,
              !lastNonSelfActiveApplication.isTerminated
        else {
            previousActiveApplication = nil
            previousFocusedElement = nil
            previousFocusedWindow = nil
            return
        }

        previousActiveApplication = lastNonSelfActiveApplication
        previousFocusedElement = focusedElement(for: lastNonSelfActiveApplication)
        previousFocusedWindow = focusedWindow(for: lastNonSelfActiveApplication)
    }

    private func restorePreviousActiveApplication() {
        guard let previousActiveApplication else {
            previousFocusedElement = nil
            previousFocusedWindow = nil
            return
        }

        guard !previousActiveApplication.isTerminated else {
            self.previousActiveApplication = nil
            previousFocusedElement = nil
            previousFocusedWindow = nil
            return
        }

        previousActiveApplication.activate(options: [.activateIgnoringOtherApps])
        if let previousFocusedElement, permissions.accessibilityGrantedNow {
            _ = AXUIElementSetAttributeValue(
                previousFocusedElement,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            )
        }

        self.previousActiveApplication = nil
        self.previousFocusedElement = nil
        self.previousFocusedWindow = nil
    }

    private func handleHistoryCleanupAfterSystemRestart() {
        let currentBootSession = Self.currentBootSessionIdentifier()
        let defaults = UserDefaults.standard
        let previousBootSession = defaults.string(forKey: Self.lastSeenBootSessionKey)
        defaults.set(currentBootSession, forKey: Self.lastSeenBootSessionKey)

        guard settings.clearHistoryOnSystemRestart else {
            return
        }

        guard let previousBootSession, previousBootSession != currentBootSession else {
            return
        }

        historyStore?.clearHistory()
    }

    private static func currentBootSessionIdentifier() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        let result = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0)
        if result == 0 {
            return String(bootTime.tv_sec)
        }

        let estimatedBootTimestamp = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        return String(Int(estimatedBootTimestamp))
    }

    private func startTrackingLastActiveApplication() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        workspaceActivationObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let activatedApplication = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                !activatedApplication.isTerminated,
                activatedApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else {
                return
            }

            self.lastNonSelfActiveApplication = activatedApplication
        }

        if let currentFrontmost = NSWorkspace.shared.frontmostApplication,
           !currentFrontmost.isTerminated,
           currentFrontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            lastNonSelfActiveApplication = currentFrontmost
        }
    }

    private func focusedElement(for application: NSRunningApplication?) -> AXUIElement? {
        guard
            permissions.accessibilityGrantedNow,
            let application
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedElementRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard
            status == .success,
            let focusedElementRef
        else {
            return nil
        }

        return axUIElement(from: focusedElementRef)
    }

    private func focusedWindow(for application: NSRunningApplication?) -> AXUIElement? {
        guard
            permissions.accessibilityGrantedNow,
            let application
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedWindowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        guard
            status == .success,
            let focusedWindowRef
        else {
            return nil
        }

        return axUIElement(from: focusedWindowRef)
    }

    /// Safely converts a `CFTypeRef` to `AXUIElement` after verifying its
    /// Core Foundation type ID matches `AXUIElementGetTypeID()`.
    private func axUIElement(from value: CFTypeRef?) -> AXUIElement? {
        guard
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        // CFTypeRef → AXUIElement is a toll-free-bridgeable cast guarded by
        // the type-ID check above.  `unsafeBitCast` is the canonical Swift
        // pattern for this conversion because AXUIElement is an opaque
        // Core Foundation type with no Swift overlay.
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func stopTrackingLastActiveApplication() {
        guard let workspaceActivationObserver else {
            return
        }

        NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        self.workspaceActivationObserver = nil
    }

    private func presentFatalStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "CmdV failed to start"
        alert.informativeText = "\(error.localizedDescription)"
        alert.addButton(withTitle: "Quit")
        alert.runModal()
    }

    private func enforceSingleInstance() -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return true
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        if let existing = otherInstances.first {
            existing.activate(options: [.activateIgnoringOtherApps])
            return false
        }

        return true
    }
}

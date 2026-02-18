import AppKit
import ApplicationServices
import Foundation

final class PermissionsService: NSObject, ObservableObject, AccessibilityPermissionChecking {
    @Published private(set) var accessibilityGranted: Bool
    private var refreshTimer: Timer?
    private var refreshAttemptsRemaining = 0

    var accessibilityGrantedNow: Bool {
        Self.isAccessibilityTrusted(prompt: false)
    }

    override init() {
        accessibilityGranted = Self.isAccessibilityTrusted(prompt: false)
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        stopRefreshPolling()
        NotificationCenter.default.removeObserver(self)
    }

    func refreshStatus() {
        let isTrusted = accessibilityGrantedNow
        DispatchQueue.main.async { [weak self] in
            self?.accessibilityGranted = isTrusted
        }
    }

    func requestAccessibilityPermission() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let isTrusted = Self.isAccessibilityTrusted(prompt: true)
            if !isTrusted {
                self.openAccessibilitySettings()
            }
        }

        startRefreshPolling()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        return AXIsProcessTrusted()
    }

    @objc
    private func handleApplicationDidBecomeActive() {
        refreshStatus()
    }

    private func startRefreshPolling() {
        stopRefreshPolling()
        refreshAttemptsRemaining = 20

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }

                self.refreshStatus()
                self.refreshAttemptsRemaining -= 1

                if self.accessibilityGrantedNow || self.refreshAttemptsRemaining <= 0 {
                    self.stopRefreshPolling()
                }
            }
        }
    }

    private func stopRefreshPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

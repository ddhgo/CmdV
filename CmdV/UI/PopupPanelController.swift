import AppKit
import Carbon.HIToolbox
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PopupPanelController: NSObject, NSWindowDelegate {
    var onConfirm: ((ClipboardItem) -> Void)?
    var onCopyOnly: ((ClipboardItem) -> Void)?
    var onClose: (() -> Void)?

    private let panel: NSPanel
    private let viewModel: PopupViewModel
    private var keyMonitor: Any?
    private var permissionMonitorTimer: Timer?

    var isVisible: Bool {
        panel.isVisible
    }

    init(viewModel: PopupViewModel) {
        self.viewModel = viewModel

        panel = FloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PopupLayout.defaultWidth,
                height: PopupLayout.defaultHeight
            ),
            styleMask: [.titled, .closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()
        configurePanel()
    }

    func show() {
        positionPanel()
        viewModel.refreshPermissions()
        viewModel.showPermissionBannerIfNeeded()
        viewModel.resetSearch()
        viewModel.selectFirstIfNeeded()
        viewModel.requestSearchFocus()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        startPermissionMonitor()
    }

    func hide(triggerOnClose: Bool) {
        guard panel.isVisible else {
            return
        }

        removeKeyMonitor()
        stopPermissionMonitor()
        panel.orderOut(nil)

        if triggerOnClose {
            onClose?()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        hide(triggerOnClose: true)
    }

    private func configurePanel() {
        panel.delegate = self
        panel.title = "CmdV"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = popupPanelBackgroundColor
        panel.isOpaque = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.minSize = NSSize(width: PopupLayout.minimumWidth, height: PopupLayout.minimumHeight)

        if let closeButton = panel.standardWindowButton(.closeButton) {
            closeButton.isEnabled = true
            closeButton.target = self
            closeButton.action = #selector(handleTitlebarClose)
        }
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true

        let rootView = PopupContentView(
            viewModel: viewModel,
            onConfirm: { [weak self] item in
                self?.onConfirm?(item)
            },
            onCopyOnly: { [weak self] item in
                self?.onCopyOnly?(item)
            }
        )
        panel.contentView = NSHostingView(rootView: rootView)
    }

    @objc private func handleTitlebarClose() {
        hide(triggerOnClose: true)
    }

    private func positionPanel() {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
        }) ?? NSScreen.main

        guard let targetScreen else {
            return
        }

        let visibleFrame = targetScreen.visibleFrame
        let panelSize = panel.frame.size

        let originX = visibleFrame.midX - panelSize.width / 2
        let originY = max(visibleFrame.minY + 16, visibleFrame.maxY - panelSize.height - 26)

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func installKeyMonitor() {
        removeKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            guard self.panel.isVisible else {
                return event
            }

            if self.handle(event: event) {
                return nil
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func startPermissionMonitor() {
        stopPermissionMonitor()

        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.viewModel.refreshPermissions()
        }

        permissionMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPermissionMonitor() {
        permissionMonitorTimer?.invalidate()
        permissionMonitorTimer = nil
    }

    private func handle(event: NSEvent) -> Bool {
        let normalizedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if normalizedModifiers.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "f"
        {
            viewModel.requestSearchFocus()
            return true
        }

        if normalizedModifiers.contains(.command),
           (Int(event.keyCode) == kVK_Return || Int(event.keyCode) == kVK_ANSI_KeypadEnter)
        {
            if let item = viewModel.selectedItem {
                onCopyOnly?(item)
            }
            return true
        }

        if normalizedModifiers.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "p"
        {
            viewModel.togglePinnedSelected()
            return true
        }

        switch Int(event.keyCode) {
        case kVK_Escape:
            hide(triggerOnClose: true)
            return true

        case kVK_UpArrow:
            viewModel.selectPrevious()
            return true

        case kVK_DownArrow:
            viewModel.selectNext()
            return true

        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let item = viewModel.selectedItem {
                onConfirm?(item)
            }
            return true

        case kVK_Delete, kVK_ForwardDelete:
            if shouldLetTextInputHandleDelete() {
                return false
            }
            viewModel.deleteSelected()
            return true

        default:
            return false
        }
    }

    private func shouldLetTextInputHandleDelete() -> Bool {
        guard let textView = panel.firstResponder as? NSTextView else {
            return false
        }

        return textView.isEditable
    }

    private var popupPanelBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(srgbRed: 0.22, green: 0.22, blue: 0.23, alpha: 1)
            }
            return NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
        }
    }
}

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PasteOutcome {
    case pasted
    case copiedOnlyNeedsAccessibility
    case failedToCopy
    case failedToSendShortcut
}

protocol AccessibilityPermissionChecking {
    var accessibilityGrantedNow: Bool { get }
}

final class PasteService {
    private let permissions: AccessibilityPermissionChecking
    private let sendCommandVShortcutHandler: () -> Bool
    private let frontmostApplicationProvider: () -> NSRunningApplication?
    private let applicationActivator: (NSRunningApplication) -> Void
    private let mainAsyncAfter: (TimeInterval, @escaping () -> Void) -> Void
    private let refocusHandler: (AXUIElement?, AXUIElement?) -> Void
    private static let imagePreparationQueue = DispatchQueue(
        label: "CmdV.PasteService.ImagePreparation",
        qos: .userInitiated
    )

    private struct PreparedImagePayload {
        let pngData: Data
        let tiffData: Data?
    }

    init(
        permissions: AccessibilityPermissionChecking,
        sendCommandVShortcutHandler: @escaping () -> Bool = PasteService.sendCommandVShortcut,
        frontmostApplicationProvider: @escaping () -> NSRunningApplication? = {
            NSWorkspace.shared.frontmostApplication
        },
        applicationActivator: @escaping (NSRunningApplication) -> Void = {
            $0.activate(options: [.activateIgnoringOtherApps])
        },
        mainAsyncAfter: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        },
        refocusHandler: @escaping (AXUIElement?, AXUIElement?) -> Void = PasteService.refocusIfPossible
    ) {
        self.permissions = permissions
        self.sendCommandVShortcutHandler = sendCommandVShortcutHandler
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.applicationActivator = applicationActivator
        self.mainAsyncAfter = mainAsyncAfter
        self.refocusHandler = refocusHandler
    }

    func paste(
        item: ClipboardItem,
        targetApplication: NSRunningApplication?,
        targetFocusedElement: AXUIElement?,
        targetFocusedWindow: AXUIElement?,
        completion: @escaping (PasteOutcome) -> Void
    ) {
        if item.type == .image {
            copyImageToPasteboardAsync(item: item) { [self] didCopy in
                guard didCopy else {
                    completion(.failedToCopy)
                    return
                }

                continuePasteFlow(
                    targetApplication: targetApplication,
                    targetFocusedElement: targetFocusedElement,
                    targetFocusedWindow: targetFocusedWindow,
                    completion: completion
                )
            }
            return
        }

        guard copyToPasteboard(item: item) else {
            completion(.failedToCopy)
            return
        }

        continuePasteFlow(
            targetApplication: targetApplication,
            targetFocusedElement: targetFocusedElement,
            targetFocusedWindow: targetFocusedWindow,
            completion: completion
        )
    }

    private func continuePasteFlow(
        targetApplication: NSRunningApplication?,
        targetFocusedElement: AXUIElement?,
        targetFocusedWindow: AXUIElement?,
        completion: @escaping (PasteOutcome) -> Void
    ) {
        guard permissions.accessibilityGrantedNow else {
            completion(.copiedOnlyNeedsAccessibility)
            return
        }

        if let targetApplication {
            applicationActivator(targetApplication)
        }

        if let targetApplication {
            sendPasteWhenTargetIsFrontmost(
                targetApplication,
                targetFocusedElement: targetFocusedElement,
                targetFocusedWindow: targetFocusedWindow,
                retriesRemaining: 14,
                completion: completion
            )
            return
        }

        mainAsyncAfter(0.08) { [self] in
            let didSend = sendCommandVShortcutHandler()
            completion(didSend ? .pasted : .failedToSendShortcut)
        }
    }

    @discardableResult
    func copyToPasteboard(item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general

        switch item.type {
        case .text:
            pasteboard.clearContents()
            guard let text = item.textContent else {
                return false
            }
            return pasteboard.setString(text, forType: .string)

        case .image:
            guard
                let imagePath = item.imagePath,
                let payload = Self.prepareImagePayload(fromImagePath: imagePath)
            else {
                pasteboard.clearContents()
                return false
            }

            pasteboard.clearContents()
            return writeImagePayloadToPasteboard(payload, to: pasteboard)
        }
    }

    private func copyImageToPasteboardAsync(
        item: ClipboardItem,
        completion: @escaping (Bool) -> Void
    ) {
        guard let imagePath = item.imagePath else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            completion(false)
            return
        }

        Self.imagePreparationQueue.async {
            let payload = Self.prepareImagePayload(fromImagePath: imagePath)

            DispatchQueue.main.async { [self] in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()

                guard let payload else {
                    completion(false)
                    return
                }

                completion(writeImagePayloadToPasteboard(payload, to: pasteboard))
            }
        }
    }

    private func writeImagePayloadToPasteboard(
        _ payload: PreparedImagePayload,
        to pasteboard: NSPasteboard
    ) -> Bool {
        let setPNG = pasteboard.setData(payload.pngData, forType: .png)

        if let tiffData = payload.tiffData {
            _ = pasteboard.setData(tiffData, forType: .tiff)
        }

        return setPNG
    }

    private static func prepareImagePayload(fromImagePath imagePath: String) -> PreparedImagePayload? {
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) else {
            return nil
        }

        return PreparedImagePayload(
            pngData: imageData,
            tiffData: makeTIFFData(from: imageData)
        )
    }

    private static func makeTIFFData(from imageData: Data) -> Data? {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let tiffData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                tiffData,
                UTType.tiff.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return tiffData as Data
    }

    private static func sendCommandVShortcut() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
            )
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    private func sendPasteWhenTargetIsFrontmost(
        _ targetApplication: NSRunningApplication,
        targetFocusedElement: AXUIElement?,
        targetFocusedWindow: AXUIElement?,
        retriesRemaining: Int,
        completion: @escaping (PasteOutcome) -> Void
    ) {
        guard !targetApplication.isTerminated else {
            completion(.failedToSendShortcut)
            return
        }

        if isFrontmost(targetApplication) {
            refocusHandler(targetFocusedElement, targetFocusedWindow)

            mainAsyncAfter(0.09) { [self] in
                let didSend = sendCommandVShortcutHandler()
                completion(didSend ? .pasted : .failedToSendShortcut)
            }
            return
        }

        guard retriesRemaining > 0 else {
            applicationActivator(targetApplication)

            mainAsyncAfter(0.12) { [self] in
                refocusHandler(targetFocusedElement, targetFocusedWindow)
                let didSend = sendCommandVShortcutHandler()
                completion(didSend ? .pasted : .failedToSendShortcut)
            }
            return
        }

        applicationActivator(targetApplication)

        mainAsyncAfter(0.06) { [self] in
            self.sendPasteWhenTargetIsFrontmost(
                targetApplication,
                targetFocusedElement: targetFocusedElement,
                targetFocusedWindow: targetFocusedWindow,
                retriesRemaining: retriesRemaining - 1,
                completion: completion
            )
        }
    }

    private static func refocusIfPossible(
        _ focusedElement: AXUIElement?,
        targetFocusedWindow: AXUIElement?
    ) {
        guard focusedElement != nil || targetFocusedWindow != nil else {
            return
        }

        var pid: pid_t = 0
        if let focusedElement {
            AXUIElementGetPid(focusedElement, &pid)
        } else if let targetFocusedWindow {
            AXUIElementGetPid(targetFocusedWindow, &pid)
        }

        if pid > 0 {
            let appElement = AXUIElementCreateApplication(pid)
            if let targetFocusedWindow {
                _ = AXUIElementSetAttributeValue(
                    appElement,
                    kAXFocusedWindowAttribute as CFString,
                    targetFocusedWindow
                )
            }

            if let focusedElement {
                _ = AXUIElementSetAttributeValue(
                    appElement,
                    kAXFocusedUIElementAttribute as CFString,
                    focusedElement
                )
            }
        }

        if let focusedElement {
            _ = AXUIElementSetAttributeValue(
                focusedElement,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            )
        }
    }

    private func isFrontmost(_ application: NSRunningApplication) -> Bool {
        guard let frontmostApplication = frontmostApplicationProvider() else {
            return false
        }

        if frontmostApplication.processIdentifier == application.processIdentifier {
            return true
        }

        if let frontmostBundleID = frontmostApplication.bundleIdentifier,
           let targetBundleID = application.bundleIdentifier,
           frontmostBundleID == targetBundleID
        {
            return true
        }

        return false
    }
}

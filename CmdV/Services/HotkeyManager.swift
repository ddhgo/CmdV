import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var handler: (() -> Void)?
    private var registeredHotkey: HotkeyConfiguration?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    deinit {
        unregister()
    }

    @discardableResult
    func register(hotkey: HotkeyConfiguration, handler: @escaping () -> Void) -> Bool {
        self.handler = handler
        self.registeredHotkey = hotkey
        unregister()

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
        )

        let userInfo = UnsafeMutableRawPointer(
            Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let manager = Unmanaged<HotkeyManager>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()

                return manager.handleEvent(type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault, tap, 0
        )

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func unregister() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        registeredHotkey = nil
    }

    private func handleEvent(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, let hotkey = registeredHotkey else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let relevantFlags: CGEventFlags = [
            .maskCommand, .maskAlternate, .maskControl, .maskShift
        ]
        let activeFlags = flags.intersection(relevantFlags)

        var expectedFlags = CGEventFlags()
        if hotkey.modifiers.contains(.command) {
            expectedFlags.insert(.maskCommand)
        }
        if hotkey.modifiers.contains(.option) {
            expectedFlags.insert(.maskAlternate)
        }
        if hotkey.modifiers.contains(.control) {
            expectedFlags.insert(.maskControl)
        }
        if hotkey.modifiers.contains(.shift) {
            expectedFlags.insert(.maskShift)
        }

        if keyCode == hotkey.keyCode && activeFlags == expectedFlags {
            DispatchQueue.main.async { [weak self] in
                self?.handler?()
            }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}

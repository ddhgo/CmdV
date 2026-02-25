import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    private let hotkeySignature: OSType
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    init(signature: String = "CCVH") {
        let characters = Array(signature.utf8)
        if characters.count == 4 {
            hotkeySignature = (UInt32(characters[0]) << 24)
                | (UInt32(characters[1]) << 16)
                | (UInt32(characters[2]) << 8)
                | UInt32(characters[3])
        } else {
            hotkeySignature = (UInt32(0x43) << 24) | (UInt32(0x43) << 16) | (UInt32(0x56) << 8) | UInt32(0x48)
        }
        installEventHandler()
    }

    private static let eventHandler: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef else {
            return noErr
        }

        guard let userData else {
            return noErr
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        if hotKeyID.signature != manager.hotkeySignature {
            return OSStatus(eventNotHandledErr)
        }

        DispatchQueue.main.async {
            manager.handler?()
        }

        return noErr
    }

    deinit {
        unregister()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(hotkey: HotkeyConfiguration, handler: @escaping () -> Void) -> Bool {
        self.handler = handler
        unregister()

        let hotKeyID = EventHotKeyID(signature: hotkeySignature, id: 1)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers.carbonFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.eventHandler,
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }
}

import AppKit
import Carbon.HIToolbox

struct HotkeyOption: Identifiable, Hashable {
    let keyCode: UInt32
    let label: String

    var id: UInt32 { keyCode }
}

enum HotkeyCatalog {
    static let options: [HotkeyOption] = [
        HotkeyOption(keyCode: UInt32(kVK_ANSI_A), label: "A"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_B), label: "B"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_C), label: "C"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_D), label: "D"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_E), label: "E"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_F), label: "F"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_G), label: "G"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_H), label: "H"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_I), label: "I"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_J), label: "J"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_K), label: "K"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_L), label: "L"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_M), label: "M"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_N), label: "N"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_O), label: "O"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_P), label: "P"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_Q), label: "Q"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_R), label: "R"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_S), label: "S"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_T), label: "T"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_U), label: "U"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_V), label: "V"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_W), label: "W"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_X), label: "X"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_Y), label: "Y"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_Z), label: "Z"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_0), label: "0"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_1), label: "1"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_2), label: "2"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_3), label: "3"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_4), label: "4"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_5), label: "5"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_6), label: "6"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_7), label: "7"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_8), label: "8"),
        HotkeyOption(keyCode: UInt32(kVK_ANSI_9), label: "9"),
        HotkeyOption(keyCode: UInt32(kVK_Space), label: "Space")
    ]

    static func label(for keyCode: UInt32) -> String {
        options.first(where: { $0.keyCode == keyCode })?.label ?? "KeyCode \(keyCode)"
    }
}

struct HotkeyConfiguration: Equatable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags

    static let `default` = HotkeyConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: [.option]
    )

    var displayString: String {
        localizedDisplayString(language: .english)
    }

    func localizedDisplayString(language: AppLanguage) -> String {
        var parts: [String] = []

        if modifiers.contains(.command) {
            parts.append(modifierLabel(for: .command, language: language))
        }
        if modifiers.contains(.option) {
            parts.append(modifierLabel(for: .option, language: language))
        }
        if modifiers.contains(.control) {
            parts.append(modifierLabel(for: .control, language: language))
        }
        if modifiers.contains(.shift) {
            parts.append(modifierLabel(for: .shift, language: language))
        }

        parts.append(HotkeyCatalog.label(for: keyCode))
        return parts.joined(separator: "+")
    }

    private func modifierLabel(for modifier: NSEvent.ModifierFlags, language: AppLanguage) -> String {
        switch modifier {
        case .command:
            return language == .korean ? "Command" : "Cmd"
        case .option:
            return "Option"
        case .control:
            return "Control"
        case .shift:
            return "Shift"
        default:
            return ""
        }
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0

        if contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if contains(.option) {
            flags |= UInt32(optionKey)
        }
        if contains(.control) {
            flags |= UInt32(controlKey)
        }
        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        return flags
    }
}

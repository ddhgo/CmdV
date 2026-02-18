import AppKit
import Carbon.HIToolbox
import XCTest
@testable import CmdV

final class HotkeyConfigurationTests: XCTestCase {
    func testLocalizedDisplayStringEnglishUsesExpectedOrder() {
        let configuration = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: [.command, .option, .control, .shift]
        )

        XCTAssertEqual(
            configuration.localizedDisplayString(language: .english),
            "Cmd+Option+Control+Shift+V"
        )
    }

    func testLocalizedDisplayStringKoreanUsesCommandLabel() {
        let configuration = HotkeyConfiguration(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: [.command, .option, .control, .shift]
        )

        XCTAssertEqual(
            configuration.localizedDisplayString(language: .korean),
            "Command+Option+Control+Shift+V"
        )
    }

    func testCarbonFlagsReflectEnabledModifiers() {
        let flags = NSEvent.ModifierFlags([.command, .option, .control]).carbonFlags

        XCTAssertNotEqual(flags & UInt32(cmdKey), 0)
        XCTAssertNotEqual(flags & UInt32(optionKey), 0)
        XCTAssertNotEqual(flags & UInt32(controlKey), 0)
        XCTAssertEqual(flags & UInt32(shiftKey), 0)
    }
}

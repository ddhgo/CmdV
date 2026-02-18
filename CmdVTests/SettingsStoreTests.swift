import AppKit
import XCTest
@testable import CmdV

final class SettingsStoreTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()

        defaultsSuiteName = "CmdVTests.SettingsStore.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil

        super.tearDown()
    }

    func testExcludedBundleIDsParsingSupportsCommaAndNewline() {
        let settings = SettingsStore(defaults: defaults)
        settings.excludedBundleIDsText = "com.apple.KeychainAccess,com.1password.1password\ncom.agilebits.onepassword7"

        XCTAssertTrue(settings.excludedBundleIDs.contains("com.apple.KeychainAccess"))
        XCTAssertTrue(settings.excludedBundleIDs.contains("com.1password.1password"))
        XCTAssertTrue(settings.excludedBundleIDs.contains("com.agilebits.onepassword7"))
        XCTAssertEqual(settings.excludedBundleIDs.count, 3)
    }

    func testHotkeyAlwaysHasAtLeastOneModifier() {
        let settings = SettingsStore(defaults: defaults)

        settings.hotkey = HotkeyConfiguration(
            keyCode: settings.hotkey.keyCode,
            modifiers: []
        )

        XCTAssertTrue(settings.hotkey.modifiers.contains(.option))
    }

    func testMaxHistoryItemsGetsClamped() {
        let settings = SettingsStore(defaults: defaults)

        settings.maxHistoryItems = 5
        XCTAssertEqual(settings.maxHistoryItems, 20)

        settings.maxHistoryItems = 20_000
        XCTAssertEqual(settings.maxHistoryItems, 1000)
    }

    func testPollingIntervalGetsClamped() {
        let settings = SettingsStore(defaults: defaults)

        settings.pollingInterval = 0.01
        XCTAssertEqual(settings.pollingInterval, 0.2, accuracy: 0.0001)

        settings.pollingInterval = 99
        XCTAssertEqual(settings.pollingInterval, 2.0, accuracy: 0.0001)
    }

    func testAppLanguagePersistsAcrossStoreReload() {
        let settings = SettingsStore(defaults: defaults)
        settings.appLanguage = .korean

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.appLanguage, .korean)
    }

    func testAppLanguageFallsBackToEnglishForUnknownValue() {
        defaults.set("xx", forKey: "settings.appLanguage")

        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.appLanguage, .english)
    }

    func testClearHistoryOnSystemRestartPersistsAcrossStoreReload() {
        let settings = SettingsStore(defaults: defaults)
        settings.clearHistoryOnSystemRestart = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.clearHistoryOnSystemRestart)
    }

    func testLaunchAtLoginPreferencePersistsAcrossStoreReload() {
        let settings = SettingsStore(defaults: defaults)
        settings.launchAtLoginEnabled = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.launchAtLoginEnabled)
    }
}

import Foundation
import XCTest
@testable import CmdV

final class HistoryStoreIntegrationTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var temporaryDirectory: URL!
    private var settings: SettingsStore!
    private var historyStore: HistoryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()

        defaultsSuiteName = "CmdVTests.HistoryStore.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CmdVTests-HistoryStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        settings = SettingsStore(defaults: defaults)
        historyStore = try HistoryStore(settings: settings, appSupportDirectory: temporaryDirectory)
        historyStore.clearHistory()
        waitUntil("history is empty") {
            self.historyStore.items.isEmpty
        }
    }

    override func tearDownWithError() throws {
        historyStore = nil
        settings = nil

        if let defaultsSuiteName, let defaults {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }

        defaults = nil
        defaultsSuiteName = nil

        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil

        try super.tearDownWithError()
    }

    func testSuppressesNearDuplicateTextFromSameSource() {
        historyStore.addTextIfNeeded("Hello  CmdV", sourceBundleID: "com.test.app")
        historyStore.addTextIfNeeded("Hello CmdV", sourceBundleID: "com.test.app")

        waitUntil("single deduplicated item") {
            self.historyStore.items.count == 1
        }

        XCTAssertEqual(historyStore.items.first?.textContent, "Hello  CmdV")
    }

    func testTrimKeepsPinnedItemsWhenCapacityIsSmall() {
        historyStore.addTextIfNeeded("Pinned Item", sourceBundleID: nil)
        waitUntil("first item inserted") {
            self.historyStore.items.count == 1
        }

        guard let pinnedID = historyStore.items.first?.id else {
            XCTFail("Expected an inserted item")
            return
        }

        historyStore.setPinned(itemID: pinnedID, isPinned: true)
        waitUntil("item pinned") {
            self.historyStore.items.first?.isPinned == true
        }

        historyStore.addTextIfNeeded("Newest Item", sourceBundleID: nil)
        historyStore.trimToCapacity(limit: 1)
        historyStore.loadInitialHistory()
        waitUntil("pinned + newest are both present") {
            self.historyStore.items.count == 2
        }

        let texts = Set(historyStore.items.compactMap(\.textContent))
        XCTAssertEqual(texts, Set(["Pinned Item", "Newest Item"]))
        XCTAssertTrue(historyStore.items.contains(where: { $0.id == pinnedID && $0.isPinned }))
    }

    func testTrimsOverflowForUnpinnedItems() {
        historyStore.addTextIfNeeded("A", sourceBundleID: nil)
        historyStore.addTextIfNeeded("B", sourceBundleID: nil)
        historyStore.addTextIfNeeded("C", sourceBundleID: nil)
        historyStore.trimToCapacity(limit: 2)

        waitUntil("capacity trim applied") {
            self.historyStore.items.count == 2
        }

        let texts = historyStore.items.compactMap(\.textContent)
        XCTAssertFalse(texts.contains("A"))
        XCTAssertEqual(Set(texts), Set(["B", "C"]))
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }

            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        XCTFail("Timed out waiting for \(description)")
    }
}

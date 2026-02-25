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

    func testTrimKeepsFavoritedItemsWhenCapacityIsSmall() {
        historyStore.addTextIfNeeded("Favorite Item", sourceBundleID: nil)
        waitUntil("favorite candidate inserted") {
            self.historyStore.items.count == 1
        }

        guard let favoriteID = historyStore.items.first?.id else {
            XCTFail("Expected an inserted item")
            return
        }

        historyStore.setFavorited(itemID: favoriteID, isFavorited: true)
        waitUntil("item favorited") {
            self.historyStore.items.first?.isFavorited == true
        }

        historyStore.addTextIfNeeded("Newest Item", sourceBundleID: nil)
        historyStore.trimToCapacity(limit: 1)
        historyStore.loadInitialHistory()
        waitUntil("favorite + newest are both present") {
            self.historyStore.items.count == 2
        }

        let texts = Set(historyStore.items.compactMap(\.textContent))
        XCTAssertEqual(texts, Set(["Favorite Item", "Newest Item"]))
        XCTAssertTrue(historyStore.items.contains(where: { $0.id == favoriteID && $0.isFavorited }))
    }

    func testClearHistoryKeepsFavoritedItems() {
        historyStore.addTextIfNeeded("Favorite Item", sourceBundleID: nil)
        historyStore.addTextIfNeeded("Nonfavorite Item", sourceBundleID: nil)
        waitUntil("items inserted") {
            self.historyStore.items.count == 2
        }

        guard let favoriteID = self.historyStore.items.last(where: { $0.textContent == "Favorite Item" })?.id else {
            XCTFail("Expected favorite candidate")
            return
        }

        historyStore.setFavorited(itemID: favoriteID, isFavorited: true)
        waitUntil("favorite set") {
            self.historyStore.items.contains(where: { $0.id == favoriteID && $0.isFavorited })
        }

        historyStore.clearHistory()
        waitUntil("history cleared except favorite") {
            self.historyStore.items.count == 1
        }

        XCTAssertEqual(self.historyStore.items.first?.id, favoriteID)
        XCTAssertEqual(self.historyStore.items.first?.textContent, "Favorite Item")
        XCTAssertTrue(self.historyStore.items.first?.isFavorited == true)
    }

    func testRecopyingThirdFileEntryMovesToTopAndDoesNotDuplicate() {
        let firstURL = makeTemporaryTextFile(name: "first.txt", content: "first")
        let secondURL = makeTemporaryTextFile(name: "second.txt", content: "second")
        let thirdURL = makeTemporaryTextFile(name: "third.txt", content: "third")

        historyStore.addFileURLsIfNeeded([firstURL], sourceBundleID: nil)
        historyStore.addFileURLsIfNeeded([secondURL], sourceBundleID: nil)
        historyStore.addFileURLsIfNeeded([thirdURL], sourceBundleID: nil)

        waitUntil("three file items inserted") {
            self.historyStore.items.count == 3
        }

        guard let thirdItemID = historyStore.items.first(where: { $0.type == .file })?.id else {
            XCTFail("Expected a file item in history")
            return
        }

        historyStore.addFileURLsIfNeeded([thirdURL], sourceBundleID: nil)

        waitUntil("recopied file moved to top without duplicate") {
            self.historyStore.items.count == 3 &&
            self.historyStore.items.first?.id == thirdItemID
        }
    }

    func testRecopyingPinnedItemKeepsPinnedState() {
        historyStore.addTextIfNeeded("Pinned Item", sourceBundleID: nil)
        historyStore.addTextIfNeeded("Newest One", sourceBundleID: nil)
        historyStore.addTextIfNeeded("Newest Two", sourceBundleID: nil)

        waitUntil("three text items inserted") {
            self.historyStore.items.count == 3
        }

        guard let pinnedItemID = self.historyStore.items.last(where: { $0.textContent == "Pinned Item" })?.id else {
            XCTFail("Expected pinned item")
            return
        }

        historyStore.setPinned(itemID: pinnedItemID, isPinned: true)
        waitUntil("pinned state applied") {
            self.historyStore.items.contains(where: { $0.id == pinnedItemID && $0.isPinned })
        }

        historyStore.addTextIfNeeded("Pinned Item", sourceBundleID: nil)

        waitUntil("pinned item moved to top and stays pinned") {
            self.historyStore.items.count == 3 &&
            self.historyStore.items.first?.id == pinnedItemID &&
            self.historyStore.items.first?.isPinned == true
        }
    }

    func testRecopyingTextMovesExistingEntryToTop() {
        historyStore.addTextIfNeeded("First", sourceBundleID: nil)
        historyStore.addTextIfNeeded("Second", sourceBundleID: nil)
        historyStore.addTextIfNeeded("Third", sourceBundleID: nil)

        waitUntil("three text items inserted") {
            self.historyStore.items.count == 3
        }

        guard let firstID = self.historyStore.items.last(where: { $0.textContent == "First" })?.id else {
            XCTFail("Expected first item")
            return
        }

        historyStore.addTextIfNeeded("First", sourceBundleID: nil)

        waitUntil("first text item moved to top without duplicate") {
            self.historyStore.items.count == 3 &&
            self.historyStore.items.first?.id == firstID
        }
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

    private func makeTemporaryTextFile(name: String, content: String) -> URL {
        let fileURL = temporaryDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: fileURL.path, contents: content.data(using: .utf8))
        return fileURL
    }
}

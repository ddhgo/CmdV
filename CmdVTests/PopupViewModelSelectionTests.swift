import Foundation
import XCTest
@testable import CmdV

final class PopupViewModelSelectionTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var temporaryDirectory: URL!
    private var settings: SettingsStore!
    private var historyStore: HistoryStore!
    private var permissions: PermissionsService!
    private var viewModel: PopupViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()

        defaultsSuiteName = "CmdVTests.PopupViewModel.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CmdVTests-PopupViewModel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        settings = SettingsStore(defaults: defaults)
        historyStore = try HistoryStore(settings: settings, appSupportDirectory: temporaryDirectory)
        permissions = PermissionsService()

        historyStore.clearHistory()
        waitUntil("history is empty") {
            self.historyStore.items.isEmpty
        }

        viewModel = PopupViewModel(
            historyStore: historyStore,
            settings: settings,
            permissions: permissions
        )
        historyStore.loadInitialHistory()
        waitUntil("history view model is ready") {
            self.viewModel.allItems.isEmpty
        }
    }

    override func tearDownWithError() throws {
        historyStore = nil
        settings = nil
        permissions = nil
        viewModel = nil

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

    func testDeleteMiddleItemKeepsAdjacentSelection() {
        historyStore.addTextIfNeeded("first", sourceBundleID: nil)
        historyStore.addTextIfNeeded("second", sourceBundleID: nil)
        historyStore.addTextIfNeeded("third", sourceBundleID: nil)

        waitUntil("3 history items inserted") {
            self.historyStore.items.count == 3
        }

        viewModel.searchQuery = ""

        let itemsBeforeDelete = viewModel.filteredItems
        guard itemsBeforeDelete.count == 3 else {
            XCTFail("Expected three items before delete")
            return
        }

        let deletedItem = itemsBeforeDelete[1]
        let expectedSelection = itemsBeforeDelete[2].id
        viewModel.selectedItemID = deletedItem.id
        viewModel.delete(itemID: deletedItem.id)

        waitUntil("selection moves to next row and stays out of top jump") {
            self.historyStore.items.count == 2 &&
            self.viewModel.selectedItemID == expectedSelection
        }
    }

    func testDeleteLastItemKeepsPreviousSelection() {
        historyStore.addTextIfNeeded("first", sourceBundleID: nil)
        historyStore.addTextIfNeeded("second", sourceBundleID: nil)
        historyStore.addTextIfNeeded("third", sourceBundleID: nil)

        waitUntil("3 history items inserted") {
            self.historyStore.items.count == 3
        }

        let itemsBeforeDelete = viewModel.filteredItems
        guard itemsBeforeDelete.count == 3 else {
            XCTFail("Expected three items before delete")
            return
        }

        let deletedItem = itemsBeforeDelete.last!
        let expectedSelection = itemsBeforeDelete[itemsBeforeDelete.count - 2].id
        viewModel.selectedItemID = deletedItem.id
        viewModel.delete(itemID: deletedItem.id)

        waitUntil("selection moves to previous row and stays out of top jump") {
            self.historyStore.items.count == 2 &&
            self.viewModel.selectedItemID == expectedSelection
        }
    }

    func testHistoryTabExcludesFavoritedItems() {
        historyStore.addTextIfNeeded("favorite", sourceBundleID: nil)
        historyStore.addTextIfNeeded("normal", sourceBundleID: nil)
        waitUntil("items inserted") {
            self.historyStore.items.count == 2
        }

        guard let favoriteID = self.historyStore.items.last(where: { $0.textContent == "favorite" })?.id else {
            XCTFail("Expected favorite candidate")
            return
        }

        historyStore.setFavorited(itemID: favoriteID, isFavorited: true)
        waitUntil("favorite updated") {
            self.historyStore.items.contains(where: { $0.id == favoriteID && $0.isFavorited })
        }

        XCTAssertEqual(self.viewModel.filteredItems.count, 1)
        XCTAssertTrue(self.viewModel.filteredItems.allSatisfy { !$0.isFavorited })
    }

    func testClearCurrentTabInFavoritesClearsFavoritesOnly() {
        historyStore.addTextIfNeeded("favorite", sourceBundleID: nil)
        historyStore.addTextIfNeeded("normal", sourceBundleID: nil)
        waitUntil("items inserted") {
            self.historyStore.items.count == 2
        }

        guard let favoriteID = self.historyStore.items.last(where: { $0.textContent == "favorite" })?.id else {
            XCTFail("Expected favorite candidate")
            return
        }

        historyStore.setFavorited(itemID: favoriteID, isFavorited: true)
        waitUntil("favorite updated") {
            self.historyStore.items.contains(where: { $0.id == favoriteID && $0.isFavorited })
        }

        viewModel.activeTab = .favorites
        viewModel.clearCurrentTab()

        waitUntil("favorites cleared") {
            self.historyStore.items.count == 1 &&
            self.historyStore.items.first?.textContent == "normal"
        }

        XCTAssertFalse(self.historyStore.items.contains(where: { $0.id == favoriteID && $0.isFavorited }))
    }

    func testActiveTabSwitchSwitchesVisibleHistoryScope() {
        historyStore.addTextIfNeeded("favorite", sourceBundleID: nil)
        historyStore.addTextIfNeeded("normal", sourceBundleID: nil)
        waitUntil("items inserted") {
            self.historyStore.items.count == 2
        }

        guard let favoriteID = self.historyStore.items.last(where: { $0.textContent == "favorite" })?.id else {
            XCTFail("Expected favorite candidate")
            return
        }

        historyStore.setFavorited(itemID: favoriteID, isFavorited: true)
        waitUntil("favorite updated") {
            self.historyStore.items.count == 2 &&
            self.historyStore.items.contains(where: { $0.id == favoriteID && $0.isFavorited })
        }

        viewModel.activeTab = .favorites
        waitUntil("favorites tab filters to favorited") {
            self.viewModel.filteredItems.count == 1 &&
            self.viewModel.filteredItems.first?.id == favoriteID
        }

        viewModel.activeTab = .history
        waitUntil("history tab filters non-favorited") {
            self.viewModel.filteredItems.count == 1 &&
            self.viewModel.filteredItems.first?.textContent == "normal"
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
}

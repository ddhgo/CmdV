import Foundation
import XCTest
@testable import CmdV

final class SQLiteHistoryDatabaseTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let baseTemp = FileManager.default.temporaryDirectory
        temporaryDirectory = baseTemp.appendingPathComponent("CmdVTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        databaseURL = temporaryDirectory.appendingPathComponent("history.sqlite3", isDirectory: false)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil
        databaseURL = nil

        try super.tearDownWithError()
    }

    func testInsertAndFetchMostRecentFirst() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        _ = database.insertText(
            text: "first",
            hash: "hash-text-1",
            createdAt: baseDate,
            sourceBundleID: "com.example.a"
        )

        _ = database.insertImage(
            imagePath: "/tmp/hash-image-1.png",
            hash: "hash-image-1",
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: "com.example.b"
        )

        let items = database.fetchRecentItems(limit: 10)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].type, .image)
        XCTAssertEqual(items[0].imagePath, "/tmp/hash-image-1.png")
        XCTAssertEqual(items[1].type, .text)
        XCTAssertEqual(items[1].textContent, "first")
        XCTAssertEqual(database.latestHash(), "hash-image-1")
    }

    func testInsertAndFetchVeryLongText() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let longText = String(repeating: "x", count: 600_000)

        _ = database.insertText(
            text: longText,
            hash: "hash-long-text",
            createdAt: Date(),
            sourceBundleID: nil
        )

        let items = database.fetchRecentItems(limit: 10)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.textContent?.count, longText.count)
        XCTAssertEqual(items.first?.textContent, longText)
    }

    func testDatabaseFileUsesOwnerOnlyPermissions() throws {
        _ = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let attributes = try FileManager.default.attributesOfItem(atPath: databaseURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions, 0o600)
    }

    func testTrimToCapacityRemovesOldRowsAndReturnsImagePaths() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_100)

        _ = database.insertText(
            text: "keep-this",
            hash: "hash-keep",
            createdAt: baseDate.addingTimeInterval(30),
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/old-image-a.png",
            hash: "hash-old-a",
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/old-image-b.png",
            hash: "hash-old-b",
            createdAt: baseDate,
            sourceBundleID: nil
        )

        let removedPaths = Set(database.trimToCapacity(1))
        let items = database.fetchRecentItems(limit: 10)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].textContent, "keep-this")
        XCTAssertEqual(removedPaths, Set(["/tmp/old-image-a.png", "/tmp/old-image-b.png"]))
    }

    func testClearAllReturnsAllImagePaths() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let now = Date()

        _ = database.insertText(
            text: "hello",
            hash: "hash-hello",
            createdAt: now,
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/image-1.png",
            hash: "hash-image-1",
            createdAt: now.addingTimeInterval(1),
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/image-2.png",
            hash: "hash-image-2",
            createdAt: now.addingTimeInterval(2),
            sourceBundleID: nil
        )

        let removedPaths = Set(database.clearAll())
        let items = database.fetchRecentItems(limit: 10)

        XCTAssertEqual(items.count, 0)
        XCTAssertEqual(removedPaths, Set(["/tmp/image-1.png", "/tmp/image-2.png"]))
    }

    func testPinnedItemsAppearFirstAfterUpdate() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_200)

        let firstID = database.insertText(
            text: "first",
            hash: "hash-first",
            createdAt: baseDate,
            sourceBundleID: nil
        )

        _ = database.insertText(
            text: "second",
            hash: "hash-second",
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )

        database.setPinned(itemID: firstID, isPinned: true)

        let items = database.fetchRecentItems(limit: 10)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].textContent, "first")
        XCTAssertTrue(items[0].isPinned)
        XCTAssertFalse(items[1].isPinned)
    }

    func testTrimCapacityKeepsPinnedItems() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_300)

        let pinnedImageID = database.insertImage(
            imagePath: "/tmp/pinned-image.png",
            hash: "hash-pinned",
            createdAt: baseDate,
            sourceBundleID: nil
        )

        _ = database.insertText(
            text: "recent-unpinned",
            hash: "hash-recent-unpinned",
            createdAt: baseDate.addingTimeInterval(20),
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/old-unpinned-image.png",
            hash: "hash-old-unpinned-image",
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )

        database.setPinned(itemID: pinnedImageID, isPinned: true)

        let removedPaths = Set(database.trimToCapacity(1))
        let items = database.fetchRecentItems(limit: 10)

        XCTAssertEqual(removedPaths, Set(["/tmp/old-unpinned-image.png"]))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].imagePath, "/tmp/pinned-image.png")
        XCTAssertTrue(items[0].isPinned)
        XCTAssertEqual(items[1].textContent, "recent-unpinned")
    }

    func testTrimCapacityKeepsFavoritedItems() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_400)

        let favoritedID = database.insertText(
            text: "favorite-item",
            hash: "hash-favorite",
            createdAt: baseDate,
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/recent-image.png",
            hash: "hash-recent-image",
            createdAt: baseDate.addingTimeInterval(20),
            sourceBundleID: nil
        )

        _ = database.insertImage(
            imagePath: "/tmp/old-image.png",
            hash: "hash-old-image",
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )

        database.setFavorited(itemID: favoritedID, isFavorited: true)

        let removedPaths = Set(database.trimToCapacity(1))
        let items = database.fetchRecentItems(limit: 10)

        XCTAssertEqual(removedPaths, Set(["/tmp/old-image.png"]))
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(where: { $0.id == favoritedID && $0.isFavorited }))
    }

    func testFindMostRecentItemIDReturnsLatestMatchForSameType() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_500)
        let sharedHash = "hash-duplicate"

        _ = database.insertText(
            text: "old",
            hash: sharedHash,
            createdAt: baseDate,
            sourceBundleID: nil
        )
        let secondID = database.insertText(
            text: "new",
            hash: sharedHash,
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )

        _ = database.insertText(
            text: "other",
            hash: "hash-other",
            createdAt: baseDate.addingTimeInterval(20),
            sourceBundleID: nil
        )

        XCTAssertEqual(database.findMostRecentItemID(type: .text, contentHash: sharedHash), secondID)
        XCTAssertNotEqual(database.findMostRecentItemID(type: .image, contentHash: sharedHash), secondID)
    }

    func testBumpItemToTopReordersByUpdatedTimestamp() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_600)

        let firstID = database.insertText(
            text: "first",
            hash: "hash-first",
            createdAt: baseDate,
            sourceBundleID: nil
        )
        let secondID = database.insertText(
            text: "second",
            hash: "hash-second",
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )

        let bumpedAt = baseDate.addingTimeInterval(20)
        database.bumpItemToTop(itemID: firstID, createdAt: bumpedAt, sourceBundleID: "com.example.bumped")

        let items = database.fetchRecentItems(limit: 2)
        guard let firstItem = items.first else {
            XCTFail("Expected first item after bump")
            return
        }

        XCTAssertEqual(firstItem.id, firstID)
        XCTAssertEqual(firstItem.createdAt.timeIntervalSince1970, bumpedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(firstItem.sourceBundleID, "com.example.bumped")
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[1].id, secondID)
    }

    func testDeduplicatesSameTypeAndHashKeepingLatestAndPinnedState() throws {
        let database = try SQLiteHistoryDatabase(databaseURL: databaseURL)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_700)
        let sharedHash = "hash-duplicate"

        _ = database.insertText(
            text: "first",
            hash: sharedHash,
            createdAt: baseDate,
            sourceBundleID: nil
        )
        let secondID = database.insertText(
            text: "second",
            hash: sharedHash,
            createdAt: baseDate.addingTimeInterval(10),
            sourceBundleID: nil
        )
        let thirdID = database.insertText(
            text: "third",
            hash: sharedHash,
            createdAt: baseDate.addingTimeInterval(20),
            sourceBundleID: nil
        )

        _ = database.insertText(
            text: "first",
            hash: "hash-other",
            createdAt: baseDate.addingTimeInterval(30),
            sourceBundleID: nil
        )

        database.setPinned(itemID: secondID, isPinned: true)
        database.setFavorited(itemID: secondID, isFavorited: true)

        database.removeDuplicateItemsByTypeAndContentHash()

        let deduped = database.fetchRecentItems(limit: 10)
        let duplicateTypeRows = deduped.filter { $0.type == .text && $0.contentHash == sharedHash }

        XCTAssertEqual(duplicateTypeRows.count, 1)
        guard let keptItem = duplicateTypeRows.first else {
            XCTFail("Expected one deduplicated text row to remain")
            return
        }

        XCTAssertEqual(keptItem.id, thirdID)
        XCTAssertTrue(keptItem.isPinned)
        XCTAssertTrue(keptItem.isFavorited)
    }
}

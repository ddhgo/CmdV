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
}

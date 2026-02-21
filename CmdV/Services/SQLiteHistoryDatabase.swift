import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteHistoryDatabaseError: Error {
    case openFailed(String)
    case migrationFailed(String)
    case permissionFailed(String)
}

final class SQLiteHistoryDatabase {
    private var db: OpaquePointer?

    init(databaseURL: URL) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(databaseURL.path, &db, flags, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw SQLiteHistoryDatabaseError.openFailed(message)
        }

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databaseURL.path)
        } catch {
            throw SQLiteHistoryDatabaseError.permissionFailed(error.localizedDescription)
        }

        do {
            try execute("PRAGMA journal_mode=WAL;")
            try execute("PRAGMA synchronous=FULL;")
            try execute(
                """
                CREATE TABLE IF NOT EXISTS history_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    type TEXT NOT NULL,
                    text_content TEXT,
                    image_path TEXT,
                    content_hash TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    source_bundle_id TEXT,
                    is_pinned INTEGER NOT NULL DEFAULT 0,
                    is_favorited INTEGER NOT NULL DEFAULT 0
                );
                """
            )

            if !hasColumn(named: "is_pinned", in: "history_items") {
                try execute("ALTER TABLE history_items ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;")
            }
            if !hasColumn(named: "is_favorited", in: "history_items") {
                try execute("ALTER TABLE history_items ADD COLUMN is_favorited INTEGER NOT NULL DEFAULT 0;")
            }

            try execute(
                "CREATE INDEX IF NOT EXISTS idx_history_items_created_at ON history_items (created_at DESC, id DESC);"
            )
        } catch {
            throw SQLiteHistoryDatabaseError.migrationFailed(error.localizedDescription)
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func fetchRecentItems(limit: Int) -> [ClipboardItem] {
        guard let statement = prepare(
            """
            SELECT id, type, text_content, image_path, content_hash, created_at, source_bundle_id, is_pinned, is_favorited
            FROM history_items
            ORDER BY is_pinned DESC, created_at DESC, id DESC
            LIMIT ?;
            """
        ) else {
            return []
        }

        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))

        var results: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            let typeString = columnString(statement: statement, at: 1) ?? ClipboardItemType.text.rawValue
            let type = ClipboardItemType(rawValue: typeString) ?? .text
            let textContent = columnString(statement: statement, at: 2)
            let imagePath = columnString(statement: statement, at: 3)
            let contentHash = columnString(statement: statement, at: 4) ?? ""
            let timestamp = sqlite3_column_double(statement, 5)
            let sourceBundleID = columnString(statement: statement, at: 6)
            let isPinned = sqlite3_column_int(statement, 7) == 1
            let isFavorited = sqlite3_column_int(statement, 8) == 1

            let item = ClipboardItem(
                id: id,
                type: type,
                textContent: textContent,
                imagePath: imagePath,
                contentHash: contentHash,
                createdAt: Date(timeIntervalSince1970: timestamp),
                sourceBundleID: sourceBundleID,
                isPinned: isPinned,
                isFavorited: isFavorited
            )
            results.append(item)
        }

        return results
    }

    func latestHash() -> String? {
        guard let statement = prepare(
            """
            SELECT content_hash
            FROM history_items
            ORDER BY created_at DESC, id DESC
            LIMIT 1;
            """
        ) else {
            return nil
        }

        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return columnString(statement: statement, at: 0)
    }

    @discardableResult
    func insertText(
        text: String,
        hash: String,
        createdAt: Date,
        sourceBundleID: String?
    ) -> Int64 {
        guard let statement = prepare(
            """
            INSERT INTO history_items (type, text_content, image_path, content_hash, created_at, source_bundle_id)
            VALUES ('text', ?, NULL, ?, ?, ?);
            """
        ) else {
            return -1
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, text, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, hash, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, createdAt.timeIntervalSince1970)
        bindOptionalString(sourceBundleID, to: 4, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return -1
        }

        return sqlite3_last_insert_rowid(db)
    }

    @discardableResult
    func insertImage(
        imagePath: String,
        hash: String,
        createdAt: Date,
        sourceBundleID: String?
    ) -> Int64 {
        guard let statement = prepare(
            """
            INSERT INTO history_items (type, text_content, image_path, content_hash, created_at, source_bundle_id)
            VALUES ('image', NULL, ?, ?, ?, ?);
            """
        ) else {
            return -1
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, imagePath, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, hash, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, createdAt.timeIntervalSince1970)
        bindOptionalString(sourceBundleID, to: 4, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return -1
        }

        return sqlite3_last_insert_rowid(db)
    }

    @discardableResult
    func insertFile(
        fileContent: String,
        hash: String,
        createdAt: Date,
        sourceBundleID: String?
    ) -> Int64 {
        guard let statement = prepare(
            """
            INSERT INTO history_items (type, text_content, image_path, content_hash, created_at, source_bundle_id)
            VALUES ('file', ?, NULL, ?, ?, ?);
            """
        ) else {
            return -1
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, fileContent, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, hash, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, createdAt.timeIntervalSince1970)
        bindOptionalString(sourceBundleID, to: 4, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return -1
        }

        return sqlite3_last_insert_rowid(db)
    }

    func deleteItem(id: Int64) -> String? {
        let removedImagePath = imagePathForItem(id: id)

        guard let statement = prepare("DELETE FROM history_items WHERE id = ?;") else {
            return removedImagePath
        }

        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        _ = sqlite3_step(statement)

        return removedImagePath
    }

    func setPinned(itemID: Int64, isPinned: Bool) {
        guard let statement = prepare("UPDATE history_items SET is_pinned = ? WHERE id = ?;") else {
            return
        }

        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, isPinned ? 1 : 0)
        sqlite3_bind_int64(statement, 2, itemID)
        _ = sqlite3_step(statement)
    }

    func setFavorited(itemID: Int64, isFavorited: Bool) {
        guard let statement = prepare("UPDATE history_items SET is_favorited = ? WHERE id = ?;") else {
            return
        }

        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, isFavorited ? 1 : 0)
        sqlite3_bind_int64(statement, 2, itemID)
        _ = sqlite3_step(statement)
    }

    func clearAll() -> [String] {
        var removedPaths: [String] = []

        if let statement = prepare(
            "SELECT image_path FROM history_items WHERE type = 'image' AND image_path IS NOT NULL;"
        ) {
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                if let path = columnString(statement: statement, at: 0) {
                    removedPaths.append(path)
                }
            }
        }

        if let statement = prepare("DELETE FROM history_items;") {
            defer { sqlite3_finalize(statement) }
            _ = sqlite3_step(statement)
        }

        return removedPaths
    }

    func trimToCapacity(_ capacity: Int) -> [String] {
        guard capacity > 0 else {
            return clearAll()
        }

        var removedPaths: [String] = []

        if let statement = prepare(
            """
            SELECT image_path
            FROM history_items
            WHERE image_path IS NOT NULL
              AND is_pinned = 0
              AND is_favorited = 0
              AND id IN (
                  SELECT id
                  FROM history_items
                  WHERE is_pinned = 0
                    AND is_favorited = 0
                  ORDER BY created_at DESC, id DESC
                  LIMIT -1 OFFSET ?
              );
            """
        ) {
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(capacity))

            while sqlite3_step(statement) == SQLITE_ROW {
                if let path = columnString(statement: statement, at: 0) {
                    removedPaths.append(path)
                }
            }
        }

        if let statement = prepare(
            """
            DELETE FROM history_items
            WHERE id IN (
                SELECT id
                FROM history_items
                WHERE is_pinned = 0
                  AND is_favorited = 0
                ORDER BY created_at DESC, id DESC
                LIMIT -1 OFFSET ?
            );
            """
        ) {
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(capacity))
            _ = sqlite3_step(statement)
        }

        return removedPaths
    }

    private func imagePathForItem(id: Int64) -> String? {
        guard let statement = prepare(
            """
            SELECT image_path
            FROM history_items
            WHERE id = ?
            LIMIT 1;
            """
        ) else {
            return nil
        }

        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return columnString(statement: statement, at: 0)
    }

    private func hasColumn(named columnName: String, in table: String) -> Bool {
        guard let statement = prepare("PRAGMA table_info(\(table));") else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let currentColumnName = columnString(statement: statement, at: 1),
               currentColumnName == columnName
            {
                return true
            }
        }

        return false
    }

    private func bindOptionalString(_ value: String?, to index: Int32, in statement: OpaquePointer?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func columnString(statement: OpaquePointer?, at index: Int32) -> String? {
        guard let rawValue = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: rawValue)
    }

    private func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)

        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw SQLiteHistoryDatabaseError.migrationFailed(message)
        }
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            return statement
        }

        return nil
    }
}

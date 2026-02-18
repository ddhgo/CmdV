import Combine
import CryptoKit
import Foundation

final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let settings: SettingsStore
    private let database: SQLiteHistoryDatabase
    private let imageStorage: ImageStorage
    private let queue = DispatchQueue(label: "CmdV.HistoryStoreQueue", qos: .userInitiated)
    private let nearDuplicateSuppressionWindow: TimeInterval = 8

    private var lastInsertedTextFingerprint: String?
    private var lastInsertedTextSourceBundleID: String?
    private var lastInsertedTextDate: Date = .distantPast

    private var cancellables: Set<AnyCancellable> = []

    init(settings: SettingsStore) throws {
        self.settings = settings

        let appSupportDirectory = try Self.createAppSupportDirectory()
        database = try SQLiteHistoryDatabase(databaseURL: appSupportDirectory.appendingPathComponent("history.sqlite3"))
        imageStorage = try ImageStorage(baseDirectory: appSupportDirectory)

        settings.$maxHistoryItems
            .dropFirst()
            .sink { [weak self] _ in
                self?.trimToCapacity()
            }
            .store(in: &cancellables)
    }

    func loadInitialHistory() {
        queue.async { [weak self] in
            self?.publishLatestItems()
        }
    }

    func addTextIfNeeded(_ text: String, sourceBundleID: String?) {
        let normalizedText = Self.normalizeCapturedText(text)
        guard !normalizedText.isEmpty else {
            return
        }

        let hash = Self.hashString(normalizedText)
        let fingerprint = Self.textFingerprint(normalizedText)

        queue.async { [weak self] in
            guard let self else {
                return
            }

            let now = Date()

            if self.shouldSuppressNearDuplicateText(
                fingerprint: fingerprint,
                sourceBundleID: sourceBundleID,
                now: now
            ) {
                return
            }

            if self.database.latestHash() == hash {
                self.recordLatestTextCapture(
                    fingerprint: fingerprint,
                    sourceBundleID: sourceBundleID,
                    at: now
                )
                return
            }

            _ = self.database.insertText(
                text: normalizedText,
                hash: hash,
                createdAt: now,
                sourceBundleID: sourceBundleID
            )

            self.recordLatestTextCapture(
                fingerprint: fingerprint,
                sourceBundleID: sourceBundleID,
                at: now
            )

            self.cleanupOverflow()
            self.publishLatestItems()
        }
    }

    func addImageDataIfNeeded(_ pngData: Data, sourceBundleID: String?) {
        guard !pngData.isEmpty else {
            return
        }

        let hash = Self.hashData(pngData)

        queue.async { [weak self] in
            guard let self else {
                return
            }

            if self.database.latestHash() == hash {
                return
            }

            do {
                let imagePath = try self.imageStorage.saveImageData(pngData, hash: hash)

                _ = self.database.insertImage(
                    imagePath: imagePath,
                    hash: hash,
                    createdAt: Date(),
                    sourceBundleID: sourceBundleID
                )

                self.cleanupOverflow()
                self.publishLatestItems()
            } catch {
                return
            }
        }
    }

    func delete(itemID: Int64) {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            let removedPath = self.database.deleteItem(id: itemID)
            self.imageStorage.removeImage(at: removedPath)
            self.publishLatestItems()
        }
    }

    func setPinned(itemID: Int64, isPinned: Bool) {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            self.database.setPinned(itemID: itemID, isPinned: isPinned)
            self.publishLatestItems()
        }
    }

    func clearHistory() {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            let removedPaths = self.database.clearAll()
            self.imageStorage.removeImages(at: removedPaths)
            self.resetRecentTextCaptureState()
            self.publishLatestItems()
        }
    }

    func trimToCapacity() {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            self.cleanupOverflow()
            self.publishLatestItems()
        }
    }

    private func cleanupOverflow() {
        let removedPaths = database.trimToCapacity(settings.maxHistoryItems)
        imageStorage.removeImages(at: removedPaths)
    }

    private func shouldSuppressNearDuplicateText(
        fingerprint: String,
        sourceBundleID: String?,
        now: Date
    ) -> Bool {
        guard let lastInsertedTextFingerprint else {
            return false
        }

        guard lastInsertedTextFingerprint == fingerprint else {
            return false
        }

        guard lastInsertedTextSourceBundleID == sourceBundleID else {
            return false
        }

        return now.timeIntervalSince(lastInsertedTextDate) <= nearDuplicateSuppressionWindow
    }

    private func recordLatestTextCapture(
        fingerprint: String,
        sourceBundleID: String?,
        at date: Date
    ) {
        lastInsertedTextFingerprint = fingerprint
        lastInsertedTextSourceBundleID = sourceBundleID
        lastInsertedTextDate = date
    }

    private func resetRecentTextCaptureState() {
        lastInsertedTextFingerprint = nil
        lastInsertedTextSourceBundleID = nil
        lastInsertedTextDate = .distantPast
    }

    private func publishLatestItems() {
        let latest = database.fetchRecentItems(limit: settings.maxHistoryItems)
        DispatchQueue.main.async { [weak self] in
            self?.items = latest
        }
    }

    private static func createAppSupportDirectory() throws -> URL {
        let baseDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first

        guard let baseDirectory else {
            throw CocoaError(.fileNoSuchFile)
        }

        let appDirectory = baseDirectory.appendingPathComponent("CmdV", isDirectory: true)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
    }

    private static func hashString(_ string: String) -> String {
        hashData(Data(string.utf8))
    }

    private static func normalizeCapturedText(_ text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{0000}", with: "")

        normalized = normalized.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return normalized.trimmingCharacters(in: .newlines)
    }

    private static func textFingerprint(_ text: String) -> String {
        let collapsedWhitespace = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hashData(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

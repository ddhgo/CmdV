import AppKit
import Foundation
import XCTest
@testable import CmdV

final class ClipboardMonitorIntegrationTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var temporaryDirectory: URL!
    private var settings: SettingsStore!
    private var historyStore: HistoryStore!
    private var pasteboard: FakePasteboardReader!
    private var monitor: ClipboardMonitor!

    override func setUpWithError() throws {
        try super.setUpWithError()

        defaultsSuiteName = "CmdVTests.ClipboardMonitor.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CmdVTests-ClipboardMonitor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        settings = SettingsStore(defaults: defaults)
        settings.maxHistoryItems = 50
        historyStore = try HistoryStore(settings: settings, appSupportDirectory: temporaryDirectory)
        historyStore.clearHistory()
        waitUntil("history is empty") {
            self.historyStore.items.isEmpty
        }

        pasteboard = FakePasteboardReader()
        monitor = ClipboardMonitor(
            historyStore: historyStore,
            settings: settings,
            pasteboardReader: pasteboard,
            frontmostBundleIDProvider: { "com.test.source" }
        )
    }

    override func tearDownWithError() throws {
        monitor?.stop()
        monitor = nil
        pasteboard = nil
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

    func testPollCapturesPlainTextClipboardItem() {
        pasteboard.plainText = "Captured text"
        pasteboard.changeCount = 1

        monitor.pollNow()

        waitUntil("text item captured") {
            self.historyStore.items.count == 1
        }

        XCTAssertEqual(historyStore.items.first?.type, .text)
        XCTAssertEqual(historyStore.items.first?.textContent, "Captured text")
    }

    func testPollCapturesTIFFImageAndConvertsToPNG() throws {
        pasteboard.tiffData = try makeSampleTIFFData()
        pasteboard.changeCount = 1

        monitor.pollNow()

        waitUntil("image item captured") {
            self.historyStore.items.count == 1 && self.historyStore.items.first?.type == .image
        }

        guard let imagePath = historyStore.items.first?.imagePath else {
            XCTFail("Expected image path for captured image")
            return
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: imagePath))
    }

    private func makeSampleTIFFData() throws -> Data {
        let size = NSSize(width: 4, height: 4)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard let data = image.tiffRepresentation else {
            throw NSError(domain: "ClipboardMonitorIntegrationTests", code: 1)
        }

        return data
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

private final class FakePasteboardReader: PasteboardReading {
    var changeCount: Int = 0
    var plainText: String?
    var utf8Text: String?
    var utf16Text: String?
    var capturedFileURLs: [URL] = []
    var rtfData: Data?
    var pngData: Data?
    var tiffData: Data?
    var fallbackImageTIFFData: Data?

    var firstItem: PasteboardItemReading? {
        if utf8Text == nil, utf16Text == nil, rtfData == nil {
            return nil
        }

        return FakePasteboardItemReader(
            utf8Text: utf8Text,
            utf16Text: utf16Text,
            rtfData: rtfData
        )
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        switch type {
        case .string:
            return plainText
        default:
            return nil
        }
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        switch type {
        case .png:
            return pngData
        case .tiff:
            return tiffData
        default:
            return nil
        }
    }

    func fileURLs() -> [URL] {
        capturedFileURLs
    }

    func firstImageTIFFRepresentation() -> Data? {
        fallbackImageTIFFData
    }
}

private struct FakePasteboardItemReader: PasteboardItemReading {
    let utf8Text: String?
    let utf16Text: String?
    let rtfData: Data?

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        if type.rawValue == "public.utf8-plain-text" {
            return utf8Text
        }

        if type.rawValue == "public.utf16-plain-text" {
            return utf16Text
        }

        return nil
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        if type == .rtf {
            return rtfData
        }

        return nil
    }
}

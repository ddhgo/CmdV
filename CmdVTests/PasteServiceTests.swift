import AppKit
import XCTest
@testable import CmdV

final class PasteServiceTests: XCTestCase {
    private var service: PasteService!
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CmdVTests-PasteService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        service = makeService(accessibilityGranted: true)
        NSPasteboard.general.clearContents()
    }

    override func tearDownWithError() throws {
        NSPasteboard.general.clearContents()
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        service = nil
        temporaryDirectory = nil

        try super.tearDownWithError()
    }

    func testCopyToPasteboardTextWritesString() {
        let item = makeTextItem(text: "hello CmdV")

        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertTrue(didCopy)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "hello CmdV")
    }

    func testCopyToPasteboardTextFailsWithoutTextContent() {
        let item = makeTextItem(text: nil)

        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertFalse(didCopy)
        XCTAssertNil(NSPasteboard.general.string(forType: .string))
    }

    func testCopyToPasteboardImageWritesPNGAndTIFFData() throws {
        let pngData = try makeSamplePNGData()
        let imagePath = temporaryDirectory.appendingPathComponent("sample.png", isDirectory: false)
        try pngData.write(to: imagePath, options: .atomic)

        let item = makeImageItem(path: imagePath.path)
        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertTrue(didCopy)
        XCTAssertEqual(NSPasteboard.general.data(forType: .png), pngData)
        XCTAssertNotNil(NSPasteboard.general.data(forType: .tiff))
    }

    func testCopyToPasteboardImageFailsWhenImageFileIsMissing() {
        let missingPath = temporaryDirectory.appendingPathComponent("missing.png", isDirectory: false).path
        let item = makeImageItem(path: missingPath)

        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertFalse(didCopy)
        XCTAssertNil(NSPasteboard.general.data(forType: .png))
    }

    func testCopyToPasteboardFileWritesFileURLs() {
        let firstFileURL = temporaryDirectory.appendingPathComponent("first.txt", isDirectory: false)
        let secondFileURL = temporaryDirectory.appendingPathComponent("second.txt", isDirectory: false)
        try? "first".write(to: firstFileURL, atomically: true, encoding: .utf8)
        try? "second".write(to: secondFileURL, atomically: true, encoding: .utf8)

        let item = makeFileItem(fileURLs: [firstFileURL, secondFileURL])

        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertTrue(didCopy)

        let pasteboardURLs = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        XCTAssertEqual(pasteboardURLs, [firstFileURL, secondFileURL])
    }

    func testCopyToPasteboardFileWritesLegacyFilenamesType() {
        let firstFileURL = temporaryDirectory.appendingPathComponent("first.txt", isDirectory: false)
        let secondFileURL = temporaryDirectory.appendingPathComponent("second.txt", isDirectory: false)
        try? "first".write(to: firstFileURL, atomically: true, encoding: .utf8)
        try? "second".write(to: secondFileURL, atomically: true, encoding: .utf8)

        let item = makeFileItem(fileURLs: [firstFileURL, secondFileURL])
        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertTrue(didCopy)

        let hasFileURLType = NSPasteboard.general.pasteboardItems?.contains { item in
            item.types.contains(.fileURL)
        } ?? false

        XCTAssertTrue(hasFileURLType)

        let hasLegacyFileListType = NSPasteboard.general.types?.contains { type in
            type.rawValue == "NSFilenamesPboardType"
        } ?? false

        XCTAssertTrue(hasLegacyFileListType || hasFileURLType)
    }

    func testCopyToPasteboardFileWithoutPayloadReturnsFalse() {
        let item = makeFileItem(fileURLs: [])

        let didCopy = service.copyToPasteboard(item: item)

        XCTAssertFalse(didCopy)
    }

    func testPasteReturnsFailedToCopyWhenImageFileIsMissing() {
        let missingPath = temporaryDirectory.appendingPathComponent("missing.png", isDirectory: false).path
        let item = makeImageItem(path: missingPath)

        let completion = expectation(description: "paste completion")
        var outcome: PasteOutcome?

        service.paste(
            item: item,
            targetApplication: nil,
            targetFocusedElement: nil,
            targetFocusedWindow: nil
        ) { result in
            outcome = result
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1.0)

        if case .failedToCopy? = outcome {
            return
        }

        XCTFail("Expected .failedToCopy but got \(String(describing: outcome))")
    }

    func testPasteReturnsCopiedOnlyNeedsAccessibilityWhenPermissionMissing() {
        service = makeService(
            accessibilityGranted: false,
            sendCommandVShortcutHandler: {
                XCTFail("Cmd+V should not be sent when accessibility is missing")
                return false
            }
        )
        let item = makeTextItem(text: "permission test")

        let completion = expectation(description: "paste completion")
        var outcome: PasteOutcome?

        service.paste(
            item: item,
            targetApplication: nil,
            targetFocusedElement: nil,
            targetFocusedWindow: nil
        ) { result in
            outcome = result
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1.0)

        if case .copiedOnlyNeedsAccessibility? = outcome {
            XCTAssertEqual(NSPasteboard.general.string(forType: .string), "permission test")
            return
        }

        XCTFail("Expected .copiedOnlyNeedsAccessibility but got \(String(describing: outcome))")
    }

    func testPasteReturnsPastedWhenPermissionGrantedAndShortcutSucceeds() {
        service = makeService(
            accessibilityGranted: true,
            sendCommandVShortcutHandler: { true }
        )
        let item = makeTextItem(text: "shortcut-success")

        let completion = expectation(description: "paste completion")
        var outcome: PasteOutcome?

        service.paste(
            item: item,
            targetApplication: nil,
            targetFocusedElement: nil,
            targetFocusedWindow: nil
        ) { result in
            outcome = result
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1.0)

        if case .pasted? = outcome {
            return
        }

        XCTFail("Expected .pasted but got \(String(describing: outcome))")
    }

    func testPasteReturnsFailedToSendShortcutWhenPermissionGrantedButShortcutFails() {
        service = makeService(
            accessibilityGranted: true,
            sendCommandVShortcutHandler: { false }
        )
        let item = makeTextItem(text: "shortcut-failure")

        let completion = expectation(description: "paste completion")
        var outcome: PasteOutcome?

        service.paste(
            item: item,
            targetApplication: nil,
            targetFocusedElement: nil,
            targetFocusedWindow: nil
        ) { result in
            outcome = result
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1.0)

        if case .failedToSendShortcut? = outcome {
            return
        }

        XCTFail("Expected .failedToSendShortcut but got \(String(describing: outcome))")
    }

    func testPasteTargetApplicationFocusPathReturnsPasted() {
        let targetApplication = NSRunningApplication.current
        var activateCallCount = 0

        service = makeService(
            accessibilityGranted: true,
            sendCommandVShortcutHandler: { true },
            frontmostApplicationProvider: { targetApplication },
            applicationActivator: { _ in
                activateCallCount += 1
            }
        )

        let item = makeTextItem(text: "target-flow")
        let completion = expectation(description: "paste completion")
        var outcome: PasteOutcome?

        service.paste(
            item: item,
            targetApplication: targetApplication,
            targetFocusedElement: nil,
            targetFocusedWindow: nil
        ) { result in
            outcome = result
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1.0)

        if case .pasted? = outcome {
            XCTAssertGreaterThanOrEqual(activateCallCount, 1)
            return
        }

        XCTFail("Expected .pasted but got \(String(describing: outcome))")
    }

    private func makeTextItem(text: String?) -> ClipboardItem {
        ClipboardItem(
            id: 1,
            type: .text,
            textContent: text,
            imagePath: nil,
            contentHash: "hash-text",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceBundleID: nil,
            isPinned: false,
            isFavorited: false
        )
    }

    private func makeImageItem(path: String?) -> ClipboardItem {
        ClipboardItem(
            id: 2,
            type: .image,
            textContent: nil,
            imagePath: path,
            contentHash: "hash-image",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceBundleID: nil,
            isPinned: false,
            isFavorited: false
        )
    }

    private func makeFileItem(fileURLs: [URL]) -> ClipboardItem {
        ClipboardItem(
            id: 3,
            type: .file,
            textContent: ClipboardItem.serializeFileURLs(fileURLs),
            imagePath: nil,
            contentHash: "hash-file",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceBundleID: nil,
            isPinned: false,
            isFavorited: false
        )
    }

    private func makeSamplePNGData() throws -> Data {
        let size = NSSize(width: 1, height: 1)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "PasteServiceTests", code: 1)
        }

        return pngData
    }

    private func makeService(
        accessibilityGranted: Bool,
        sendCommandVShortcutHandler: @escaping () -> Bool = { true },
        frontmostApplicationProvider: @escaping () -> NSRunningApplication? = { nil },
        applicationActivator: @escaping (NSRunningApplication) -> Void = { _ in }
    ) -> PasteService {
        PasteService(
            permissions: StubPermissions(accessibilityGranted: accessibilityGranted),
            sendCommandVShortcutHandler: sendCommandVShortcutHandler,
            frontmostApplicationProvider: frontmostApplicationProvider,
            applicationActivator: applicationActivator,
            mainAsyncAfter: { _, work in work() },
            refocusHandler: { _, _ in }
        )
    }
}

private struct StubPermissions: AccessibilityPermissionChecking {
    let accessibilityGranted: Bool

    var accessibilityGrantedNow: Bool {
        accessibilityGranted
    }
}

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

        service = PasteService(permissions: PermissionsService())
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

    private func makeTextItem(text: String?) -> ClipboardItem {
        ClipboardItem(
            id: 1,
            type: .text,
            textContent: text,
            imagePath: nil,
            contentHash: "hash-text",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceBundleID: nil,
            isPinned: false
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
            isPinned: false
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
}

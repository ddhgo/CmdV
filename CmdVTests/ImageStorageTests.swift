import Foundation
import XCTest
@testable import CmdV

final class ImageStorageTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var storage: ImageStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CmdVTests-ImageStorage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        storage = try ImageStorage(baseDirectory: temporaryDirectory)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        storage = nil
        temporaryDirectory = nil

        try super.tearDownWithError()
    }

    func testInitCreatesImagesDirectory() throws {
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: storage.imagesDirectory.path, isDirectory: &isDirectory)

        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testSaveImageDataWritesFileAndReturnsExpectedPath() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])

        let savedPath = try storage.saveImageData(data, hash: "hash-1")

        XCTAssertEqual(savedPath, storage.imagesDirectory.appendingPathComponent("hash-1.png", isDirectory: false).path)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: savedPath)), data)
    }

    func testSaveImageDataDoesNotOverwriteExistingFileForSameHash() throws {
        let original = Data([0x01, 0x02, 0x03])
        let replacement = Data([0x0A, 0x0B, 0x0C])

        let firstPath = try storage.saveImageData(original, hash: "same-hash")
        let secondPath = try storage.saveImageData(replacement, hash: "same-hash")

        XCTAssertEqual(firstPath, secondPath)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: firstPath)), original)
    }

    func testRemoveImageDeletesExistingFile() throws {
        let path = try storage.saveImageData(Data([0x41, 0x42]), hash: "to-delete")

        storage.removeImage(at: path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testRemoveImageIgnoresNilAndMissingPath() {
        storage.removeImage(at: nil)
        storage.removeImage(at: storage.imagesDirectory.appendingPathComponent("missing.png", isDirectory: false).path)
    }

    func testRemoveImagesDeletesEveryProvidedPath() throws {
        let first = try storage.saveImageData(Data([0x01]), hash: "first")
        let second = try storage.saveImageData(Data([0x02]), hash: "second")

        storage.removeImages(at: [first, second])

        XCTAssertFalse(FileManager.default.fileExists(atPath: first))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second))
    }
}

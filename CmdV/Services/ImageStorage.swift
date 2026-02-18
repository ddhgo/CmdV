import Foundation

final class ImageStorage {
    let imagesDirectory: URL

    init(baseDirectory: URL) throws {
        imagesDirectory = baseDirectory.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(
            at: imagesDirectory,
            withIntermediateDirectories: true
        )
    }

    func saveImageData(_ data: Data, hash: String) throws -> String {
        let fileURL = imagesDirectory.appendingPathComponent("\(hash).png", isDirectory: false)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try data.write(to: fileURL, options: .atomic)
        }

        return fileURL.path
    }

    func removeImage(at path: String?) {
        guard let path else {
            return
        }

        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func removeImages(at paths: [String]) {
        for path in paths {
            removeImage(at: path)
        }
    }
}

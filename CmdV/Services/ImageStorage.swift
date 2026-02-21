import Foundation

final class ImageStorage {
    let imagesDirectory: URL

    init(baseDirectory: URL) throws {
        imagesDirectory = baseDirectory.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(
            at: imagesDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: imagesDirectory.path)
    }

    func saveImageData(_ data: Data, hash: String) throws -> String {
        let fileURL = imagesDirectory.appendingPathComponent("\(hash).png", isDirectory: false)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try data.write(to: fileURL, options: .atomic)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)

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

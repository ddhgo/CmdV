import Foundation

enum ClipboardItemType: String {
    case text
    case image
    case file
}

struct ClipboardItem: Identifiable, Hashable {
    let id: Int64
    let type: ClipboardItemType
    let textContent: String?
    let imagePath: String?
    let contentHash: String
    let createdAt: Date
    let sourceBundleID: String?
    let isPinned: Bool
    let isFavorited: Bool
}

extension ClipboardItem {
    var fileURLs: [URL] {
        guard type == .file, let textContent else {
            return []
        }

        return Self.deserializeFileURLs(from: textContent)
    }

    func displayTitle(for language: AppLanguage) -> String {
        switch type {
        case .text:
            return textContent ?? ""
        case .image:
            return AppText.value(.popupImageLabel, language: language)
        case .file:
            let urls = fileURLs
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }

            if urls.count > 1 {
                return "\(urls.count) \(AppText.value(.popupFilesLabel, language: language))"
            }

            return AppText.value(.popupFileLabel, language: language)
        }
    }

    static func serializeFileURLs(_ fileURLs: [URL]) -> String? {
        let normalizedPaths = fileURLs
            .map(\.standardizedFileURL)
            .map(\.path)
            .filter { !$0.isEmpty }

        guard !normalizedPaths.isEmpty else {
            return nil
        }

        guard let data = try? JSONEncoder().encode(normalizedPaths) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func deserializeFileURLs(from value: String) -> [URL] {
        let payload = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !payload.isEmpty,
              let data = payload.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}

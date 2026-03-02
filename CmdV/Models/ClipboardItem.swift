import AppKit
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
    /// Deserialises the file URLs stored for this item.
    ///
    /// For `.file` items `textContent` holds a JSON-encoded `[String]` of
    /// absolute POSIX paths (written by `serializeFileURLs(_:)`).  This
    /// property decodes those paths and filters out any that no longer exist
    /// on disk, so callers always receive only resolvable URLs.
    var fileURLs: [URL] {
        guard type == .file, let textContent else {
            return []
        }

        return Self.deserializeFileURLs(from: textContent)
    }

    func displaySubtitle(for language: AppLanguage) -> String? {
        switch type {
        case .file:
            return sourceName() ?? fileFormatSummary(for: language)
        case .text:
            return sourceName() ?? AppText.value(.popupTextTypeLabel, language: language)
        case .image:
            return sourceName() ?? imageFormatSummary(for: language)
        }
    }

    /// Returns a human-readable app name for the clipboard source, or `nil` if
    /// no source bundle ID was recorded.
    ///
    /// Lookup chain (first non-empty value wins):
    /// 1. `CFBundleDisplayName` from the app's `Info.plist`
    /// 2. `CFBundleName` from the app's `Info.plist`
    /// 3. The app file name without extension (e.g. `"Safari"`)
    /// 4. The last component of the bundle ID (e.g. `"safari"` from
    ///    `"com.apple.Safari"`) — used when the app bundle can no longer be
    ///    located on disk.
    private func sourceName() -> String? {
        guard let bundleID = sourceBundleID else {
            return nil
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
               !displayName.isEmpty {
                return displayName
            }

            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
               !name.isEmpty {
                return name
            }

            return appURL.deletingPathExtension().lastPathComponent
        }

        return bundleID.components(separatedBy: ".").last
    }

    private func imageFormatSummary(for language: AppLanguage) -> String? {
        return AppText.value(.popupImageLabel, language: language)
    }

    func fileFormatSummary(for language: AppLanguage) -> String {
        let urls = fileURLs

        guard !urls.isEmpty else {
            return AppText.value(.popupFileLabel, language: language)
        }

        let formatLabels = urls.map { Self.fileFormatLabel(for: $0, language: language) }
        var uniqueFormats: [String] = []

        for label in formatLabels where !uniqueFormats.contains(label) {
            uniqueFormats.append(label)
        }

        if uniqueFormats.count == 1 {
            if urls.count > 1 {
                return "\(uniqueFormats[0]) · \(Self.fileCountText(urls.count, language: language))"
            }

            return uniqueFormats[0]
        }

        if uniqueFormats.count == 2 {
            return uniqueFormats.joined(separator: ", ")
        }

        return "\(AppText.value(.popupMixedFileTypes, language: language)) (\(Self.fileCountText(urls.count, language: language)))"
    }

    /// Returns a short display label for a single file URL.
    ///
    /// Detection order:
    /// 1. **Directory** — checked via `URLResourceValues.isDirectory` to avoid
    ///    relying on path-extension heuristics for packages / bundles.
    /// 2. **File extension** — uppercased (e.g. `"PDF"`, `"PNG"`).
    /// 3. **Unknown** — shown when the extension is missing or empty.
    private static func fileFormatLabel(for url: URL, language: AppLanguage) -> String {
        var isDirectory = false
        if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
           let value = resourceValues.isDirectory {
            isDirectory = value
        }

        if isDirectory {
            return AppText.value(.popupFolderLabel, language: language)
        }

        let extensionLower = url.pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !extensionLower.isEmpty else {
            return AppText.value(.popupFileTypeUnknown, language: language)
        }

        return extensionLower.uppercased()
    }

    /// Formats a file count string according to the active app language.
    ///
    /// - English: `"3 files"`
    /// - Korean:  `"3개"`
    private static func fileCountText(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(count) files"
        case .korean:
            return "\(count)개"
        }
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

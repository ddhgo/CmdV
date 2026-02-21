import AppKit
import Combine
import Foundation
import ImageIO
import UniformTypeIdentifiers

protocol PasteboardItemReading {
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
}

protocol PasteboardReading {
    var changeCount: Int { get }
    var firstItem: PasteboardItemReading? { get }
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    func fileURLs() -> [URL]
    func firstImageTIFFRepresentation() -> Data?
}

private struct SystemPasteboardItemReader: PasteboardItemReading {
    let item: NSPasteboardItem

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        item.string(forType: type)
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        item.data(forType: type)
    }
}

private final class SystemPasteboardReader: PasteboardReading {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    var firstItem: PasteboardItemReading? {
        guard let item = pasteboard.pasteboardItems?.first else {
            return nil
        }

        return SystemPasteboardItemReader(item: item)
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        pasteboard.string(forType: type)
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        pasteboard.data(forType: type)
    }

    func fileURLs() -> [URL] {
        guard
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL]
        else {
            return []
        }

        return urls
    }

    func firstImageTIFFRepresentation() -> Data? {
        guard
            let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
            let image = images.first as? NSImage
        else {
            return nil
        }

        return image.tiffRepresentation
    }
}

final class ClipboardMonitor {
    private let pasteboardReader: PasteboardReading
    private let historyStore: HistoryStore
    private let settings: SettingsStore
    private let frontmostBundleIDProvider: () -> String?
    private let payloadProcessingQueue = DispatchQueue(
        label: "CmdV.ClipboardPayloadProcessingQueue",
        qos: .userInitiated
    )
    private let utf8TextType = NSPasteboard.PasteboardType("public.utf8-plain-text")
    private let utf16TextType = NSPasteboard.PasteboardType("public.utf16-plain-text")

    private var timer: Timer?
    private var lastChangeCount: Int
    private var cancellables: Set<AnyCancellable> = []

    private struct PasteboardPayloadSnapshot {
        let fileURLs: [URL]
        let plainText: String?
        let utf8Text: String?
        let utf16Text: String?
        let rtfData: Data?
        let pngData: Data?
        let tiffData: Data?
        let fallbackImageData: Data?
    }

    init(
        historyStore: HistoryStore,
        settings: SettingsStore,
        pasteboardReader: PasteboardReading = SystemPasteboardReader(),
        frontmostBundleIDProvider: @escaping () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
    ) {
        self.pasteboardReader = pasteboardReader
        self.historyStore = historyStore
        self.settings = settings
        self.frontmostBundleIDProvider = frontmostBundleIDProvider
        lastChangeCount = pasteboardReader.changeCount

        settings.$pollingInterval
            .dropFirst()
            .sink { [weak self] interval in
                self?.restart(interval: interval)
            }
            .store(in: &cancellables)
    }

    func start() {
        restart(interval: settings.pollingInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pollNow() {
        pollPasteboard()
    }

    private func restart(interval: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.timer?.invalidate()
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.pollPasteboard()
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func pollPasteboard() {
        let currentChangeCount = pasteboardReader.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lastChangeCount = currentChangeCount

        let isRecordingPaused = settings.isRecordingPaused
        guard !isRecordingPaused else {
            return
        }

        let excludedBundleIDs = settings.excludedBundleIDs
        let sourceBundleID = frontmostBundleIDProvider()

        if let sourceBundleID, excludedBundleIDs.contains(sourceBundleID) {
            return
        }

        payloadProcessingQueue.async { [weak self] in
            guard let self else {
                return
            }

            let payload = self.capturePayloadSnapshot()
            self.processPayload(payload, sourceBundleID: sourceBundleID)
        }
    }

    private func capturePayloadSnapshot() -> PasteboardPayloadSnapshot {
        let item = pasteboardReader.firstItem
        let fileURLs = pasteboardReader.fileURLs()
        let plainText = pasteboardReader.string(forType: .string)
        let utf8Text = item?.string(forType: utf8TextType)
        let utf16Text = item?.string(forType: utf16TextType)
        let rtfData = item?.data(forType: .rtf)
        let pngData = pasteboardReader.data(forType: .png)
        let tiffData = pasteboardReader.data(forType: .tiff)
        let fallbackImageData: Data?
        if pngData == nil, tiffData == nil {
            fallbackImageData = pasteboardReader.firstImageTIFFRepresentation()
        } else {
            fallbackImageData = nil
        }

        if !fileURLs.isEmpty {
            return PasteboardPayloadSnapshot(
                fileURLs: fileURLs,
                plainText: plainText,
                utf8Text: utf8Text,
                utf16Text: utf16Text,
                rtfData: rtfData,
                pngData: pngData,
                tiffData: tiffData,
                fallbackImageData: fallbackImageData
            )
        }

        if pngData != nil || tiffData != nil || fallbackImageData != nil {
            return PasteboardPayloadSnapshot(
                fileURLs: [],
                plainText: nil,
                utf8Text: nil,
                utf16Text: nil,
                rtfData: nil,
                pngData: pngData,
                tiffData: tiffData,
                fallbackImageData: fallbackImageData
            )
        }

        if [plainText, utf8Text, utf16Text].contains(where: { !($0?.isEmpty ?? true) }) {
            return PasteboardPayloadSnapshot(
                fileURLs: [],
                plainText: plainText,
                utf8Text: utf8Text,
                utf16Text: utf16Text,
                rtfData: rtfData,
                pngData: nil,
                tiffData: nil,
                fallbackImageData: nil
            )
        }

        return PasteboardPayloadSnapshot(
            fileURLs: [],
            plainText: nil,
            utf8Text: nil,
            utf16Text: nil,
            rtfData: nil,
            pngData: nil,
            tiffData: nil,
            fallbackImageData: nil
        )
    }

    private func processPayload(_ payload: PasteboardPayloadSnapshot, sourceBundleID: String?) {
        if !payload.fileURLs.isEmpty {
            historyStore.addFileURLsIfNeeded(payload.fileURLs, sourceBundleID: sourceBundleID)
            return
        }

        if let text = extractPlainText(from: payload), !text.isEmpty {
            historyStore.addTextIfNeeded(text, sourceBundleID: sourceBundleID)
            return
        }

        if let pngData = payload.pngData, !pngData.isEmpty {
            historyStore.addImageDataIfNeeded(pngData, sourceBundleID: sourceBundleID)
            return
        }

        if let tiffData = payload.tiffData,
           let pngData = Self.pngData(fromImageData: tiffData)
        {
            historyStore.addImageDataIfNeeded(pngData, sourceBundleID: sourceBundleID)
            return
        }

        if let fallbackImageData = payload.fallbackImageData,
           let pngData = Self.pngData(fromImageData: fallbackImageData)
        {
            historyStore.addImageDataIfNeeded(pngData, sourceBundleID: sourceBundleID)
        }
    }

    private func extractPlainText(from payload: PasteboardPayloadSnapshot) -> String? {
        if let text = payload.plainText, !text.isEmpty {
            return text
        }

        let candidateTexts = [payload.utf8Text, payload.utf16Text]
        for candidate in candidateTexts {
            if let text = candidate, !text.isEmpty {
                return text
            }
        }

        if let rtfData = payload.rtfData,
           let attributed = try? NSAttributedString(
               data: rtfData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           )
        {
            let text = attributed.string
            if !text.isEmpty {
                return text
            }
        }

        return nil
    }

    private static func pngData(fromImageData imageData: Data) -> Data? {
        guard
            !imageData.isEmpty,
            let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            return nil
        }

        let outputData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                outputData,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return outputData as Data
    }
}

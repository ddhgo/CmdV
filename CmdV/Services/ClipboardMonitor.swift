import AppKit
import Combine
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let historyStore: HistoryStore
    private let settings: SettingsStore
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
        let plainText: String?
        let utf8Text: String?
        let utf16Text: String?
        let rtfData: Data?
        let pngData: Data?
        let tiffData: Data?
        let fallbackImageData: Data?
    }

    init(historyStore: HistoryStore, settings: SettingsStore) {
        self.historyStore = historyStore
        self.settings = settings
        lastChangeCount = pasteboard.changeCount

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
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }

        lastChangeCount = currentChangeCount

        guard !settings.isRecordingPaused else {
            return
        }

        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let sourceBundleID, settings.excludedBundleIDs.contains(sourceBundleID) {
            return
        }

        let payload = capturePayloadSnapshot()

        payloadProcessingQueue.async { [weak self] in
            self?.processPayload(payload, sourceBundleID: sourceBundleID)
        }
    }

    private func capturePayloadSnapshot() -> PasteboardPayloadSnapshot {
        let item = pasteboard.pasteboardItems?.first
        let plainText = pasteboard.string(forType: .string)
        let utf8Text = item?.string(forType: utf8TextType)
        let utf16Text = item?.string(forType: utf16TextType)
        let rtfData = item?.data(forType: .rtf)

        if [plainText, utf8Text, utf16Text].contains(where: { !($0?.isEmpty ?? true) }) {
            return PasteboardPayloadSnapshot(
                plainText: plainText,
                utf8Text: utf8Text,
                utf16Text: utf16Text,
                rtfData: rtfData,
                pngData: nil,
                tiffData: nil,
                fallbackImageData: nil
            )
        }

        let pngData = pasteboard.data(forType: .png)
        let tiffData = pasteboard.data(forType: .tiff)

        let fallbackImageData: Data?
        if pngData == nil, tiffData == nil,
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = images.first as? NSImage
        {
            fallbackImageData = image.tiffRepresentation
        } else {
            fallbackImageData = nil
        }

        return PasteboardPayloadSnapshot(
            plainText: plainText,
            utf8Text: utf8Text,
            utf16Text: utf16Text,
            rtfData: rtfData,
            pngData: pngData,
            tiffData: tiffData,
            fallbackImageData: fallbackImageData
        )
    }

    private func processPayload(_ payload: PasteboardPayloadSnapshot, sourceBundleID: String?) {
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

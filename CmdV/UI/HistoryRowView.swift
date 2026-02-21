import AppKit
import ImageIO
import SwiftUI

private enum RelativeTime {
    static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }
}

private final class ThumbnailCache {
    static let shared = NSCache<NSString, NSImage>()
}

private enum ThumbnailProvider {
    static func thumbnail(for path: String, maxPixelSize: Int = 220) -> NSImage? {
        if let cached = ThumbnailCache.shared.object(forKey: NSString(string: path)) {
            return cached
        }

        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        ThumbnailCache.shared.setObject(image, forKey: NSString(string: path))
        return image
    }
}

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let language: AppLanguage
    let onMenuOpen: (ClipboardItem) -> Void
    let onMenuClose: () -> Void
    let onHoverChanged: (ClipboardItem, Bool) -> Void
    let onCopy: (ClipboardItem) -> Void
    let onShare: (ClipboardItem) -> Void
    let onOpen: (ClipboardItem) -> Void
    let onTogglePinned: (ClipboardItem) -> Void
    let onToggleFavorited: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.type == .image {
                if let imagePath = item.imagePath {
                    ThumbnailImageView(path: imagePath)
                }
            } else if item.type == .file {
                fileIcon
            }

            VStack(alignment: .leading, spacing: 6) {
                switch item.type {
                case .text:
                    Text(item.textContent ?? "")
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 13))

                case .image:
                    Text(AppText.value(.popupImageLabel, language: language))
                        .font(.system(size: 13, weight: .semibold))

                case .file:
                    Text(item.displayTitle(for: language))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 13, weight: .semibold))
                }

                if let subtitle = item.displaySubtitle(for: language) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Text(RelativeTime.string(from: item.createdAt))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .layoutPriority(0)
                    }
                } else {
                    Text(RelativeTime.string(from: item.createdAt))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    if item.isFavorited {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

            }
            .padding(.trailing, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? selectedRowFillColor : rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? selectedRowStrokeColor : rowStrokeColor, lineWidth: 1)
        )
        .overlay {
            SecondaryClickCaptureView(
                onSecondaryClick: {
                    onMenuOpen(item)
                },
                onHoverChanged: { isHovering in
                    onHoverChanged(item, isHovering)
                }
            )
        }
        .overlay(alignment: .bottomTrailing) {
            menuButton
                .padding(.trailing, 4)
                .padding(.bottom, 4)
        }
        .contextMenu {
            rowMenuItems
        }
    }

    private var menuButton: some View {
        Menu {
            rowMenuItems
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16, alignment: .center)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .simultaneousGesture(
            TapGesture().onEnded {
                onMenuOpen(item)
            }
        )
        .accessibilityLabel(AppText.value(.popupMoreActions, language: language))
    }

    @ViewBuilder
    private var rowMenuItems: some View {
        Button(AppText.value(.popupCopy, language: language)) {
            onCopy(item)
        }
        .onDisappear {
            onMenuClose()
        }

        if hasOpenAction {
            Button(AppText.value(.popupOpen, language: language)) {
                onOpen(item)
            }
            .onDisappear {
                onMenuClose()
            }
        }

        if hasShareAction {
            shareAction
            Divider()
        }

        Button(item.isPinned ? AppText.value(.popupUnpin, language: language) : AppText.value(.popupPin, language: language)) {
            onTogglePinned(item)
        }

        Button(item.isFavorited ? AppText.value(.popupUnfavorite, language: language) : AppText.value(.popupFavorite, language: language)) {
            onToggleFavorited(item)
        }

        Divider()

        Button(role: .destructive) {
            onDelete(item)
        } label: {
            Text(AppText.value(.popupDelete, language: language))
        }
    }

    private var rowBackgroundColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.21, green: 0.22, blue: 0.25, alpha: 0.86)
                }
                return NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            }
        )
    }

    private var rowStrokeColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor.white.withAlphaComponent(0.06)
                }
                return NSColor.black.withAlphaComponent(0.08)
            }
        )
    }

    private var selectedRowFillColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.31, green: 0.35, blue: 0.42, alpha: 0.54)
                }
                return NSColor(srgbRed: 0.42, green: 0.5, blue: 0.62, alpha: 0.24)
            }
        )
    }

    private var selectedRowStrokeColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.48, green: 0.56, blue: 0.68, alpha: 0.9)
                }
                return NSColor(srgbRed: 0.34, green: 0.45, blue: 0.6, alpha: 0.86)
            }
        )
    }

    private var hasShareAction: Bool {
        switch item.type {
        case .text:
            return !(item.textContent?.isEmpty ?? true)
        case .image:
            return item.imagePath != nil
        case .file:
            return !item.fileURLs.isEmpty
        }
    }

    private var hasOpenAction: Bool {
        item.type == .file && !item.fileURLs.isEmpty
    }

    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    Color(
                        nsColor: NSColor(name: nil) { appearance in
                            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                                return NSColor(srgbRed: 0.30, green: 0.4, blue: 0.58, alpha: 0.9)
                            }
                            return NSColor(srgbRed: 0.73, green: 0.79, blue: 0.9, alpha: 1)
                        }
                    )
                )
                .frame(width: 36, height: 36)
            Image(systemName: "doc.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var shareAction: some View {
        Button(AppText.value(.popupShare, language: language)) {
            onShare(item)
        }
    }
}

private struct SecondaryClickCaptureView: NSViewRepresentable {
    let onSecondaryClick: () -> Void
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> SecondaryClickCaptureNSView {
        let view = SecondaryClickCaptureNSView()
        view.onSecondaryClick = onSecondaryClick
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: SecondaryClickCaptureNSView, context: Context) {
        nsView.onSecondaryClick = onSecondaryClick
        nsView.onHoverChanged = onHoverChanged
    }
}

private final class SecondaryClickCaptureNSView: NSView {
    var onSecondaryClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isPointerInside = false
    private var menuObserver: NSObjectProtocol?

    deinit {
        if let menuObserver {
            NotificationCenter.default.removeObserver(menuObserver)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let menuObserver {
            NotificationCenter.default.removeObserver(menuObserver)
            self.menuObserver = nil
        }

        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshHoverStateFromPointer()
        }
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseEnteredAndExited,
            .mouseMoved,
            .inVisibleRect
        ]

        let newTrackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea

        super.updateTrackingAreas()
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondaryClick?()
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            onSecondaryClick?()
        }
        super.mouseDown(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        setHover(true)
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        setHover(false)
        super.mouseExited(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        refreshHoverStateFromPointer()
        super.mouseMoved(with: event)
    }

    private func refreshHoverStateFromPointer() {
        guard let window else {
            setHover(false)
            return
        }

        let locationInWindow = window.mouseLocationOutsideOfEventStream
        let locationInView = convert(locationInWindow, from: nil)
        setHover(bounds.contains(locationInView))
    }

    private func setHover(_ isInside: Bool) {
        guard isPointerInside != isInside else {
            return
        }

        isPointerInside = isInside
        onHoverChanged?(isInside)
    }
}

private struct ThumbnailImageView: View {
    let path: String

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(rowBackgroundColor)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(.circular)
                    )
            }
        }
        .frame(width: 64, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            guard image == nil else {
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let loadedImage = ThumbnailProvider.thumbnail(for: path)
                DispatchQueue.main.async {
                    image = loadedImage
                }
            }
        }
    }

    private var rowBackgroundColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.2, green: 0.2, blue: 0.21, alpha: 1)
                }
                return NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            }
        )
    }
}

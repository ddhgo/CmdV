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
                onMenuClose: {
                    onMenuClose()
                },
                onHoverChanged: { isHovering in
                    onHoverChanged(item, isHovering)
                }
            )
        }
        .overlay(alignment: .bottomTrailing) {
            menuButton
                .padding(.trailing, 7)
                .padding(.bottom, 7)
        }
        .contextMenu {
            rowMenuItems
        }
    }

    private var menuButton: some View {
        Menu {
            rowMenuItems
        } label: {
            Image(systemName: "ellipsis")
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
        if hasOpenAction {
            Button(AppText.value(.popupOpen, language: language)) {
                onOpen(item)
            }
            .onDisappear {
                onMenuClose()
            }
            Divider()
        }

        Button(AppText.value(.popupCopy, language: language)) {
            onCopy(item)
        }
        .onDisappear {
            onMenuClose()
        }

        if hasShareAction {
            shareAction
                .onDisappear {
                    onMenuClose()
                }
        }

        if hasOpenAction || hasShareAction {
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
        CmdVTheme.Colors.rowSurface
    }

    private var rowStrokeColor: Color {
        CmdVTheme.Colors.subtleStroke
    }

    private var selectedRowFillColor: Color {
        CmdVTheme.Colors.rowSelectedSurface
    }

    private var selectedRowStrokeColor: Color {
        CmdVTheme.Colors.rowSelectedStroke
    }

    /// Whether the Share menu item should appear for this item.
    ///
    /// Share requires actual content: non-empty text, a stored image file, or
    /// at least one resolved file URL.  Items without content (e.g. an image
    /// whose file has been deleted) are excluded to avoid presenting a share
    /// sheet that would immediately fail.
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

    /// Whether the Open menu item should appear for this item.
    ///
    /// Only file-type items with at least one resolvable URL support "Open in
    /// Finder / default app".  Text and image items are excluded because they
    /// have no meaningful file-system location to open.
    private var hasOpenAction: Bool {
        item.type == .file && !item.fileURLs.isEmpty
    }

    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    CmdVTheme.Colors.controlSurface
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
    let onMenuClose: () -> Void
    let onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> SecondaryClickCaptureNSView {
        let view = SecondaryClickCaptureNSView()
        view.onSecondaryClick = onSecondaryClick
        view.onMenuClose = onMenuClose
        view.onHoverChanged = onHoverChanged
        return view
    }

    func updateNSView(_ nsView: SecondaryClickCaptureNSView, context: Context) {
        nsView.onSecondaryClick = onSecondaryClick
        nsView.onMenuClose = onMenuClose
        nsView.onHoverChanged = onHoverChanged
    }
}

private final class SecondaryClickCaptureNSView: NSView {
    var onSecondaryClick: (() -> Void)?
    var onMenuClose: (() -> Void)?
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
            self?.onMenuClose?()
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
            return
        }

        if let nextResponder {
            nextResponder.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
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

    /// Re-evaluates whether the pointer is inside this view by converting the
    /// current mouse location from window coordinates to view-local bounds.
    ///
    /// Called after a context menu closes (via `NSMenu.didEndTrackingNotification`)
    /// and on `mouseMoved` events.  These two sites cover the case where the
    /// system skips `mouseEntered`/`mouseExited` events while a menu is
    /// tracking, leaving `isPointerInside` stale after the menu dismisses.
    private func refreshHoverStateFromPointer() {
        guard let window else {
            setHover(false)
            return
        }

        let locationInWindow = window.mouseLocationOutsideOfEventStream
        let locationInView = convert(locationInWindow, from: nil)
        setHover(bounds.contains(locationInView))
    }

    /// Updates the stored hover state and notifies the callback only when the
    /// state actually changes.
    ///
    /// The guard prevents redundant `onHoverChanged` calls when the tracking
    /// area fires multiple enter/exit events in quick succession (e.g. when
    /// the view is scrolled under the pointer or when `refreshHoverStateFromPointer`
    /// is called from both `mouseMoved` and `NSMenu.didEndTrackingNotification`).
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
                .stroke(CmdVTheme.Colors.subtleStroke, lineWidth: 1)
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
        CmdVTheme.Colors.controlSurface
    }
}

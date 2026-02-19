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
    let onCopy: (ClipboardItem) -> Void
    let onShare: (ClipboardItem) -> Void
    let onTogglePinned: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.type == .image {
                if let imagePath = item.imagePath {
                    ThumbnailImageView(path: imagePath)
                }
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
                }

                if let sourceBundleID = item.sourceBundleID {
                    Text(sourceBundleID)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(RelativeTime.string(from: item.createdAt))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
        .accessibilityLabel(AppText.value(.popupMoreActions, language: language))
    }

    @ViewBuilder
    private var rowMenuItems: some View {
        Button(AppText.value(.popupCopy, language: language)) {
            onCopy(item)
        }
        .onAppear {
            onMenuOpen(item)
        }

        if hasShareAction {
            shareAction
            Divider()
        }

        Button(item.isPinned ? AppText.value(.popupUnpin, language: language) : AppText.value(.popupPin, language: language)) {
            onTogglePinned(item)
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
                    return NSColor(srgbRed: 0.2, green: 0.21, blue: 0.24, alpha: 1)
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
                    return NSColor(srgbRed: 0.2, green: 0.34, blue: 0.54, alpha: 0.45)
                }
                return NSColor(srgbRed: 0.36, green: 0.56, blue: 0.92, alpha: 0.24)
            }
        )
    }

    private var selectedRowStrokeColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.2, green: 0.56, blue: 0.92, alpha: 0.86)
                }
                return NSColor(srgbRed: 0.2, green: 0.44, blue: 0.82, alpha: 0.86)
            }
        )
    }

    private var hasShareAction: Bool {
        switch item.type {
        case .text:
            return !(item.textContent?.isEmpty ?? true)
        case .image:
            return item.imagePath != nil
        }
    }

    @ViewBuilder
    private var shareAction: some View {
        Button(AppText.value(.popupShare, language: language)) {
            onShare(item)
        }
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

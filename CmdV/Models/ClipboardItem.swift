import Foundation

enum ClipboardItemType: String {
    case text
    case image
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
}

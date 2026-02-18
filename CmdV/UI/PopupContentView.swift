import SwiftUI

struct PopupContentView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onConfirm: (ClipboardItem) -> Void
    let onCopyOnly: (ClipboardItem) -> Void

    @FocusState private var searchFocused: Bool
    @State private var hoveredItemID: Int64?
    @State private var contextMenuItemID: Int64?

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.showsPermissionBanner {
                permissionBanner
            }

            searchBar
            dividerLine
            contentList
        }
        .padding(14)
        .frame(minWidth: PopupLayout.minimumWidth, minHeight: PopupLayout.minimumHeight)
        .background(popupBackgroundColor)
        .onAppear {
            viewModel.selectFirstIfNeeded()
            searchFocused = true
            hoveredItemID = nil
            contextMenuItemID = nil
        }
        .onReceive(viewModel.$searchFocusRequestToken) { _ in
            searchFocused = true
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)

                Text(AppText.value(.popupPermissionBanner, language: viewModel.appLanguage))
                    .font(.caption)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: viewModel.dismissPermissionBanner) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Dismiss permission banner")
            }

            HStack(spacing: 8) {
                Button(AppText.value(.popupRequest, language: viewModel.appLanguage)) {
                    viewModel.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(AppText.value(.popupOpenSettings, language: viewModel.appLanguage)) {
                    viewModel.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.leading, 22)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.15))
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(AppText.value(.popupSearchPlaceholder, language: viewModel.appLanguage), text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFocused)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.resetSearch()
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(popupSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(popupDividerColor)
            .frame(height: 1)
    }

    private var contentList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.filteredItems.isEmpty {
                    VStack(spacing: 6) {
                        Text(AppText.value(.popupNoClipboardItems, language: viewModel.appLanguage))
                            .font(.headline)
                        Text(AppText.value(.popupNoClipboardSubtitle, language: viewModel.appLanguage))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.filteredItems) { item in
                            HistoryRowView(
                                item: item,
                                isSelected: isRowSelected(itemID: item.id),
                                language: viewModel.appLanguage,
                                onMenuOpen: { openedItem in
                                    contextMenuItemID = openedItem.id
                                },
                                onCopy: { copiedItem in
                                    selectForRowAction(copiedItem)
                                    onCopyOnly(copiedItem)
                                },
                                onTogglePinned: { toggledItem in
                                    selectForRowAction(toggledItem)
                                    viewModel.togglePinned(itemID: toggledItem.id)
                                },
                                onDelete: { deletedItem in
                                    selectForRowAction(deletedItem)
                                    viewModel.delete(itemID: deletedItem.id)
                                }
                            )
                                .contentShape(Rectangle())
                                .onHover { isHovering in
                                    if isHovering {
                                        hoveredItemID = item.id
                                        contextMenuItemID = nil
                                    }
                                }
                                .onTapGesture {
                                    viewModel.selectedItemID = item.id
                                    hoveredItemID = nil
                                    contextMenuItemID = nil
                                    onConfirm(item)
                                }
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .onReceive(viewModel.$selectedItemID) { selectedID in
                guard let selectedID else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }

    private func selectForRowAction(_ item: ClipboardItem) {
        viewModel.selectedItemID = item.id
        hoveredItemID = nil
        contextMenuItemID = nil
    }

    private func isRowSelected(itemID: Int64) -> Bool {
        if let hoveredItemID {
            return hoveredItemID == itemID
        }

        if let contextMenuItemID {
            return contextMenuItemID == itemID
        }

        return viewModel.selectedItemID == itemID
    }

    private var popupBackgroundColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.22, green: 0.22, blue: 0.23, alpha: 1)
                }
                return NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
            }
        )
    }

    private var popupSurfaceColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.19, green: 0.19, blue: 0.2, alpha: 1)
                }
                return NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            }
        )
    }

    private var popupDividerColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor.white.withAlphaComponent(0.1)
                }
                return NSColor.black.withAlphaComponent(0.08)
            }
        )
    }
}

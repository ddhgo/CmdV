import AppKit
import SwiftUI

struct PopupContentView: View {
    @ObservedObject var viewModel: PopupViewModel

    let onConfirm: (ClipboardItem) -> Void
    let onCopyOnly: (ClipboardItem) -> Void
    let onShare: (ClipboardItem) -> Void

    @FocusState private var searchFocused: Bool
    @State private var contextMenuItemID: Int64?
    @State private var hoveredItemID: Int64?
    @State private var contextMenuActive = false
    @State private var allowSelectedFallbackHighlight = false
    @State private var lastExplicitSelectionToken = 0
    private let popupCornerRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.isRecordingPaused {
                recordingDisabledBanner
            }

            if viewModel.showsPermissionBanner {
                permissionBanner
            }

            searchHeader
            dividerLine
            contentList
        }
        .padding(12)
        .frame(minWidth: PopupLayout.minimumWidth, minHeight: PopupLayout.minimumHeight)
        .background(
            RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous)
                .fill(popupBackgroundColor)
        )
        .onAppear {
            contextMenuItemID = nil
            hoveredItemID = nil
            contextMenuActive = false
            allowSelectedFallbackHighlight = false
            lastExplicitSelectionToken = viewModel.explicitSelectionToken
            viewModel.selectFirstIfNeeded()
            searchFocused = true
        }
        .onReceive(viewModel.$searchFocusRequestToken) { _ in
            searchFocused = true
        }
        .onReceive(viewModel.$explicitSelectionToken) { token in
            guard token != lastExplicitSelectionToken else {
                return
            }

            lastExplicitSelectionToken = token
            allowSelectedFallbackHighlight = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
            guard contextMenuActive || contextMenuItemID != nil else {
                return
            }

            contextMenuActive = false
            contextMenuItemID = nil
        }
    }

    private var recordingDisabledBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)

            Text(AppText.value(.popupRecordingDisabledBanner, language: viewModel.appLanguage))
                .font(.caption)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
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
                .accessibilityLabel(
                    AppText.value(.popupDismissPermissionBannerA11y, language: viewModel.appLanguage)
                )
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            searchBar

            HStack(spacing: 8) {
                clearAllButton
                favoritesTabButton
            }
            .frame(width: 136, alignment: .trailing)
            .layoutPriority(2)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            brandMark

            TextField(AppText.value(.popupSearchPlaceholder, language: viewModel.appLanguage), text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .frame(maxWidth: .infinity)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.resetSearch()
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    AppText.value(.popupClearSearchA11y, language: viewModel.appLanguage)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(popupSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(searchBarBorderColor, lineWidth: 1)
        )
        .layoutPriority(0)
    }

    private var clearAllButton: some View {
        Button {
            viewModel.clearCurrentTab()
        } label: {
            Text(viewModel.activeTab == .favorites ? AppText.value(.popupClearFavorites, language: viewModel.appLanguage) : AppText.value(.popupClear, language: viewModel.appLanguage))
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(width: 88, height: 36)
                .foregroundStyle(Color.primary.opacity(0.95))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(popupSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(searchBarBorderColor, lineWidth: 1)
        )
        .accessibilityLabel(
            viewModel.activeTab == .favorites
                ? AppText.value(.popupClearFavorites, language: viewModel.appLanguage)
                : AppText.value(.popupClear, language: viewModel.appLanguage)
        )
    }

    private var favoritesTabButton: some View {
        Button {
            viewModel.toggleFavoritesTab()
        } label: {
            Image(systemName: viewModel.activeTab == .favorites ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.activeTab == .favorites ? Color.white : .secondary.opacity(0.9))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(viewModel.activeTab == .favorites ? selectedRowStrokeColor : popupSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(searchBarBorderColor, lineWidth: 1)
        )
        .accessibilityLabel(AppText.value(.popupFavoritesTab, language: viewModel.appLanguage))
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
                        Text(AppText.value(
                            viewModel.activeTab == .favorites ? .popupNoFavorites : .popupNoClipboardItems,
                            language: viewModel.appLanguage
                        ))
                            .font(.headline)
                        Text(AppText.value(
                            viewModel.activeTab == .favorites ? .popupNoFavoritesSubtitle : .popupNoClipboardSubtitle,
                            language: viewModel.appLanguage
                        ))
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
                                    hoveredItemID = openedItem.id
                                    contextMenuActive = true
                                    allowSelectedFallbackHighlight = true
                                },
                                onMenuClose: {
                                    contextMenuActive = false
                                    contextMenuItemID = nil
                                },
                                onHoverChanged: { hoveredItem, isHovering in
                                    if isHovering {
                                        if contextMenuActive {
                                            contextMenuActive = false
                                            contextMenuItemID = nil
                                        }

                                        hoveredItemID = hoveredItem.id
                                        // Hover-driven highlight should not fall back to keyboard selection,
                                        // otherwise row transitions can briefly jump to selectedItemID.
                                        allowSelectedFallbackHighlight = false
                                    } else if !contextMenuActive, hoveredItemID == hoveredItem.id {
                                        let exitingItemID = hoveredItem.id
                                        DispatchQueue.main.async {
                                            guard !contextMenuActive, hoveredItemID == exitingItemID else {
                                                return
                                            }

                                            hoveredItemID = nil
                                        }
                                    }
                                },
                                onCopy: { copiedItem in
                                    selectForRowAction(copiedItem)
                                    onCopyOnly(copiedItem)
                                },
                                onShare: { sharedItem in
                                    selectForRowAction(sharedItem)
                                    onShare(sharedItem)
                                },
                                onOpen: { openedItem in
                                    selectForRowAction(openedItem)
                                    viewModel.openItem(openedItem)
                                },
                                onTogglePinned: { toggledItem in
                                    selectForRowAction(toggledItem)
                                    viewModel.togglePinned(itemID: toggledItem.id)
                                },
                                onToggleFavorited: { toggledItem in
                                    selectForRowAction(toggledItem)
                                    viewModel.toggleFavorited(itemID: toggledItem.id)
                                },
                                onDelete: { deletedItem in
                                    selectForRowAction(deletedItem)
                                    if hoveredItemID == deletedItem.id {
                                        hoveredItemID = nil
                                    }
                                    contextMenuItemID = nil
                                    contextMenuActive = false
                                    allowSelectedFallbackHighlight = true
                                    viewModel.delete(itemID: deletedItem.id)
                                }
                            )
                                .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedItemID = item.id
                                contextMenuItemID = nil
                                hoveredItemID = item.id
                                allowSelectedFallbackHighlight = true
                                    onConfirm(item)
                                }
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 2)
            .onReceive(viewModel.$selectedItemID) { selectedID in
                guard let selectedID else {
                    return
                }

                guard allowSelectedFallbackHighlight || contextMenuActive else {
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
        contextMenuItemID = nil
        hoveredItemID = item.id
        contextMenuActive = false
        allowSelectedFallbackHighlight = true
    }

    private func isRowSelected(itemID: Int64) -> Bool {
        let visibleItemIDs = viewModel.filteredItems.map(\.id)

        if contextMenuActive, let contextMenuItemID {
            guard visibleItemIDs.contains(contextMenuItemID) else {
                return false
            }

            return contextMenuItemID == itemID
        }

        if let hoveredItemID {
            guard visibleItemIDs.contains(hoveredItemID) else {
                return false
            }

            return hoveredItemID == itemID
        }

        if let contextMenuItemID {
            guard visibleItemIDs.contains(contextMenuItemID) else {
                return false
            }

            return contextMenuItemID == itemID
        }

        if allowSelectedFallbackHighlight, let selectedItemID = viewModel.selectedItemID {
            return selectedItemID == itemID
        }

        return false
    }

    private var popupBackgroundColor: Color {
        CmdVTheme.Colors.windowSurface
    }

    private var popupSurfaceColor: Color {
        CmdVTheme.Colors.controlSurface
    }

    private var popupDividerColor: Color {
        CmdVTheme.Colors.subtleStroke
    }

    private var searchBarBorderColor: Color {
        CmdVTheme.Colors.subtleStroke
    }

    private var selectedRowStrokeColor: Color {
        CmdVTheme.Colors.rowSelectedStroke
    }

    @ViewBuilder
    private var brandMark: some View {
        if let image = popupBrandImage {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(width: 20, height: 20)
        }
    }

    private var popupBrandImage: NSImage? {
        NSImage(named: "CmdVMainLogo") ?? NSImage(named: "CmdVMenuBarTemplate")
    }
}

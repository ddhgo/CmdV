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

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.isRecordingPaused {
                recordingDisabledBanner
            }

            if viewModel.showsPermissionBanner {
                permissionBanner
            }

            searchBar
            dividerLine
            contentList
        }
        .padding(12)
        .frame(minWidth: PopupLayout.minimumWidth, minHeight: PopupLayout.minimumHeight)
        .background(popupBackgroundColor)
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
                                    hoveredItemID = openedItem.id
                                    contextMenuActive = true
                                    allowSelectedFallbackHighlight = true
                                },
                                onMenuClose: {
                                    contextMenuActive = false
                                    contextMenuItemID = nil
                                },
                                onCopy: { copiedItem in
                                    selectForRowAction(copiedItem)
                                    onCopyOnly(copiedItem)
                                },
                                onShare: { sharedItem in
                                    selectForRowAction(sharedItem)
                                    onShare(sharedItem)
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
                                .onTapGesture {
                                    viewModel.selectedItemID = item.id
                                    contextMenuItemID = nil
                                    hoveredItemID = item.id
                                    allowSelectedFallbackHighlight = true
                                    onConfirm(item)
                                }
                                .onHover { isHovering in
                                    if contextMenuActive {
                                        return
                                    }

                                    if isHovering {
                                        hoveredItemID = item.id
                                        allowSelectedFallbackHighlight = true
                                    }
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
        if contextMenuActive, let contextMenuItemID {
            return contextMenuItemID == itemID
        }

        if let hoveredItemID {
            return hoveredItemID == itemID
        }

        if let contextMenuItemID {
            return contextMenuItemID == itemID
        }

        if allowSelectedFallbackHighlight, let selectedItemID = viewModel.selectedItemID {
            return selectedItemID == itemID
        }

        return false
    }

    private var popupBackgroundColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.17, green: 0.18, blue: 0.21, alpha: 1)
                }
                return NSColor(srgbRed: 0.94, green: 0.95, blue: 0.97, alpha: 1)
            }
        )
    }

    private var popupSurfaceColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.2, green: 0.21, blue: 0.25, alpha: 1)
                }
                return NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 1)
            }
        )
    }

    private var popupDividerColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor.white.withAlphaComponent(0.12)
                }
                return NSColor.black.withAlphaComponent(0.1)
            }
        )
    }

    private var searchBarBorderColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor.white.withAlphaComponent(0.08)
                }
                return NSColor.black.withAlphaComponent(0.08)
            }
        )
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

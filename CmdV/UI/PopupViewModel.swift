import Combine
import AppKit
import Foundation

enum PopupListTab {
    case history
    case favorites
}

final class PopupViewModel: ObservableObject {
    @Published private(set) var allItems: [ClipboardItem] = []
    @Published var searchQuery: String = "" {
        didSet {
            ensureSelectionValid()
        }
    }
    @Published var activeTab: PopupListTab = .history {
        didSet {
            historyStore.setScopeForFavoritesOnly(activeTab == .favorites)
            ensureSelectionValid(forceSelectFirst: true)
        }
    }
    @Published var selectedItemID: Int64?
    @Published private(set) var isRecordingPaused: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var showsPermissionBanner: Bool = false
    @Published private(set) var appLanguage: AppLanguage = .korean
    @Published var searchFocusRequestToken: Int = 0
    @Published var explicitSelectionToken: Int = 0

    private let historyStore: HistoryStore
    private let settings: SettingsStore
    private let permissions: PermissionsService
    private var cancellables: Set<AnyCancellable> = []
    private var pendingSelectionAfterDeleteIndex: Int?
    private var pendingSelectionAfterDeleteID: Int64?

    init(
        historyStore: HistoryStore,
        settings: SettingsStore,
        permissions: PermissionsService
    ) {
        self.historyStore = historyStore
        self.settings = settings
        self.permissions = permissions

        historyStore.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.allItems = items
                self?.ensureSelectionValid()
            }
            .store(in: &cancellables)

        settings.$isRecordingPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaused in
                self?.isRecordingPaused = isPaused
            }
            .store(in: &cancellables)

        settings.$appLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] language in
                self?.appLanguage = language
            }
            .store(in: &cancellables)

        permissions.$accessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                self?.accessibilityGranted = granted
                if granted {
                    self?.showsPermissionBanner = false
                }
            }
            .store(in: &cancellables)

        appLanguage = settings.appLanguage
    }

    var filteredItems: [ClipboardItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return allItems
        }

        return allItems.filter { item in
            switch item.type {
            case .text:
                return item.textContent?.localizedCaseInsensitiveContains(query) ?? false
            case .image:
                return AppText.imageSearchTokens(language: appLanguage)
                    .contains(where: { $0.localizedCaseInsensitiveContains(query) })
            case .file:
                return item.fileURLs.contains { url in
                    let fileName = url.lastPathComponent
                    return fileName.localizedCaseInsensitiveContains(query)
                        || url.path.localizedCaseInsensitiveContains(query)
                }
            }
        }
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else {
            return filteredItems.first
        }

        return filteredItems.first(where: { $0.id == selectedItemID })
    }

    func selectFirstIfNeeded() {
        ensureSelectionValid(forceSelectFirst: true)
    }

    func selectPrevious() {
        let items = filteredItems
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }

        guard
            let selectedItemID,
            let currentIndex = items.firstIndex(where: { $0.id == selectedItemID })
        else {
            self.selectedItemID = items.first?.id
            markSelectionExplicit()
            return
        }

        let newIndex = max(currentIndex - 1, 0)
        self.selectedItemID = items[newIndex].id
        markSelectionExplicit()
    }

    func selectNext() {
        let items = filteredItems
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }

        guard
            let selectedItemID,
            let currentIndex = items.firstIndex(where: { $0.id == selectedItemID })
        else {
            self.selectedItemID = items.first?.id
            markSelectionExplicit()
            return
        }

        let newIndex = min(currentIndex + 1, items.count - 1)
        self.selectedItemID = items[newIndex].id
        markSelectionExplicit()
    }

    func deleteSelected() {
        guard let selectedItemID else {
            return
        }

        delete(itemID: selectedItemID)
    }

    func togglePinnedSelected() {
        guard let selectedItem else {
            return
        }

        togglePinned(itemID: selectedItem.id)
    }

    func delete(itemID: Int64) {
        let itemsBeforeDelete = filteredItems
        let fallbackSelectionIndex = fallbackSelectionIndex(afterDeleting: itemID, from: itemsBeforeDelete)
        pendingSelectionAfterDeleteIndex = fallbackSelectionIndex

        var immediateSelectionID: Int64?
        if let fallbackSelectionIndex,
           itemsBeforeDelete.indices.contains(fallbackSelectionIndex) {
            pendingSelectionAfterDeleteID = itemsBeforeDelete[fallbackSelectionIndex].id
            immediateSelectionID = pendingSelectionAfterDeleteID
        } else if itemsBeforeDelete.count > 1 {
            immediateSelectionID = itemsBeforeDelete.first(where: { $0.id != itemID })?.id
            pendingSelectionAfterDeleteID = immediateSelectionID
        } else {
            pendingSelectionAfterDeleteID = nil
        }

        selectedItemID = immediateSelectionID

        historyStore.delete(itemID: itemID)
        markSelectionExplicit()
    }

    /// Returns the list index that should receive focus after `itemID` is deleted
    /// from `items`.
    ///
    /// Priority:
    /// 1. The item immediately *below* the deleted row (same visual position).
    /// 2. The item immediately *above* when the deleted row was the last one.
    /// 3. `nil` when the list will be empty after deletion.
    private func fallbackSelectionIndex(afterDeleting itemID: Int64, from items: [ClipboardItem]) -> Int? {
        guard let deletedIndex = items.firstIndex(where: { $0.id == itemID }) else {
            return nil
        }

        let remainingCount = items.count - 1
        guard remainingCount > 0 else {
            return nil
        }

        if deletedIndex < items.count - 1 {
            return deletedIndex
        }

        return deletedIndex - 1
    }

    func openItem(_ item: ClipboardItem) {
        guard item.type == .file else {
            return
        }

        let urls = item.fileURLs
        guard !urls.isEmpty else {
            return
        }

        urls.forEach { url in
            NSWorkspace.shared.open(url)
        }
    }

    func togglePinned(itemID: Int64) {
        guard let item = allItems.first(where: { $0.id == itemID }) else {
            return
        }

        historyStore.setPinned(itemID: itemID, isPinned: !item.isPinned)
    }

    func toggleFavorited(itemID: Int64) {
        guard let item = allItems.first(where: { $0.id == itemID }) else {
            return
        }

        historyStore.setFavorited(itemID: itemID, isFavorited: !item.isFavorited)
    }

    func toggleFavoritesTab() {
        activeTab = (activeTab == .history) ? .favorites : .history
    }

    func clearHistory() {
        historyStore.clearHistory()
    }

    func clearCurrentTab() {
        clearPendingSelection()
        if activeTab == .favorites {
            historyStore.unfavoriteAllItems()
            return
        }

        historyStore.clearHistory()
    }

    func togglePauseRecording() {
        settings.isRecordingPaused.toggle()
    }

    func requestSearchFocus() {
        searchFocusRequestToken += 1
    }

    func resetSearch() {
        searchQuery = ""
    }

    func requestAccessibilityPermission() {
        permissions.requestAccessibilityPermission()
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    func refreshPermissions() {
        permissions.refreshStatus()
    }

    func showPermissionBannerIfNeeded() {
        guard !accessibilityGranted else {
            showsPermissionBanner = false
            return
        }

        showsPermissionBanner = true
    }

    func dismissPermissionBanner() {
        showsPermissionBanner = false
    }

    /// Reconciles `selectedItemID` with the current `filteredItems` list.
    ///
    /// Called whenever the item list or search query changes so the highlighted
    /// row stays consistent.  If a delete-pending state exists it is resolved
    /// first: the stored target ID is preferred, falling back to the stored
    /// index, and finally to the first visible item.  When `forceSelectFirst`
    /// is `true` (e.g. after a tab switch) the first item is always selected
    /// regardless of existing selection state.
    private func ensureSelectionValid(forceSelectFirst: Bool = false) {
        let visibleItems = filteredItems

        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            pendingSelectionAfterDeleteID = nil
            pendingSelectionAfterDeleteIndex = nil
            return
        }

        let hasPendingDeleteSelection = pendingSelectionAfterDeleteID != nil || pendingSelectionAfterDeleteIndex != nil
        if hasPendingDeleteSelection {
            if let pendingSelectionAfterDeleteID,
               visibleItems.contains(where: { $0.id == pendingSelectionAfterDeleteID }) {
                selectedItemID = pendingSelectionAfterDeleteID
            } else if let pendingSelectionAfterDeleteIndex {
                let boundedIndex = min(
                    max(pendingSelectionAfterDeleteIndex, 0),
                    visibleItems.count - 1
                )
                selectedItemID = visibleItems[boundedIndex].id
            } else {
                selectedItemID = visibleItems.first?.id
            }

            pendingSelectionAfterDeleteIndex = nil
            pendingSelectionAfterDeleteID = nil
            return
        }

        pendingSelectionAfterDeleteIndex = nil

        if forceSelectFirst {
            selectedItemID = visibleItems.first?.id
            return
        }

        if let selectedItemID,
           visibleItems.contains(where: { $0.id == selectedItemID })
        {
            return
        }

        selectedItemID = visibleItems.first?.id
    }

    /// Increments `explicitSelectionToken` to signal that the selection was
    /// driven by a keyboard or row action rather than an implicit list update.
    ///
    /// `PopupContentView` observes this token and enables the fallback highlight
    /// path (`allowSelectedFallbackHighlight`) only after an explicit action,
    /// preventing spurious scroll jumps when the list refreshes in the background.
    private func markSelectionExplicit() {
        explicitSelectionToken += 1
    }

    /// Resets all pending-delete selection state and clears the current
    /// selection.  Called before bulk-clear operations (e.g. "Clear All") so
    /// `ensureSelectionValid` starts from a clean slate rather than trying to
    /// restore a stale post-delete position.
    private func clearPendingSelection() {
        pendingSelectionAfterDeleteID = nil
        pendingSelectionAfterDeleteIndex = nil
        selectedItemID = nil
        markSelectionExplicit()
    }
}

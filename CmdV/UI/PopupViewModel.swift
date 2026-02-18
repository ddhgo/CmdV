import Combine
import Foundation

final class PopupViewModel: ObservableObject {
    @Published private(set) var allItems: [ClipboardItem] = []
    @Published var searchQuery: String = "" {
        didSet {
            ensureSelectionValid()
        }
    }
    @Published var selectedItemID: Int64?
    @Published private(set) var isRecordingPaused: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var showsPermissionBanner: Bool = false
    @Published private(set) var appLanguage: AppLanguage = .english
    @Published var searchFocusRequestToken: Int = 0

    private let historyStore: HistoryStore
    private let settings: SettingsStore
    private let permissions: PermissionsService
    private var cancellables: Set<AnyCancellable> = []

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
            return
        }

        let newIndex = max(currentIndex - 1, 0)
        self.selectedItemID = items[newIndex].id
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
            return
        }

        let newIndex = min(currentIndex + 1, items.count - 1)
        self.selectedItemID = items[newIndex].id
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
        historyStore.delete(itemID: itemID)
    }

    func togglePinned(itemID: Int64) {
        guard let item = allItems.first(where: { $0.id == itemID }) else {
            return
        }

        historyStore.setPinned(itemID: itemID, isPinned: !item.isPinned)
    }

    func clearHistory() {
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

    private func ensureSelectionValid(forceSelectFirst: Bool = false) {
        let visibleItems = filteredItems

        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            return
        }

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
}

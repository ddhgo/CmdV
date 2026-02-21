import AppKit
import Foundation
import OSLog
import ServiceManagement

enum LaunchAtLoginFeedback: Equatable {
    case enabled
    case disabled
    case failed(String)
}

final class SettingsStore: ObservableObject {
    private static let supportedHotkeyModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
    private static let hotkeyModifierOrder: [NSEvent.ModifierFlags] = [.command, .option, .control, .shift]
    static let maxHistoryItemsRange: ClosedRange<Int> = 20...1000
    static let maxHistoryItemsUIStepperRange: ClosedRange<Int> = 50...1000
    static let maxHistoryItemsStep = 10

    static let pollingIntervalClampRange: ClosedRange<Double> = 0.2...2.0
    static let pollingIntervalDisplayRange: ClosedRange<Double> = 0.2...1.5
    static let pollingIntervalStep = 0.1
    private static let maxHotkeyModifiers = 2

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cmdv.app", category: "SettingsStore")
    private let persistenceQueue = DispatchQueue(
        label: "CmdV.SettingsStorePersistenceQueue",
        qos: .utility
    )

    private enum Keys {
        static let maxHistoryItems = "settings.maxHistoryItems"
        static let pollingInterval = "settings.pollingInterval"
        static let isRecordingPaused = "settings.isRecordingPaused"
        static let launchAtLoginEnabled = "settings.launchAtLoginEnabled"
        static let excludedBundleIDsText = "settings.excludedBundleIDsText"
        static let appLanguage = "settings.appLanguage"
        static let clearHistoryOnSystemRestart = "settings.clearHistoryOnSystemRestart"
        static let hotkeyKeyCode = "settings.hotkey.keyCode"
        static let hotkeyModifiersRaw = "settings.hotkey.modifiersRaw"
    }

    private let defaults: UserDefaults
    @Published var maxHistoryItems: Int {
        didSet {
            let clamped = Self.clamp(maxHistoryItems, to: Self.maxHistoryItemsRange)
            if clamped != maxHistoryItems {
                maxHistoryItems = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.maxHistoryItems)
        }
    }

    @Published var pollingInterval: Double {
        didSet {
            let clamped = Self.clamp(pollingInterval, to: Self.pollingIntervalClampRange)
            if clamped != pollingInterval {
                pollingInterval = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.pollingInterval)
        }
    }

    @Published var isRecordingPaused: Bool {
        didSet {
            let newValue = isRecordingPaused
            let defaults = self.defaults
            persistenceQueue.async {
                defaults.set(newValue, forKey: Keys.isRecordingPaused)
            }
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        }
    }

    @Published private(set) var launchAtLoginFeedback: LaunchAtLoginFeedback

    @Published var excludedBundleIDsText: String {
        didSet {
            defaults.set(excludedBundleIDsText, forKey: Keys.excludedBundleIDsText)
        }
    }

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
        }
    }

    @Published var clearHistoryOnSystemRestart: Bool {
        didSet {
            defaults.set(clearHistoryOnSystemRestart, forKey: Keys.clearHistoryOnSystemRestart)
        }
    }

    @Published var hotkey: HotkeyConfiguration {
        didSet {
            defaults.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            defaults.set(Int(hotkey.modifiers.rawValue), forKey: Keys.hotkeyModifiersRaw)
        }
    }

    var excludedBundleIDs: Set<String> {
        let delimiters = CharacterSet.newlines.union(CharacterSet(charactersIn: ","))
        let values = excludedBundleIDsText
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Set(values)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let maxItemsValue = defaults.object(forKey: Keys.maxHistoryItems) as? Int ?? 200
        maxHistoryItems = Self.clamp(maxItemsValue, to: Self.maxHistoryItemsRange)

        let pollingValue = defaults.object(forKey: Keys.pollingInterval) as? Double ?? 0.6
        pollingInterval = Self.clamp(pollingValue, to: Self.pollingIntervalClampRange)

        isRecordingPaused = defaults.object(forKey: Keys.isRecordingPaused) as? Bool ?? false
        let initialLaunchAtLoginEnabled: Bool
        if let storedLaunchAtLoginEnabled = defaults.object(forKey: Keys.launchAtLoginEnabled) as? Bool {
            initialLaunchAtLoginEnabled = storedLaunchAtLoginEnabled
        } else {
            initialLaunchAtLoginEnabled = Self.readSystemLaunchAtLoginEnabled()
        }
        launchAtLoginEnabled = initialLaunchAtLoginEnabled
        launchAtLoginFeedback = initialLaunchAtLoginEnabled ? .enabled : .disabled
        excludedBundleIDsText = defaults.string(forKey: Keys.excludedBundleIDsText) ?? ""
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: Keys.appLanguage) ?? "") ?? .english
        clearHistoryOnSystemRestart = defaults.object(forKey: Keys.clearHistoryOnSystemRestart) as? Bool ?? false

        let keyCode: UInt32
        if let storedKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? Int {
            keyCode = UInt32(storedKeyCode)
        } else {
            keyCode = HotkeyConfiguration.default.keyCode
        }

        let modifiers: NSEvent.ModifierFlags
        if let storedModifiers = defaults.object(forKey: Keys.hotkeyModifiersRaw) as? Int {
            modifiers = NSEvent.ModifierFlags(rawValue: UInt(storedModifiers))
        } else {
            modifiers = HotkeyConfiguration.default.modifiers
        }

        let sanitizedModifiers = Self.sanitizeHotkeyModifiers(modifiers)
        hotkey = HotkeyConfiguration(
            keyCode: keyCode,
            modifiers: sanitizedModifiers.isEmpty ? [.option] : sanitizedModifiers
        )
    }

    func refreshLaunchAtLoginStatus() {
        let isEnabled = Self.readSystemLaunchAtLoginEnabled()
        launchAtLoginEnabled = isEnabled
        launchAtLoginFeedback = isEnabled ? .enabled : .disabled
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            let applied = Self.readSystemLaunchAtLoginEnabled()
            launchAtLoginEnabled = applied
            if applied == enabled {
                launchAtLoginFeedback = applied ? .enabled : .disabled
                return true
            }

            logger.error(
                "Launch-at-login mismatch. requested=\(enabled, privacy: .public) applied=\(applied, privacy: .public)"
            )
            launchAtLoginFeedback = .failed("System launch-at-login status did not match the requested value.")
            return false
        } catch {
            logger.error("Launch-at-login update failed: \(error.localizedDescription, privacy: .public)")
            launchAtLoginEnabled = Self.readSystemLaunchAtLoginEnabled()
            launchAtLoginFeedback = .failed(error.localizedDescription)
            return false
        }
    }

    func setHotkeyKeyCode(_ keyCode: UInt32) {
        hotkey = HotkeyConfiguration(
            keyCode: keyCode,
            modifiers: Self.sanitizeHotkeyModifiers(hotkey.modifiers.intersection(Self.supportedHotkeyModifiers))
        )
    }

    func setHotkeyModifier(_ modifier: NSEvent.ModifierFlags, enabled: Bool) {
        var modifiers = hotkey.modifiers

        if enabled {
            if !modifiers.contains(modifier)
                && Self.hotkeyModifierCount(modifiers) >= Self.maxHotkeyModifiers {
                return
            }
            modifiers.insert(modifier)
        } else {
            modifiers.remove(modifier)
        }

        var validModifiers = Self.sanitizeHotkeyModifiers(
            modifiers.intersection(Self.supportedHotkeyModifiers)
        )
        if validModifiers.isEmpty {
            validModifiers = [.option]
        }
        hotkey = HotkeyConfiguration(
            keyCode: hotkey.keyCode,
            modifiers: validModifiers
        )
    }

    func isHotkeyModifierEnabled(_ modifier: NSEvent.ModifierFlags) -> Bool {
        hotkey.modifiers.contains(modifier)
    }

    private static func readSystemLaunchAtLoginEnabled() -> Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private static func sanitizeHotkeyModifiers(
        _ modifiers: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        let intersected = modifiers.intersection(Self.supportedHotkeyModifiers)
        var trimmed = NSEvent.ModifierFlags()
        var remaining = maxHotkeyModifiers

        for modifier in hotkeyModifierOrder {
            guard remaining > 0 else {
                break
            }
            if intersected.contains(modifier) {
                trimmed.insert(modifier)
                remaining -= 1
            }
        }

        return trimmed
    }

    private static func hotkeyModifierCount(_ modifiers: NSEvent.ModifierFlags) -> Int {
        hotkeyModifierOrder.reduce(0) { count, modifier in
            count + (modifiers.contains(modifier) ? 1 : 0)
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .korean:
            return "한국어"
        }
    }
}

enum AppTextKey {
    case menuOpenClipboardHistory
    case menuHotkeyFormat
    case menuSettings
    case menuQuitCmdV
    case menuActivationTitle
    case menuActivationStatusEnabled
    case menuActivationStatusDisabled

    case popupResume
    case popupPause
    case popupPin
    case popupUnpin
    case popupFavorite
    case popupUnfavorite
    case popupFavoritesTab
    case popupAllTab
    case popupDelete
    case popupMoreActions
    case popupCopy
    case popupShare
    case popupClear
    case popupWindowTitle
    case popupPermissionBanner
    case popupRecordingDisabledBanner
    case popupRequest
    case popupOpenSettings
    case popupDismissPermissionBannerA11y
    case popupSearchPlaceholder
    case popupClearSearchA11y
    case popupNoClipboardItems
    case popupNoClipboardSubtitle
    case popupNoFavorites
    case popupNoFavoritesSubtitle
    case popupFooterHints
    case popupImageLabel
    case popupFileLabel
    case popupTextTypeLabel
    case popupOpen
    case popupFilesLabel
    case popupFolderLabel
    case popupMixedFileTypes
    case popupFileTypeUnknown
    case popupPhotoTypeLabel
    case popupVideoTypeLabel

    case settingsTitle
    case settingsGeneral
    case settingsAbout
    case settingsDeveloperName
    case settingsDeveloperAddress
    case settingsVersion
    case settingsFeedback
    case settingsDeveloperAddressOpen
    case settingsSendFeedback
    case settingsLanguage
    case settingsPauseRecording
    case settingsLaunchAtLogin
    case settingsLaunchAtLoginEnabledState
    case settingsLaunchAtLoginDisabledState
    case settingsLaunchAtLoginFailedFormat
    case settingsClearOnSystemRestart
    case settingsClearOnSystemRestartHint
    case settingsHistoryCapacity
    case settingsHistoryCapacityFormat
    case settingsHistoryCapacityUnit
    case settingsHistoryCapacityHint
    case settingsClipboardPolling
    case settingsClipboardPollingHint
    case settingsGlobalHotkey
    case settingsGlobalHotkeyHint
    case settingsCurrentShortcut
    case settingsHotkeyKey
    case settingsHotkeyModifiers
    case settingsResetHotkey
    case settingsCommand
    case settingsOption
    case settingsControl
    case settingsShift
    case settingsCurrentHotkeyFormat
    case settingsHotkeyUnavailableHint
    case settingsPrivacy
    case settingsExcludedAppsHint
    case settingsAutoPaste
    case settingsPermissionEnabled
    case settingsPermissionMissing
    case settingsPermissionEnabledHelp
    case settingsPermissionMissingGuide
    case settingsRequestPermission
    case settingsOpenPrivacySettings
    case settingsRecheckPermission
    case settingsNoPermissionHint
    case settingsClearHistory
    case settingsClearHistoryConfirmTitle
    case settingsClearHistoryConfirmMessage
    case settingsCancel
    case settingsDone
}

enum AppText {
    static func value(_ key: AppTextKey, language: AppLanguage) -> String {
        switch language {
        case .english:
            return englishValue(key)
        case .korean:
            return koreanValue(key)
        }
    }

    static func menuHotkey(_ hotkey: String, language: AppLanguage) -> String {
        String(format: value(.menuHotkeyFormat, language: language), hotkey)
    }

    static func historyCapacity(_ count: Int, language: AppLanguage) -> String {
        String(format: value(.settingsHistoryCapacityFormat, language: language), count)
    }

    static func currentHotkey(_ hotkey: String, language: AppLanguage) -> String {
        String(format: value(.settingsCurrentHotkeyFormat, language: language), hotkey)
    }

    static func imageSearchTokens(language: AppLanguage) -> [String] {
        switch language {
        case .english:
            return ["image", "이미지"]
        case .korean:
            return ["이미지", "image"]
        }
    }

    private static func englishValue(_ key: AppTextKey) -> String {
        switch key {
        case .menuOpenClipboardHistory:
            return "Open Clipboard History"
        case .menuHotkeyFormat:
            return "Hotkey: %@"
        case .menuSettings:
            return "Settings..."
        case .menuQuitCmdV:
            return "Quit CmdV"
        case .menuActivationTitle:
            return "CmdV"
        case .menuActivationStatusEnabled:
            return "Clipboard On"
        case .menuActivationStatusDisabled:
            return "Clipboard Off"

        case .popupResume:
            return "Resume"
        case .popupPause:
            return "Pause"
        case .popupPin:
            return "Pin"
        case .popupUnpin:
            return "Unpin"
        case .popupFavorite:
            return "Favorite"
        case .popupUnfavorite:
            return "Remove Favorite"
        case .popupFavoritesTab:
            return "Favorites"
        case .popupAllTab:
            return "All"
        case .popupDelete:
            return "Delete"
        case .popupMoreActions:
            return "More actions"
        case .popupCopy:
            return "Copy"
        case .popupShare:
            return "Share"
        case .popupClear:
            return "Clear"
        case .popupWindowTitle:
            return "Clipboard"
        case .popupPermissionBanner:
            return "Auto-paste requires Accessibility permission. Items still copy to clipboard."
        case .popupRecordingDisabledBanner:
            return "CmdV is currently disabled. Turn it on from the menu bar to resume clipboard recording."
        case .popupRequest:
            return "Request"
        case .popupOpenSettings:
            return "Open Settings"
        case .popupDismissPermissionBannerA11y:
            return "Dismiss permission banner"
        case .popupSearchPlaceholder:
            return "Search clipboard history"
        case .popupClearSearchA11y:
            return "Clear search"
        case .popupNoClipboardItems:
            return "No clipboard items"
        case .popupNoClipboardSubtitle:
            return "Copy text, images, or files to start building history."
        case .popupNoFavorites:
            return "No favorites yet"
        case .popupNoFavoritesSubtitle:
            return "Pin items with the favorite button to show them here."
        case .popupFooterHints:
            return "Up/Down Select   Enter Paste   Cmd+Enter Copy   Cmd+P Pin   Esc Close   Cmd+F Search   Delete Remove"
        case .popupImageLabel:
            return "Image"
        case .popupTextTypeLabel:
            return "Text"
        case .popupFileLabel:
            return "File"
        case .popupOpen:
            return "Open"
        case .popupFilesLabel:
            return "Files"
        case .popupFolderLabel:
            return "Folder"
        case .popupMixedFileTypes:
            return "Mixed file types"
        case .popupFileTypeUnknown:
            return "Unknown"
        case .popupPhotoTypeLabel:
            return "Photo"
        case .popupVideoTypeLabel:
            return "Video"

        case .settingsTitle:
            return "CmdV Settings"
        case .settingsGeneral:
            return "General"
        case .settingsAbout:
            return "About"
        case .settingsDeveloperName:
            return "Developer"
        case .settingsDeveloperAddress:
            return "Related Address"
        case .settingsVersion:
            return "Version"
        case .settingsFeedback:
            return "Feedback"
        case .settingsDeveloperAddressOpen:
            return "Open Website"
        case .settingsSendFeedback:
            return "Send Feedback"
        case .settingsLanguage:
            return "Language"
        case .settingsPauseRecording:
            return "Pause recording"
        case .settingsLaunchAtLogin:
            return "Launch at login"
        case .settingsLaunchAtLoginEnabledState:
            return "Status: Enabled"
        case .settingsLaunchAtLoginDisabledState:
            return "Status: Disabled"
        case .settingsLaunchAtLoginFailedFormat:
            return "Failed: %@"
        case .settingsClearOnSystemRestart:
            return "Clear on reboot"
        case .settingsClearOnSystemRestartHint:
            return "When on, history is removed after reboot on the next launch."
        case .settingsHistoryCapacity:
            return "History capacity"
        case .settingsHistoryCapacityFormat:
            return "History capacity %d items"
        case .settingsHistoryCapacityUnit:
            return "items"
        case .settingsHistoryCapacityHint:
            return "Number of history entries to keep. Unit: items."
        case .settingsClipboardPolling:
            return "Clipboard polling"
        case .settingsClipboardPollingHint:
            return "Polling interval in seconds: how often CmdV checks clipboard changes. Lower is faster; higher uses less CPU."
        case .settingsGlobalHotkey:
            return "Global Hotkey"
        case .settingsGlobalHotkeyHint:
            return "Use a global shortcut to toggle the clipboard history."
        case .settingsCurrentShortcut:
            return "Current shortcut"
        case .settingsHotkeyKey:
            return "Key"
        case .settingsHotkeyModifiers:
            return "Modifiers"
        case .settingsResetHotkey:
            return "Reset"
        case .settingsCommand:
            return "Command"
        case .settingsOption:
            return "Option"
        case .settingsControl:
            return "Control"
        case .settingsShift:
            return "Shift"
        case .settingsCurrentHotkeyFormat:
            return "Current: %@"
        case .settingsHotkeyUnavailableHint:
            return "This hotkey is already in use by another app. Choose a different combination."
        case .settingsPrivacy:
            return "Auto-Paste & Permission"
        case .settingsExcludedAppsHint:
            return "Clipboard from these bundle IDs is not saved (one per line)"
        case .settingsAutoPaste:
            return "Auto-Paste"
        case .settingsPermissionEnabled:
            return "Accessibility permission is enabled"
        case .settingsPermissionEnabledHelp:
            return "Auto-paste and clipboard operations are ready."
        case .settingsPermissionMissing:
            return "Accessibility permission is missing"
        case .settingsPermissionMissingGuide:
            return "Open Privacy & Security > Accessibility and allow CmdV."
        case .settingsRequestPermission:
            return "Request Permission"
        case .settingsOpenPrivacySettings:
            return "Open Privacy Settings"
        case .settingsRecheckPermission:
            return "Re-check"
        case .settingsNoPermissionHint:
            return "Without permission, selecting an item still copies it to the clipboard."
        case .settingsClearHistory:
            return "Clear History"
        case .settingsClearHistoryConfirmTitle:
            return "Clear all clipboard history?"
        case .settingsClearHistoryConfirmMessage:
            return "This action permanently deletes saved text, images, and files."
        case .settingsCancel:
            return "Cancel"
        case .settingsDone:
            return "Done"
        }
    }

    private static func koreanValue(_ key: AppTextKey) -> String {
        switch key {
        case .menuOpenClipboardHistory:
            return "클립보드 기록 열기"
        case .menuHotkeyFormat:
            return "단축키: %@"
        case .menuSettings:
            return "설정..."
        case .menuQuitCmdV:
            return "CmdV 종료"
        case .menuActivationTitle:
            return "CmdV"
        case .menuActivationStatusEnabled:
            return "클립보드 활성화"
        case .menuActivationStatusDisabled:
            return "클립보드 비활성"

        case .popupResume:
            return "재개"
        case .popupPause:
            return "일시정지"
        case .popupPin:
            return "고정"
        case .popupUnpin:
            return "고정 해제"
        case .popupFavorite:
            return "즐겨찾기"
        case .popupUnfavorite:
            return "즐겨찾기 해제"
        case .popupFavoritesTab:
            return "즐겨찾기"
        case .popupAllTab:
            return "전체"
        case .popupDelete:
            return "삭제"
        case .popupMoreActions:
            return "추가 작업"
        case .popupCopy:
            return "복사"
        case .popupShare:
            return "공유"
        case .popupClear:
            return "모두 삭제"
        case .popupWindowTitle:
            return "클립보드"
        case .popupPermissionBanner:
            return "자동 붙여넣기를 사용하려면 손쉬운 사용 권한이 필요합니다. 항목은 클립보드로 복사됩니다."
        case .popupRecordingDisabledBanner:
            return "현재 CmdV가 비활성화 상태입니다. 메뉴바에서 CmdV 활성화를 켜주세요."
        case .popupRequest:
            return "요청"
        case .popupOpenSettings:
            return "설정 열기"
        case .popupDismissPermissionBannerA11y:
            return "권한 안내 배너 닫기"
        case .popupSearchPlaceholder:
            return "클립보드 기록 검색"
        case .popupClearSearchA11y:
            return "검색어 지우기"
        case .popupNoClipboardItems:
            return "클립보드 항목이 없습니다"
        case .popupNoClipboardSubtitle:
            return "텍스트, 이미지, 파일을 복사하면 기록이 쌓입니다."
        case .popupNoFavorites:
            return "즐겨찾기 항목이 없습니다"
        case .popupNoFavoritesSubtitle:
            return "항목에서 즐겨찾기 버튼을 누르면 여기에 표시됩니다."
        case .popupFooterHints:
            return "위/아래 선택   Enter 붙여넣기   Cmd+Enter 복사   Cmd+P 고정   Esc 닫기   Cmd+F 검색   Delete 삭제"
        case .popupImageLabel:
            return "이미지"
        case .popupTextTypeLabel:
            return "텍스트"
        case .popupFileLabel:
            return "파일"
        case .popupOpen:
            return "열기"
        case .popupFilesLabel:
            return "파일"
        case .popupFolderLabel:
            return "폴더"
        case .popupMixedFileTypes:
            return "혼합 파일 형식"
        case .popupFileTypeUnknown:
            return "알 수 없음"
        case .popupPhotoTypeLabel:
            return "사진"
        case .popupVideoTypeLabel:
            return "동영상"

        case .settingsTitle:
            return "CmdV 설정"
        case .settingsGeneral:
            return "일반"
        case .settingsAbout:
            return "정보"
        case .settingsDeveloperName:
            return "개발자"
        case .settingsDeveloperAddress:
            return "관련 주소"
        case .settingsVersion:
            return "버전"
        case .settingsFeedback:
            return "피드백"
        case .settingsDeveloperAddressOpen:
            return "웹사이트 열기"
        case .settingsSendFeedback:
            return "피드백 보내기"
        case .settingsLanguage:
            return "언어"
        case .settingsPauseRecording:
            return "기록 일시정지"
        case .settingsLaunchAtLogin:
            return "부팅 시 자동 실행"
        case .settingsLaunchAtLoginEnabledState:
            return "상태: 활성화됨"
        case .settingsLaunchAtLoginDisabledState:
            return "상태: 비활성화됨"
        case .settingsLaunchAtLoginFailedFormat:
            return "실패: %@"
        case .settingsClearOnSystemRestart:
            return "부팅 시 기록 삭제"
        case .settingsClearOnSystemRestartHint:
            return "켜면 재부팅 후 모든 기록을 삭제합니다"
        case .settingsHistoryCapacity:
            return "기록 용량"
        case .settingsHistoryCapacityFormat:
            return "기록 용량 %d개"
        case .settingsHistoryCapacityUnit:
            return "개"
        case .settingsHistoryCapacityHint:
            return "저장할 기록 항목의 개수를 설정합니다. 단위: 개"
        case .settingsClipboardPolling:
            return "클립보드 폴링"
        case .settingsClipboardPollingHint:
            return "단위: 초. 클립보드 변경을 확인하는 주기입니다. 값이 낮을수록 빠르고, 높을수록 CPU 사용이 줄어듭니다."
        case .settingsGlobalHotkey:
            return "전역 단축키"
        case .settingsGlobalHotkeyHint:
            return "단축키로 클립보드 기록 창을 열고 닫습니다."
        case .settingsCurrentShortcut:
            return "현재 단축키"
        case .settingsHotkeyKey:
            return "키"
        case .settingsHotkeyModifiers:
            return "조합키"
        case .settingsResetHotkey:
            return "기본값"
        case .settingsCommand:
            return "Command"
        case .settingsOption:
            return "Option"
        case .settingsControl:
            return "Control"
        case .settingsShift:
            return "Shift"
        case .settingsCurrentHotkeyFormat:
            return "현재: %@"
        case .settingsHotkeyUnavailableHint:
            return "이 단축키는 다른 앱에서 이미 사용 중입니다. 다른 조합으로 변경해 주세요."
        case .settingsPrivacy:
            return "자동 붙여넣기 및 권한"
        case .settingsExcludedAppsHint:
            return "여기에 등록한 번들 ID 앱의 클립보드는 저장하지 않습니다 (한 줄에 하나)"
        case .settingsAutoPaste:
            return "자동 붙여넣기"
        case .settingsPermissionEnabled:
            return "손쉬운 사용 권한이 활성화됨"
        case .settingsPermissionEnabledHelp:
            return "자동 붙여넣기 및 클립보드 동작이 즉시 동작합니다."
        case .settingsPermissionMissing:
            return "손쉬운 사용 권한이 없음"
        case .settingsPermissionMissingGuide:
            return "시스템 설정 > 보안 및 개인정보 보호 > 손쉬운 사용에서 CmdV를 허용해 주세요."
        case .settingsRequestPermission:
            return "권한 요청"
        case .settingsOpenPrivacySettings:
            return "개인정보 설정 열기"
        case .settingsRecheckPermission:
            return "권한 상태 재확인"
        case .settingsNoPermissionHint:
            return "권한이 없어도 항목 선택 시 클립보드에는 복사됩니다."
        case .settingsClearHistory:
            return "기록 비우기"
        case .settingsClearHistoryConfirmTitle:
            return "클립보드 기록을 모두 비울까요?"
        case .settingsClearHistoryConfirmMessage:
            return "저장된 텍스트, 이미지, 파일이 영구적으로 삭제됩니다."
        case .settingsCancel:
            return "취소"
        case .settingsDone:
            return "완료"
        }
    }
}

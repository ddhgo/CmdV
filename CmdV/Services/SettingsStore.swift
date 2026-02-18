import AppKit
import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
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
    private let supportedHotkeyModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    @Published var maxHistoryItems: Int {
        didSet {
            let clamped = max(20, min(1000, maxHistoryItems))
            if clamped != maxHistoryItems {
                maxHistoryItems = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.maxHistoryItems)
        }
    }

    @Published var pollingInterval: Double {
        didSet {
            let clamped = max(0.2, min(2.0, pollingInterval))
            if clamped != pollingInterval {
                pollingInterval = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.pollingInterval)
        }
    }

    @Published var isRecordingPaused: Bool {
        didSet {
            defaults.set(isRecordingPaused, forKey: Keys.isRecordingPaused)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        }
    }

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
            if hotkey.modifiers.intersection(supportedHotkeyModifiers).isEmpty {
                hotkey.modifiers = [.option]
            }

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
        maxHistoryItems = max(20, min(1000, maxItemsValue))

        let pollingValue = defaults.object(forKey: Keys.pollingInterval) as? Double ?? 0.6
        pollingInterval = max(0.2, min(2.0, pollingValue))

        isRecordingPaused = defaults.object(forKey: Keys.isRecordingPaused) as? Bool ?? false
        if let storedLaunchAtLoginEnabled = defaults.object(forKey: Keys.launchAtLoginEnabled) as? Bool {
            launchAtLoginEnabled = storedLaunchAtLoginEnabled
        } else {
            launchAtLoginEnabled = Self.readSystemLaunchAtLoginEnabled()
        }
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

        let sanitizedModifiers = modifiers.intersection(supportedHotkeyModifiers)
        hotkey = HotkeyConfiguration(
            keyCode: keyCode,
            modifiers: sanitizedModifiers.isEmpty ? [.option] : sanitizedModifiers
        )
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = Self.readSystemLaunchAtLoginEnabled()
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
            return applied == enabled
        } catch {
            launchAtLoginEnabled = Self.readSystemLaunchAtLoginEnabled()
            return false
        }
    }

    func setHotkeyKeyCode(_ keyCode: UInt32) {
        hotkey = HotkeyConfiguration(keyCode: keyCode, modifiers: hotkey.modifiers)
    }

    func setHotkeyModifier(_ modifier: NSEvent.ModifierFlags, enabled: Bool) {
        var modifiers = hotkey.modifiers

        if enabled {
            modifiers.insert(modifier)
        } else {
            modifiers.remove(modifier)
        }

        let validModifiers = modifiers.intersection(supportedHotkeyModifiers)
        hotkey = HotkeyConfiguration(
            keyCode: hotkey.keyCode,
            modifiers: validModifiers.isEmpty ? [.option] : validModifiers
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

    case popupResume
    case popupPause
    case popupPin
    case popupUnpin
    case popupDelete
    case popupMoreActions
    case popupCopy
    case popupClear
    case popupPermissionBanner
    case popupRequest
    case popupOpenSettings
    case popupSearchPlaceholder
    case popupNoClipboardItems
    case popupNoClipboardSubtitle
    case popupFooterHints
    case popupImageLabel

    case settingsTitle
    case settingsGeneral
    case settingsLanguage
    case settingsPauseRecording
    case settingsLaunchAtLogin
    case settingsClearOnSystemRestart
    case settingsClearOnSystemRestartHint
    case settingsHistoryCapacityFormat
    case settingsClipboardPolling
    case settingsClipboardPollingHint
    case settingsGlobalHotkey
    case settingsHotkeyKey
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
    case settingsRequestPermission
    case settingsOpenPrivacySettings
    case settingsNoPermissionHint
    case settingsClearHistory
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

        case .popupResume:
            return "Resume"
        case .popupPause:
            return "Pause"
        case .popupPin:
            return "Pin"
        case .popupUnpin:
            return "Unpin"
        case .popupDelete:
            return "Delete"
        case .popupMoreActions:
            return "More actions"
        case .popupCopy:
            return "Copy"
        case .popupClear:
            return "Clear"
        case .popupPermissionBanner:
            return "Auto-paste requires Accessibility permission. Items still copy to clipboard."
        case .popupRequest:
            return "Request"
        case .popupOpenSettings:
            return "Open Settings"
        case .popupSearchPlaceholder:
            return "Search clipboard history"
        case .popupNoClipboardItems:
            return "No clipboard items"
        case .popupNoClipboardSubtitle:
            return "Copy text or images to start building history."
        case .popupFooterHints:
            return "Up/Down Select   Enter Paste   Cmd+Enter Copy   Cmd+P Pin   Esc Close   Cmd+F Search   Delete Remove"
        case .popupImageLabel:
            return "Image"

        case .settingsTitle:
            return "CmdV Settings"
        case .settingsGeneral:
            return "General"
        case .settingsLanguage:
            return "Language"
        case .settingsPauseRecording:
            return "Pause recording"
        case .settingsLaunchAtLogin:
            return "Launch at login"
        case .settingsClearOnSystemRestart:
            return "Clear history after system restart"
        case .settingsClearOnSystemRestartHint:
            return "When enabled, history from the previous boot session is removed automatically on next launch after reboot."
        case .settingsHistoryCapacityFormat:
            return "History capacity: %d items"
        case .settingsClipboardPolling:
            return "Clipboard polling"
        case .settingsClipboardPollingHint:
            return "How often CmdV checks for clipboard changes. Lower is faster; higher uses less CPU."
        case .settingsGlobalHotkey:
            return "Global Hotkey"
        case .settingsHotkeyKey:
            return "Key"
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
        case .settingsPermissionMissing:
            return "Accessibility permission is missing"
        case .settingsRequestPermission:
            return "Request Permission"
        case .settingsOpenPrivacySettings:
            return "Open Privacy Settings"
        case .settingsNoPermissionHint:
            return "Without permission, selecting an item still copies it to the clipboard."
        case .settingsClearHistory:
            return "Clear History"
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

        case .popupResume:
            return "재개"
        case .popupPause:
            return "일시정지"
        case .popupPin:
            return "고정"
        case .popupUnpin:
            return "고정 해제"
        case .popupDelete:
            return "삭제"
        case .popupMoreActions:
            return "추가 작업"
        case .popupCopy:
            return "복사"
        case .popupClear:
            return "비우기"
        case .popupPermissionBanner:
            return "자동 붙여넣기를 사용하려면 손쉬운 사용 권한이 필요합니다. 항목은 클립보드로 복사됩니다."
        case .popupRequest:
            return "요청"
        case .popupOpenSettings:
            return "설정 열기"
        case .popupSearchPlaceholder:
            return "클립보드 기록 검색"
        case .popupNoClipboardItems:
            return "클립보드 항목이 없습니다"
        case .popupNoClipboardSubtitle:
            return "텍스트나 이미지를 복사하면 기록이 쌓입니다."
        case .popupFooterHints:
            return "위/아래 선택   Enter 붙여넣기   Cmd+Enter 복사   Cmd+P 고정   Esc 닫기   Cmd+F 검색   Delete 삭제"
        case .popupImageLabel:
            return "이미지"

        case .settingsTitle:
            return "CmdV 설정"
        case .settingsGeneral:
            return "일반"
        case .settingsLanguage:
            return "언어"
        case .settingsPauseRecording:
            return "기록 일시정지"
        case .settingsLaunchAtLogin:
            return "부팅 시 자동 실행"
        case .settingsClearOnSystemRestart:
            return "시스템 재시작 후 기록 자동 삭제"
        case .settingsClearOnSystemRestartHint:
            return "활성화하면 재부팅 후 첫 실행 시 이전 부팅 세션의 기록이 자동으로 삭제됩니다."
        case .settingsHistoryCapacityFormat:
            return "기록 용량: %d개"
        case .settingsClipboardPolling:
            return "클립보드 폴링"
        case .settingsClipboardPollingHint:
            return "클립보드 변경을 확인하는 주기입니다. 값이 낮을수록 빠르고, 높을수록 CPU 사용이 줄어듭니다."
        case .settingsGlobalHotkey:
            return "전역 단축키"
        case .settingsHotkeyKey:
            return "키"
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
        case .settingsPermissionMissing:
            return "손쉬운 사용 권한이 없음"
        case .settingsRequestPermission:
            return "권한 요청"
        case .settingsOpenPrivacySettings:
            return "개인정보 설정 열기"
        case .settingsNoPermissionHint:
            return "권한이 없어도 항목 선택 시 클립보드에는 복사됩니다."
        case .settingsClearHistory:
            return "기록 비우기"
        case .settingsDone:
            return "완료"
        }
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    static let fixedWindowWidth: CGFloat = 348

    @ObservedObject var settings: SettingsStore
    @ObservedObject var permissions: PermissionsService
    @ObservedObject var runtimeState: AppRuntimeState

    let onClearHistory: () -> Void
    let onClose: () -> Void
    let onContentSizeChange: (CGSize) -> Void

    private enum SettingsTab: String, CaseIterable, Hashable {
        case general
        case hotkey
        case privacy
        case about
    }

    @State private var labelColumnWidth: CGFloat = 180
    @State private var selectedTab: SettingsTab = .general
    @State private var contentSize: CGSize = .zero
    @State private var tabBarWidth: CGFloat = 0
    private let fixedWindowWidth = Self.fixedWindowWidth
    private let generalNumericInputWidth: CGFloat = 88
    private let generalControlPadding = CGFloat(16)
    private let generalNumericRowSpacing: CGFloat = 2
    private let tabSpacing: CGFloat = 5
    private let tabButtonMinSize: CGFloat = 56
    private let tabButtonMaxSize: CGFloat = 92
    private let rootContentInset: CGFloat = 12
    private let permissionsButtonHeight: CGFloat = 30
    private let hotkeyControlHeight: CGFloat = 34
    private let hotkeyKeyControlMinWidth: CGFloat = 80
    private let generalControlHeight: CGFloat = 24
    private let cardContentInset: CGFloat = 14
    private let settingsLabelFont = Font.system(size: 12.5, weight: .medium)
    private let paneRadius: CGFloat = 18
    private let tabPillRadius: CGFloat = 12
    private let developerAddressURL = "https://github.com/rtfdev"
    private let sponsorURL = "https://github.com/sponsors/rtfdev"
    private let feedbackURL = "https://github.com/rtfdev/CtrlCV/issues/new/choose"

    private var language: AppLanguage {
        settings.appLanguage
    }

    var body: some View {
        VStack(spacing: 12) {
            settingsTabBar

            selectedTabContent
        }
        .padding(.horizontal, rootContentInset)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: fixedWindowWidth)
        .onAppear {
            permissions.refreshStatus()
            settings.refreshLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.refreshLaunchAtLoginStatus()
        }
        .onPreferenceChange(SettingsLabelWidthPreferenceKey.self) { measuredWidth in
            labelColumnWidth = min(
                maxLabelColumnWidth,
                max(120, measuredWidth)
            )
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SettingsViewContentSizePreferenceKey.self,
                    value: proxy.size
                )
            }
        )
        .onPreferenceChange(SettingsViewContentSizePreferenceKey.self) { measuredSize in
            guard measuredSize.width > 0, measuredSize.height > 0 else {
                return
            }

            if abs(measuredSize.width - contentSize.width) < 0.5,
               abs(measuredSize.height - contentSize.height) < 0.5 {
                return
            }

            contentSize = measuredSize
            onContentSizeChange(measuredSize)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(CmdVTheme.Colors.windowSurface)
        .clipShape(RoundedRectangle(cornerRadius: paneRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: paneRadius, style: .continuous)
                .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
    }

    private var settingsTabBar: some View {
        HStack(spacing: tabSpacing) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                let iconSize = isSelected ? 15.0 : 14.5
                let tabButtonSide = tabButtonLength

                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: tabIcon(tab))
                        .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: tabButtonSide, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: tabPillRadius, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: tabPillRadius, style: .continuous)
                                .stroke(
                                    isSelected ? Color.accentColor.opacity(0.45) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: tabPillRadius, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tabTitle(tab))
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CmdVTheme.Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SettingsTabBarWidthPreferenceKey.self,
                    value: proxy.size.width
                )
            }
        )
        .onPreferenceChange(SettingsTabBarWidthPreferenceKey.self) { measuredWidth in
            guard measuredWidth > 0 else { return }
            if abs(measuredWidth - tabBarWidth) >= 0.5 {
                tabBarWidth = measuredWidth
            }
        }
    }

    private var selectedTabContent: some View {
        Group {
            switch selectedTab {
            case .general:
                generalSection
            case .hotkey:
                hotkeySection
            case .privacy:
                privacySection
            case .about:
                aboutSection
            }
        }
    }

    private func tabTitle(_ tab: SettingsTab) -> String {
        switch tab {
        case .general:
            return AppText.value(.settingsGeneral, language: language)
        case .hotkey:
            return AppText.value(.settingsGlobalHotkey, language: language)
        case .privacy:
            return AppText.value(.settingsPrivacy, language: language)
        case .about:
            return AppText.value(.settingsAbout, language: language)
        }
    }

    private func tabIcon(_ tab: SettingsTab) -> String {
        switch tab {
        case .general:
            return "slider.horizontal.3"
        case .hotkey:
            return "keyboard"
        case .privacy:
            return "hand.raised"
        case .about:
            return "info.circle"
        }
    }

    private var generalSection: some View {
        settingsCard(title: AppText.value(.settingsGeneral, language: language)) {
            VStack(alignment: .leading, spacing: 9) {
                generalFieldRow(label: AppText.value(.settingsLanguage, language: language)) {
                    Picker("", selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName)
                                .tag(option)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }

                generalHistoryCapacityRow

                generalFieldRow(
                    label: AppText.value(.settingsClipboardPolling, language: language),
                    infoMessage: AppText.value(.settingsClipboardPollingHint, language: language),
                    contentWidth: generalNumericInputWidth
                ) {
                    HStack(alignment: .center, spacing: generalNumericRowSpacing) {
                        TextField(
                            "",
                            value: pollingIntervalBinding,
                            format: .number.precision(.fractionLength(1))
                        )
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 52)
                        .controlSize(.small)
                        .frame(height: generalControlHeight)

                        Stepper(
                            "",
                            value: pollingIntervalBinding,
                            in: SettingsStore.pollingIntervalDisplayRange,
                            step: SettingsStore.pollingIntervalStep
                        )
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(height: generalControlHeight)
                    }
                }

                generalFieldRow(label: AppText.value(.settingsLaunchAtLogin, language: language)) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                generalClearOnSystemRestartRow
            }
        }
    }

    private var aboutSection: some View {
        settingsCard(
            title: "",
            showTitle: false
        ) {
            VStack(alignment: .center, spacing: 8) {
                aboutValueRow {
                    HStack(spacing: 8) {
                        Text("CmdV")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(appVersionText)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13, weight: .medium))
                    }
                }

                aboutValueRow {
                    Text("by rtfdev")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                aboutValueRow {
                    Button(AppText.value(.settingsDeveloperAddressOpen, language: language)) {
                        openExternalURL(developerAddressURL)
                    }
                    .buttonStyle(.bordered)
                    .font(.callout)
                    .controlSize(.small)
                }

                aboutValueRow {
                    Button(AppText.value(.settingsSendFeedback, language: language)) {
                        openExternalURL(feedbackURL)
                    }
                    .buttonStyle(.bordered)
                    .font(.callout)
                    .controlSize(.small)
                }

                aboutValueRow {
                    Button(AppText.value(.settingsSponsorAuthor, language: language)) {
                        openExternalURL(sponsorURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.callout)
                    .controlSize(.small)
                }
            }
        }
    }

    private func aboutValueRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .center, spacing: 4) {
            content()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var generalClearOnSystemRestartRow: some View {
        generalFieldRow(
            label: AppText.value(.settingsClearOnSystemRestart, language: language),
            infoMessage: AppText.value(.settingsClearOnSystemRestartHint, language: language)
        ) {
            Toggle("", isOn: $settings.clearHistoryOnSystemRestart)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var generalHistoryCapacityRow: some View {
        generalFieldRow(
            label: AppText.value(.settingsHistoryCapacity, language: language),
            infoMessage: AppText.value(.settingsHistoryCapacityHint, language: language),
            contentWidth: generalNumericInputWidth
        ) {
            HStack(alignment: .center, spacing: generalNumericRowSpacing) {
                TextField(
                    "",
                    value: historyCapacityBinding,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .controlSize(.small)
                .frame(height: generalControlHeight)

                Stepper(
                    "",
                    value: historyCapacityBinding,
                    in: SettingsStore.maxHistoryItemsUIStepperRange,
                    step: SettingsStore.maxHistoryItemsStep
                )
                .labelsHidden()
                .controlSize(.small)
                .frame(height: generalControlHeight)
            }
        }
    }

    private var maxLabelColumnWidth: CGFloat {
        let outerPadding = rootContentInset * 2
        let cardPadding = cardContentInset * 2
        let rowSpacing = CGFloat(12)
        let usableRowWidth = fixedWindowWidth - outerPadding - cardPadding
        return max(120, usableRowWidth - generalNumericInputWidth - rowSpacing - generalControlPadding)
    }

    private func generalFieldRow<Content: View>(
        label: String,
        infoMessage: String? = nil,
        infoPlacementLeading: Bool = false,
        contentWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        fieldRow(
            label: label,
            infoMessage: infoMessage,
            infoPlacementLeading: infoPlacementLeading
        ) {
            if let contentWidth {
                content()
                    .frame(width: contentWidth, alignment: .trailing)
                    .frame(height: generalControlHeight)
            } else {
                content()
                    .frame(height: generalControlHeight)
            }
        }
    }

    private var hotkeySection: some View {
        settingsCard(title: AppText.value(.settingsGlobalHotkey, language: language)) {
            VStack(alignment: .leading, spacing: 10) {
                hotkeyRow(
                    title: AppText.value(.settingsOpenClipboardWindow, language: language),
                    keyCode: settings.hotkey.keyCode,
                    isModifierEnabled: settings.isHotkeyModifierEnabled,
                    selectedModifierCount: shortcutModifierCount(
                        isModifierEnabled: settings.isHotkeyModifierEnabled
                    ),
                    maxModifierCount: 2,
                    setModifier: settings.setHotkeyModifier,
                    setKeyCode: settings.setHotkeyKeyCode
                )

                hotkeyRow(
                    title: AppText.value(.settingsScreenshotHotkey, language: language),
                    keyCode: settings.screenshotHotkey.keyCode,
                    isModifierEnabled: settings.isScreenshotHotkeyModifierEnabled,
                    selectedModifierCount: shortcutModifierCount(
                        isModifierEnabled: settings.isScreenshotHotkeyModifierEnabled
                    ),
                    maxModifierCount: 3,
                    setModifier: settings.setScreenshotHotkeyModifier,
                    setKeyCode: settings.setScreenshotHotkeyKeyCode
                )
            }
        }
    }

    private var privacySection: some View {
        settingsCard(
            title: AppText.value(.settingsPrivacy, language: language)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Spacer(minLength: 0)
                        accessibilityStatusChip
                        Spacer(minLength: 0)
                    }
                    Text(privacyPermissionHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer(minLength: 0)
                    Button(
                        permissions.accessibilityGranted
                            ? AppText.value(.settingsOpenPrivacySettings, language: language)
                            : AppText.value(.settingsRequestPermission, language: language)
                    ) {
                        if permissions.accessibilityGranted {
                            permissions.openAccessibilitySettings()
                        } else {
                            permissions.requestAccessibilityPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(height: permissionsButtonHeight)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var privacyPermissionHint: String {
        permissions.accessibilityGranted
            ? AppText.value(.settingsPermissionEnabledHelp, language: language)
            : AppText.value(.settingsPermissionMissingGuide, language: language)
    }

    private func settingsCard<Content: View>(
        title: String,
        showTitle: Bool = true,
        fixedHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isCompact = fixedHeight != nil

        return VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
            if showTitle {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }

            content()
        }
        .padding(.horizontal, cardContentInset)
        .padding(.vertical, isCompact ? 8 : 12)
        .frame(
            maxWidth: .infinity,
            minHeight: fixedHeight,
            maxHeight: fixedHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CmdVTheme.Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
        )
    }

    private func fieldRow<Content: View>(
        label: String,
        infoMessage: String? = nil,
        infoPlacementLeading: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 4) {
                if let infoMessage {
                    if infoPlacementLeading {
                        InfoHelpButton(message: infoMessage)
                    }
                }

                Text(label)
                    .foregroundStyle(.secondary)
                    .font(settingsLabelFont)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                    .truncationMode(.tail)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: SettingsLabelWidthPreferenceKey.self,
                                value: proxy.size.width
                            )
                        }
                    )

                if let infoMessage, !infoPlacementLeading {
                    InfoHelpButton(message: infoMessage)
                }
            }
            .frame(width: labelColumnWidth, alignment: .leading)
            

            Spacer(minLength: 0)
            content()
        }
    }

    private var accessibilityStatusChip: some View {
        let granted = permissions.accessibilityGranted
        let statusText = granted
            ? AppText.value(.settingsPermissionEnabled, language: language)
            : AppText.value(.settingsPermissionMissing, language: language)
        let tint = granted ? Color.green : Color.orange

        return HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.13))
        )
    }

    private var pollingIntervalBinding: Binding<Double> {
        Binding(
            get: { settings.pollingInterval },
            set: { value in
                let rounded = (value * 10).rounded() / 10
                settings.pollingInterval = min(
                    SettingsStore.pollingIntervalDisplayRange.upperBound,
                    max(SettingsStore.pollingIntervalDisplayRange.lowerBound, rounded)
                )
            }
        )
    }

    private var historyCapacityBinding: Binding<Int> {
        Binding(
            get: { settings.maxHistoryItems },
            set: { value in
                settings.maxHistoryItems = min(
                    SettingsStore.maxHistoryItemsRange.upperBound,
                    max(SettingsStore.maxHistoryItemsRange.lowerBound, value)
                )
            }
        )
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? shortVersion ?? "1.0"
            : (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1.0"
    }

    private func openExternalURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLoginEnabled },
            set: { value in
                if !settings.setLaunchAtLoginEnabled(value) {
                    NSSound.beep()
                }
            }
        )
    }

    private var tabButtonCount: Int {
        SettingsTab.allCases.count
    }

    private var tabButtonLength: CGFloat {
        guard tabBarWidth > 0 else { return tabButtonMinSize }
        let count = CGFloat(tabButtonCount)
        let spacingTotal = tabSpacing * (count - 1)
        return max(tabButtonMinSize, min(tabButtonMaxSize, (tabBarWidth - spacingTotal) / count))
    }

    private struct SettingsTabBarWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private func hotkeyRow(
        title: String,
        keyCode: UInt32,
        isModifierEnabled: @escaping (NSEvent.ModifierFlags) -> Bool,
        selectedModifierCount: Int,
        maxModifierCount: Int,
        setModifier: @escaping (NSEvent.ModifierFlags, Bool) -> Void,
        setKeyCode: @escaping (UInt32) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    shortcutModifierMenu(
                        isModifierEnabled: isModifierEnabled,
                        selectedModifierCount: selectedModifierCount,
                        maxModifierCount: maxModifierCount,
                        setModifier: setModifier
                    )
                    shortcutKeyMenu(
                        currentKeyCode: keyCode,
                        isKeyCodeSelected: { option in
                            keyCode == option.keyCode
                        },
                        setKeyCode: setKeyCode
                    )
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func shortcutModifierMenu(
        isModifierEnabled: @escaping (NSEvent.ModifierFlags) -> Bool,
        selectedModifierCount: Int,
        maxModifierCount: Int,
        setModifier: @escaping (NSEvent.ModifierFlags, Bool) -> Void
    ) -> some View {
        return Menu {
            shortcutModifierMenuItem(
                modifier: .command,
                isEnabled: isModifierEnabled(.command),
                selectedModifierCount: selectedModifierCount,
                maxModifierCount: maxModifierCount,
                setModifier: setModifier
            )
            shortcutModifierMenuItem(
                modifier: .option,
                isEnabled: isModifierEnabled(.option),
                selectedModifierCount: selectedModifierCount,
                maxModifierCount: maxModifierCount,
                setModifier: setModifier
            )
            shortcutModifierMenuItem(
                modifier: .control,
                isEnabled: isModifierEnabled(.control),
                selectedModifierCount: selectedModifierCount,
                maxModifierCount: maxModifierCount,
                setModifier: setModifier
            )
            shortcutModifierMenuItem(
                modifier: .shift,
                isEnabled: isModifierEnabled(.shift),
                selectedModifierCount: selectedModifierCount,
                maxModifierCount: maxModifierCount,
                setModifier: setModifier
            )
        } label: {
            HStack(spacing: 5) {
                Text(shortcutModifierSummary(isModifierEnabled: isModifierEnabled))
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 10)
            .frame(height: hotkeyControlHeight)
        }
        .fixedSize(horizontal: true, vertical: false)
        .menuStyle(.borderedButton)
    }

    @ViewBuilder
    private func shortcutModifierMenuItem(
        modifier: NSEvent.ModifierFlags,
        isEnabled: Bool,
        selectedModifierCount: Int,
        maxModifierCount: Int,
        setModifier: @escaping (NSEvent.ModifierFlags, Bool) -> Void
    ) -> some View {
        let symbol = modifierSymbolName(modifier)
        let canSelect = isEnabled || selectedModifierCount < maxModifierCount

        Button {
            if canSelect {
                setModifier(modifier, !isEnabled)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 20, alignment: .center)

                Spacer(minLength: 0)

                if isEnabled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(!canSelect)
    }

    private func shortcutKeyMenu(
        currentKeyCode: UInt32,
        isKeyCodeSelected: @escaping (HotkeyOption) -> Bool,
        setKeyCode: @escaping (UInt32) -> Void
    ) -> some View {
        Menu {
            ForEach(HotkeyCatalog.options) { option in
                Button {
                    setKeyCode(option.keyCode)
                } label: {
                    let selected = isKeyCodeSelected(option)
                    Text(selected ? "✓ \(option.label)" : option.label)
                }
            }
            } label: {
            HStack(spacing: 6) {
                Text(
                    HotkeyCatalog.options.first(where: { $0.keyCode == currentKeyCode })?.label ?? "V"
                )
                .font(.system(.body, design: .monospaced, weight: .medium))
                .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: hotkeyControlHeight, alignment: .center)
            .frame(minWidth: hotkeyKeyControlMinWidth)
        }
        .fixedSize(horizontal: true, vertical: false)
        .menuStyle(.borderedButton)
    }

    private func shortcutModifierSummary(isModifierEnabled: (NSEvent.ModifierFlags) -> Bool) -> String {
        let activeFlags: [NSEvent.ModifierFlags] = [.command, .option, .control, .shift]
        let items = activeFlags.compactMap { flag in
            isModifierEnabled(flag) ? activeModifierGlyph(flag) : nil
        }

        return items.isEmpty
            ? (language == .korean ? "단일키" : "Key only")
            : items.joined(separator: " + ")
    }

    private func shortcutModifierCount(isModifierEnabled: (NSEvent.ModifierFlags) -> Bool) -> Int {
        [NSEvent.ModifierFlags.command, .option, .control, .shift].reduce(0) { count, flag in
            count + (isModifierEnabled(flag) ? 1 : 0)
        }
    }

    private func activeModifierGlyph(_ modifier: NSEvent.ModifierFlags) -> String {
        switch modifier {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        case .shift:
            return "⇧"
        default:
            return ""
        }
    }

    private func modifierSymbolName(_ modifier: NSEvent.ModifierFlags) -> String {
        switch modifier {
        case .command:
            return "command"
        case .option:
            return "option"
        case .control:
            return "control"
        case .shift:
            return "shift"
        default:
            return ""
        }
    }

    private var settingsBackgroundColor: Color { CmdVTheme.Colors.windowSurface }
    private var settingsSurfaceColor: Color { CmdVTheme.Colors.windowSurface }
    private var settingsCardBackgroundColor: Color { CmdVTheme.Colors.cardSurface }
}

private struct InfoHelpButton: View {
    let message: String
    @State private var isShowingHelp = false

    var body: some View {
        Image(systemName: "info.circle.fill")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 12, height: 12)
            .contentShape(Circle())
            .onTapGesture {
                isShowingHelp.toggle()
            }
            .popover(isPresented: $isShowingHelp) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .help(message)
            .accessibilityLabel("설명 보기")
            .accessibilityValue(message)
    }
}

private struct SettingsLabelWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SettingsViewContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

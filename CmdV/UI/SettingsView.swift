import AppKit
import SwiftUI

struct SettingsView: View {
    static let fixedWindowWidth: CGFloat = 360

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

    @State private var labelColumnWidth: CGFloat = 132
    @State private var selectedTab: SettingsTab = .general
    @State private var contentSize: CGSize = .zero
    @State private var tabBarWidth: CGFloat = 0
    private let fixedWindowWidth = Self.fixedWindowWidth
    private let tabSpacing: CGFloat = 5
    private let tabButtonMinSize: CGFloat = 44
    private let tabButtonMaxSize: CGFloat = 78
    private let compactCardHeight: CGFloat = 60
    private let permissionsButtonHeight: CGFloat = 30
    private let developerAddressURL = "https://github.com/rtfdev"
    private let feedbackURL = "https://github.com/rtfdev/CtrlCV/issues/new/choose"

    private var language: AppLanguage {
        settings.appLanguage
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: tabSpacing) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    let isSelected = selectedTab == tab
                    let iconSize = isSelected ? 16.0 : 15.0
                    let tabButtonSide = tabButtonLength

                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .frame(width: tabButtonSide, height: tabButtonSide)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(nsColor: .windowBackgroundColor).opacity(0.2))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.32),
                                        lineWidth: 1
                                    )
                            )
                            .animation(.easeInOut(duration: 0.16), value: isSelected)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tabTitle(tab))
                }
            }
            .padding(.horizontal, 2)
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

            selectedTabContent
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(width: fixedWindowWidth)
        .onAppear {
            permissions.refreshStatus()
            settings.refreshLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.refreshLaunchAtLoginStatus()
        }
        .onPreferenceChange(SettingsLabelWidthPreferenceKey.self) { measuredWidth in
            labelColumnWidth = min(142, max(122, measuredWidth))
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
        .background(settingsBackgroundColor)
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
            return "gearshape"
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
                fieldRow(label: AppText.value(.settingsLanguage, language: language)) {
                    Picker("", selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName)
                                .tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 148, alignment: .trailing)
                }

                fieldRow(label: AppText.value(.settingsLaunchAtLogin, language: language)) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                clearOnSystemRestartRow

                historyCapacityRow

                fieldRow(
                    label: AppText.value(.settingsClipboardPolling, language: language),
                    infoMessage: AppText.value(.settingsClipboardPollingHint, language: language)
                ) {
                    HStack(alignment: .center, spacing: 6) {
                        Stepper(
                            "",
                            value: pollingIntervalBinding,
                            in: SettingsStore.pollingIntervalDisplayRange,
                            step: SettingsStore.pollingIntervalStep
                        )
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(height: 22)

                        TextField(
                            "",
                            value: pollingIntervalBinding,
                            format: .number.precision(.fractionLength(1))
                        )
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .controlSize(.small)
                        .frame(height: 22)

                        Text("s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        settingsCard(title: AppText.value(.settingsAbout, language: language)) {
            VStack(alignment: .leading, spacing: 8) {
                fieldRow(label: AppText.value(.settingsDeveloperName, language: language)) {
                    Text("rtfdev")
                        .foregroundStyle(.secondary)
                }

                fieldRow(label: AppText.value(.settingsDeveloperAddress, language: language)) {
                    Button(AppText.value(.settingsDeveloperAddressOpen, language: language)) {
                        openExternalURL(developerAddressURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                fieldRow(label: AppText.value(.settingsVersion, language: language)) {
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                }

                fieldRow(label: AppText.value(.settingsFeedback, language: language)) {
                    Button(AppText.value(.settingsSendFeedback, language: language)) {
                        openExternalURL(feedbackURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var clearOnSystemRestartRow: some View {
        fieldRow(
            label: AppText.value(.settingsClearOnSystemRestart, language: language),
            infoMessage: AppText.value(.settingsClearOnSystemRestartHint, language: language)
        ) {
            Toggle("", isOn: $settings.clearHistoryOnSystemRestart)
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var historyCapacityRow: some View {
        fieldRow(label: AppText.value(.settingsHistoryCapacity, language: language)) {
            HStack(alignment: .center, spacing: 6) {
                Stepper(
                    "",
                    value: historyCapacityBinding,
                    in: SettingsStore.maxHistoryItemsUIStepperRange,
                    step: SettingsStore.maxHistoryItemsStep
                )
                .labelsHidden()
                .controlSize(.small)
                .frame(height: 22)

                TextField(
                    "",
                    value: historyCapacityBinding,
                    format: .number
                )
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .controlSize(.small)
                .frame(height: 22)

                Text(AppText.value(.settingsHistoryCapacityUnit, language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hotkeySection: some View {
        settingsCard(
            title: AppText.value(.settingsGlobalHotkey, language: language),
            fixedHeight: compactCardHeight
        ) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)

                modifierMenu

                hotkeyKeyMenu
            }
            .font(.subheadline)

            if runtimeState.hotkeyRegistrationFailed {
                Text(AppText.value(.settingsHotkeyUnavailableHint, language: language))
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacySection: some View {
        settingsCard(
            title: AppText.value(.settingsPrivacy, language: language)
        ) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill((permissions.accessibilityGranted ? Color.green : Color.orange).opacity(0.16))
                            .frame(width: 30, height: 30)

                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(permissions.accessibilityGranted ? Color.green : Color.orange)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 6) {
                        accessibilityStatusChip
                        Text(privacyPermissionHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    if permissions.accessibilityGranted {
                        Button(AppText.value(.settingsPermissionEnabled, language: language)) {}
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .frame(height: permissionsButtonHeight)
                            .disabled(true)
                    } else {
                        Button(AppText.value(.settingsRequestPermission, language: language)) {
                            permissions.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .frame(height: permissionsButtonHeight)
                    }

                    Button(AppText.value(.settingsOpenPrivacySettings, language: language)) {
                        permissions.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(height: permissionsButtonHeight)
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
        fixedHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isCompact = fixedHeight != nil

        return VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isCompact ? 8 : 12)
        .frame(
            maxWidth: .infinity,
            minHeight: fixedHeight,
            maxHeight: fixedHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(settingsCardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
    }

    private func fieldRow<Content: View>(
        label: String,
        infoMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 4) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: SettingsLabelWidthPreferenceKey.self,
                                value: proxy.size.width
                            )
                        }
                    )
                .frame(width: labelColumnWidth, alignment: .leading)

                if let infoMessage {
                    InfoHelpButton(message: infoMessage)
                }
            }

            Spacer(minLength: 0)
            content()
                .fixedSize(horizontal: true, vertical: false)
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
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case (let short?, let build?) where !short.isEmpty && !build.isEmpty:
            return "\(short) (\(build))"
        case (let short?, _):
            return short
        case (_, let build?):
            return build
        default:
            return "1.0"
        }
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

    private var modifierMenu: some View {
        Menu {
            modifierMenuItem(title: modifierShortTitle(.command), modifier: .command)
            modifierMenuItem(title: modifierShortTitle(.option), modifier: .option)
            modifierMenuItem(title: modifierShortTitle(.control), modifier: .control)
            modifierMenuItem(title: modifierShortTitle(.shift), modifier: .shift)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(activeModifiersLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .modifier(HotkeyControlBackgroundModifier())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func modifierMenuItem(title: String, modifier: NSEvent.ModifierFlags) -> some View {
        Button {
            let isEnabled = settings.isHotkeyModifierEnabled(modifier)
            settings.setHotkeyModifier(modifier, enabled: !isEnabled)
        } label: {
            Text(settings.isHotkeyModifierEnabled(modifier) ? "✓ \(title)" : title)
        }
    }

    private var hotkeyKeyMenu: some View {
        Menu {
            ForEach(HotkeyCatalog.options) { option in
                Button {
                    settings.setHotkeyKeyCode(option.keyCode)
                } label: {
                    let selected = settings.hotkey.keyCode == option.keyCode
                    Text(selected ? "✓ \(option.label)" : option.label)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(
                    HotkeyCatalog.options.first(where: { $0.keyCode == settings.hotkey.keyCode })?.label ?? "V"
                )
                .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 34, alignment: .center)
            .frame(minWidth: 88)
            .modifier(HotkeyControlBackgroundModifier())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var activeModifiersLabel: String {
        let items: [(NSEvent.ModifierFlags, String)] = [
            (.command, modifierShortTitle(.command)),
            (.option, modifierShortTitle(.option)),
            (.control, modifierShortTitle(.control)),
            (.shift, modifierShortTitle(.shift))
        ]

        let enabled = items.compactMap { flag, title in
            settings.isHotkeyModifierEnabled(flag) ? title : nil
        }
        return enabled.joined(separator: "+")
    }

    private func modifierShortTitle(_ modifier: NSEvent.ModifierFlags) -> String {
        switch modifier {
        case .command:
            return language == .korean ? "Cmd" : "Cmd"
        case .option:
            return language == .korean ? "Opt" : "Opt"
        case .control:
            return language == .korean ? "Ctrl" : "Ctrl"
        case .shift:
            return AppText.value(.settingsShift, language: language)
        default:
            return ""
        }
    }

    private var settingsBackgroundColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.22, green: 0.22, blue: 0.23, alpha: 1)
                }
                return NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
            }
        )
    }

    private var settingsCardBackgroundColor: Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(srgbRed: 0.19, green: 0.19, blue: 0.2, alpha: 1)
                }
                return NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            }
        )
    }
}

private struct HotkeyControlBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
    }
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

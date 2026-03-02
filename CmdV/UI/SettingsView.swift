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
    let onTabSelectionChange: () -> Void

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
    @State private var activeInfoID: String?
    @State private var infoButtonMetadata: [String: InfoHelpButtonMetadata] = [:]
    @State private var infoBubbleHeight: CGFloat = 0
    @State private var lastInfoButtonTapAt = Date.distantPast
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
    private let infoBubbleWidth: CGFloat = 220
    private let infoBubbleIconHorizontalOffset: CGFloat = 20
    private let infoBubbleVerticalSpacing: CGFloat = 8
    private let minimumInfoBubbleHeight: CGFloat = 42
    private let aboutAppIconSize: CGFloat = 58
    private let aboutActionRowHeight: CGFloat = 28
    private let developerAddressURL = "https://github.com/ddhgo"
    private let githubRepositoryURL = "https://github.com/ddhgo/CmdV"
    private let sponsorURL = "https://github.com/sponsors/ddhgo"
    private let feedbackURL = "https://github.com/ddhgo/CmdV/issues/new/choose"

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
        .onPreferenceChange(InfoHelpButtonPreferenceKey.self) { values in
            infoButtonMetadata = values
        }
        .onPreferenceChange(InfoHelpBubbleHeightPreferenceKey.self) { measuredHeight in
            infoBubbleHeight = measuredHeight
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                guard Date().timeIntervalSince(lastInfoButtonTapAt) >= 0.15 else {
                    return
                }
                activeInfoID = nil
            }
        )
        .coordinateSpace(name: "SettingsViewSpace")
        .fixedSize(horizontal: false, vertical: true)
        .background(CmdVTheme.Colors.windowSurface)
        .clipShape(RoundedRectangle(cornerRadius: paneRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: paneRadius, style: .continuous)
                .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if let activeInfoID,
               let metadata = infoButtonMetadata[activeInfoID] {
                InfoHelpBubble(message: metadata.message, width: infoBubbleWidth)
                    .offset(
                        x: infoBubbleX(for: metadata.frame),
                        y: infoBubbleY(for: metadata.frame)
                    )
                    .zIndex(2)
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
    }

    private var settingsTabBar: some View {
        HStack(spacing: tabSpacing) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                let iconSize = isSelected ? 15.0 : 14.5
                let tabButtonSide = tabButtonLength

                Button {
                    guard selectedTab != tab else {
                        return
                    }
                    activeInfoID = nil
                    selectedTab = tab
                    onTabSelectionChange()
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
            VStack(alignment: .center, spacing: 7) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: aboutAppIconSize, height: aboutAppIconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)

                VStack(spacing: 1) {
                    Text("CmdV")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("\(AppText.value(.settingsVersion, language: language)) \(appVersionText)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text("by ddhgo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    aboutActionButton(
                        title: "GitHub",
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        destination: githubRepositoryURL
                    )
                    aboutActionButton(
                        title: AppText.value(.settingsDeveloperAddressOpen, language: language),
                        systemImage: "globe",
                        destination: developerAddressURL
                    )
                    aboutActionButton(
                        title: AppText.value(.settingsSendFeedback, language: language),
                        systemImage: "bubble.left.and.bubble.right",
                        destination: feedbackURL
                    )
                }
                .padding(.top, 3)

                Button(AppText.value(.settingsSponsorAuthor, language: language)) {
                    openExternalURL(sponsorURL)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func aboutActionButton(
        title: String,
        systemImage: String,
        destination: String
    ) -> some View {
        Button {
            openExternalURL(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 15)

                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: aboutActionRowHeight)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(CmdVTheme.Colors.controlSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
        let infoID = infoMessage.map { "\(label)|\($0)|\(infoPlacementLeading)" }

        return HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 4) {
                if let infoMessage, let infoID, infoPlacementLeading {
                    InfoHelpButton(
                        message: infoMessage,
                        infoID: infoID,
                        activeInfoID: $activeInfoID,
                        onTap: { lastInfoButtonTapAt = Date() }
                    )
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

                if let infoMessage, let infoID, !infoPlacementLeading {
                    InfoHelpButton(
                        message: infoMessage,
                        infoID: infoID,
                        activeInfoID: $activeInfoID,
                        onTap: { lastInfoButtonTapAt = Date() }
                    )
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

    private func infoBubbleX(for frame: CGRect) -> CGFloat {
        let preferred = frame.midX - infoBubbleIconHorizontalOffset
        let minimum = rootContentInset
        let maximum = fixedWindowWidth - rootContentInset - infoBubbleWidth
        return min(max(minimum, preferred), max(minimum, maximum))
    }

    private func infoBubbleY(for frame: CGRect) -> CGFloat {
        let bubbleHeight = max(minimumInfoBubbleHeight, infoBubbleHeight)
        let viewHeight = max(contentSize.height, 320)
        let minimum = rootContentInset
        let maximum = max(minimum, viewHeight - rootContentInset - bubbleHeight)
        let preferredBelow = frame.maxY + infoBubbleVerticalSpacing
        if preferredBelow <= maximum {
            return preferredBelow
        }

        let preferredAbove = frame.minY - infoBubbleVerticalSpacing - bubbleHeight
        if preferredAbove >= minimum {
            return preferredAbove
        }

        return min(max(preferredBelow, minimum), maximum)
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
    let infoID: String
    @Binding var activeInfoID: String?
    let onTap: () -> Void

    var body: some View {
        Image(systemName: "info.circle.fill")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 12, height: 12)
            .contentShape(Circle())
            .onTapGesture {
                onTap()
                if activeInfoID == infoID {
                    activeInfoID = nil
                } else {
                    activeInfoID = infoID
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: InfoHelpButtonPreferenceKey.self,
                        value: [
                            infoID: InfoHelpButtonMetadata(
                                frame: proxy.frame(in: .named("SettingsViewSpace")),
                                message: message
                            )
                        ]
                    )
                }
            )
            .help(message)
            .accessibilityLabel("설명 보기")
            .accessibilityValue(message)
    }
}

private struct InfoHelpBubble: View {
    let message: String
    let width: CGFloat

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CmdVTheme.Colors.cardSurface.opacity(0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CmdVTheme.Colors.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
            .allowsHitTesting(false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: InfoHelpBubbleHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
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

private struct InfoHelpButtonMetadata: Equatable {
    let frame: CGRect
    let message: String
}

private struct InfoHelpButtonPreferenceKey: PreferenceKey {
    static var defaultValue: [String: InfoHelpButtonMetadata] = [:]

    static func reduce(value: inout [String: InfoHelpButtonMetadata], nextValue: () -> [String: InfoHelpButtonMetadata]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct InfoHelpBubbleHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

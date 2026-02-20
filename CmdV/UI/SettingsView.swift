import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var permissions: PermissionsService
    @ObservedObject var runtimeState: AppRuntimeState

    let onClearHistory: () -> Void
    let onClose: () -> Void

    @State private var labelColumnWidth: CGFloat = 148
    private let compactCardHeight: CGFloat = 60

    private var language: AppLanguage {
        settings.appLanguage
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                generalSection
                compactControlsRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .onAppear {
            permissions.refreshStatus()
            settings.refreshLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings.refreshLaunchAtLoginStatus()
        }
        .onPreferenceChange(SettingsLabelWidthPreferenceKey.self) { measuredWidth in
            labelColumnWidth = min(164, max(136, measuredWidth))
        }
        .frame(width: settingsWindowSize.width, height: settingsWindowSize.height)
        .background(settingsBackgroundColor)
    }

    private var compactControlsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            hotkeySection
                .frame(maxWidth: .infinity, alignment: .topLeading)

            privacySection
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    static func preferredWindowSize(for language: AppLanguage) -> CGSize {
        switch language {
        case .english:
            return CGSize(width: 540, height: 560)
        case .korean:
            return CGSize(width: 540, height: 560)
        }
    }

    private var settingsWindowSize: CGSize {
        Self.preferredWindowSize(for: language)
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

                VStack(alignment: .leading, spacing: 4) {
                    clearOnSystemRestartRow

                    Text(AppText.value(.settingsClearOnSystemRestartHint, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                historyCapacityRow

                fieldRow(label: AppText.value(.settingsClipboardPolling, language: language)) {
                    HStack(spacing: 6) {
                        TextField(
                            "",
                            value: pollingIntervalBinding,
                            format: .number.precision(.fractionLength(1))
                        )
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)

                        Text("s")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Stepper(
                            "",
                            value: pollingIntervalBinding,
                            in: SettingsStore.pollingIntervalDisplayRange,
                            step: SettingsStore.pollingIntervalStep
                        )
                            .labelsHidden()
                    }
                }

                Text(AppText.value(.settingsClipboardPollingHint, language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var clearOnSystemRestartRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(AppText.value(.settingsClearOnSystemRestart, language: language))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.92)

            Spacer(minLength: 0)

            Toggle("", isOn: $settings.clearHistoryOnSystemRestart)
                .labelsHidden()
                .toggleStyle(.switch)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var historyCapacityRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(AppText.historyCapacity(settings.maxHistoryItems, language: language))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Stepper(
                "",
                value: $settings.maxHistoryItems,
                in: SettingsStore.maxHistoryItemsUIStepperRange,
                step: SettingsStore.maxHistoryItemsStep
            )
                .labelsHidden()
        }
    }

    private var hotkeySection: some View {
        settingsCard(
            title: AppText.value(.settingsGlobalHotkey, language: language),
            fixedHeight: compactCardHeight
        ) {
            VStack(alignment: .leading, spacing: 6) {
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
    }

    private var privacySection: some View {
        settingsCard(
            title: AppText.value(.settingsPrivacy, language: language),
            fixedHeight: compactCardHeight
        ) {
            VStack(alignment: .leading, spacing: 9) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        accessibilityStatusChip

                        Spacer(minLength: 0)

                        Button(AppText.value(.settingsRequestPermission, language: language)) {
                            permissions.requestAccessibilityPermission()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        accessibilityStatusChip

                        Button(AppText.value(.settingsRequestPermission, language: language)) {
                            permissions.requestAccessibilityPermission()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

            }
        }
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
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

            Spacer(minLength: 0)
            content()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var accessibilityStatusChip: some View {
        let granted = permissions.accessibilityGranted
        let statusText: String
        switch language {
        case .english:
            statusText = granted ? "Enabled" : "Missing"
        case .korean:
            statusText = granted ? "활성화됨" : "없음"
        }
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

    private var hotkeyKeyBinding: Binding<UInt32> {
        Binding(
            get: { settings.hotkey.keyCode },
            set: { settings.setHotkeyKeyCode($0) }
        )
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
            .frame(width: 82, height: 34, alignment: .center)
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

private struct SettingsLabelWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

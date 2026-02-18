import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var permissions: PermissionsService
    @ObservedObject var runtimeState: AppRuntimeState

    let onClearHistory: () -> Void
    let onClose: () -> Void

    @State private var labelColumnWidth: CGFloat = 148

    private var language: AppLanguage {
        settings.appLanguage
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                generalSection
                hotkeySection
                privacySection
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
        .onPreferenceChange(SettingsLabelWidthPreferenceKey.self) { measuredWidth in
            labelColumnWidth = min(164, max(136, measuredWidth))
        }
        .frame(width: settingsWindowSize.width, height: settingsWindowSize.height)
        .background(settingsBackgroundColor)
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

                fieldRow(label: AppText.value(.settingsPauseRecording, language: language)) {
                    Toggle("", isOn: $settings.isRecordingPaused)
                        .labelsHidden()
                        .toggleStyle(.switch)
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

                        Stepper("", value: pollingIntervalBinding, in: 0.2...1.5, step: 0.1)
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

                HStack {
                    Spacer(minLength: 0)

                    Button(role: .destructive, action: onClearHistory) {
                        Text(AppText.value(.settingsClearHistory, language: language))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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

            Stepper("", value: $settings.maxHistoryItems, in: 50...1000, step: 10)
                .labelsHidden()
        }
    }

    private var hotkeySection: some View {
        settingsCard(title: AppText.value(.settingsGlobalHotkey, language: language)) {
            VStack(alignment: .leading, spacing: 6) {
                fieldRow(label: AppText.value(.settingsHotkeyKey, language: language)) {
                    HStack(spacing: 12) {
                        HStack(spacing: 12) {
                            hotkeyModifierToggle(title: modifierShortTitle(.command), modifier: .command)
                            hotkeyModifierToggle(title: modifierShortTitle(.option), modifier: .option)
                            hotkeyModifierToggle(title: modifierShortTitle(.control), modifier: .control)
                            hotkeyModifierToggle(title: modifierShortTitle(.shift), modifier: .shift)
                        }

                        Picker("", selection: hotkeyKeyBinding) {
                            ForEach(HotkeyCatalog.options) { option in
                                Text(option.label)
                                    .tag(option.keyCode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 96, alignment: .leading)
                    }
                    .font(.subheadline)
                }

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
        settingsCard(title: AppText.value(.settingsPrivacy, language: language)) {
            VStack(alignment: .leading, spacing: 9) {
                Text(AppText.value(.settingsAutoPaste, language: language))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        accessibilityStatusChip

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Button(AppText.value(.settingsRequestPermission, language: language)) {
                                permissions.requestAccessibilityPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(AppText.value(.settingsOpenPrivacySettings, language: language)) {
                                permissions.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        accessibilityStatusChip

                        HStack(spacing: 8) {
                            Button(AppText.value(.settingsRequestPermission, language: language)) {
                                permissions.requestAccessibilityPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(AppText.value(.settingsOpenPrivacySettings, language: language)) {
                                permissions.openAccessibilitySettings()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                Text(AppText.value(.settingsNoPermissionHint, language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                settings.pollingInterval = min(1.5, max(0.2, rounded))
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

    private func modifierBinding(_ modifier: NSEvent.ModifierFlags) -> Binding<Bool> {
        Binding(
            get: { settings.isHotkeyModifierEnabled(modifier) },
            set: { settings.setHotkeyModifier(modifier, enabled: $0) }
        )
    }

    private func hotkeyModifierToggle(
        title: String,
        modifier: NSEvent.ModifierFlags
    ) -> some View {
        Toggle(title, isOn: modifierBinding(modifier))
            .toggleStyle(.checkbox)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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

private struct SettingsLabelWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

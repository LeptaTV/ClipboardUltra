import SwiftUI

struct SettingsView: View {
    @AppStorage("shortcutKeyCode") private var keyCode: Int = 0
    @AppStorage("shortcutModifiers") private var modifiersRaw: Int = 0
    @AppStorage("expirationDays") private var expirationDays: Int = 0
    @AppStorage("expirationMinutes") private var expirationMinutes: Int = 0
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("blockSensitiveLookingContent") private var blockSensitiveLookingContent: Bool = true

    @State private var keyCodeBinding: Int = 0
    @State private var modifiersBinding: UInt = 0
    @State private var launchAtLoginAvailable = true
    @State private var customBundleId = ""
    @State private var excludedBundleIdsState: [String] = []

    @State private var selectedExpirationOption: ExpirationOption = .never
    @State private var showCustomMinutesSheet = false
    @State private var customMinutesInput = ""

    let commonSensitiveApps: [(name: String, bundleId: String)] = [
        ("1Password", "com.1password.1password"),
        ("Bitwarden", "com.bitwarden.desktop"),
        ("Keychain Access", "com.apple.keychainaccess"),
        ("NordPass", "com.nordsec.nordpass")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    donationHeader

                    Divider()

                    shortcutSection

                    Divider()

                    launchAtLoginSection

                    Divider()

                    autoDeleteSection

                    Divider()

                    sensitiveAppsSection

                    Divider()

                    customBundleSection

                    Divider()

                    privacySection

                    if !excludedBundleIdsState.isEmpty {
                        Divider()
                        activeExclusionsSection
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .background(Color.clear)
        }
        .preferredColorScheme(
            (UserDefaults.standard.string(forKey: "preferredColorScheme") ?? "dark") == "dark" ? .dark : .light
        )
        .sheet(isPresented: $showCustomMinutesSheet) {
            customMinutesDialog
        }
        .onAppear {
            keyCodeBinding = keyCode
            modifiersBinding = UInt(modifiersRaw)
            refreshExcludedBundleIds()
            syncExpirationSelectionFromStorage()

            if #available(macOS 13.0, *) {
                launchAtLoginAvailable = true
                launchAtLogin = LaunchAtLoginManager.shared.isEnabled
            } else {
                launchAtLoginAvailable = false
                launchAtLogin = false
            }
        }
    }

    private var donationHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Support ClipboardUltra")
                .font(.system(size: 11.5, weight: .semibold))

            Button {
                DonationManager.openDonationPage()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11))

                    Text("Buy me a coffee")
                        .font(.system(size: 11, weight: .medium))

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Global Shortcut")
                .font(.system(size: 11.5, weight: .semibold))

            Text("Show the popover from anywhere.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)

            ShortcutRecorderView(
                keyCode: $keyCodeBinding,
                modifiers: $modifiersBinding
            )
            .frame(height: 30)
            .onChange(of: keyCodeBinding) { _, newValue in
                keyCode = newValue
                ShortcutManager.shared.reload()
            }
            .onChange(of: modifiersBinding) { _, newValue in
                modifiersRaw = Int(newValue)
                ShortcutManager.shared.reload()
            }
        }
    }

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Launch at login")
                .font(.system(size: 11.5, weight: .semibold))

            Toggle("Open ClipboardUltra when I log in", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    let success = LaunchAtLoginManager.shared.setEnabled(newValue)
                    launchAtLogin = success ? newValue : LaunchAtLoginManager.shared.isEnabled
                }
            ))
            .font(.system(size: 11))
            .disabled(!launchAtLoginAvailable)

            if !launchAtLoginAvailable {
                Text("Available on macOS 13 or later.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var autoDeleteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Auto-delete")
                .font(.system(size: 11.5, weight: .semibold))

            Picker("Auto-delete", selection: Binding(
                get: { selectedExpirationOption },
                set: { newValue in
                    if newValue == .custom {
                        customMinutesInput = expirationMinutes > 0 ? "\(expirationMinutes)" : ""
                        showCustomMinutesSheet = true
                    } else {
                        applyExpirationOption(newValue)
                    }
                }
            )) {
                ForEach(ExpirationOption.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Text(expirationDescription)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
    }

    private var sensitiveAppsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Exclude sensitive apps")
                .font(.system(size: 11.5, weight: .semibold))

            Text("Copies from these apps won't be saved.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                ForEach(commonSensitiveApps, id: \.bundleId) { app in
                    SensitiveAppRow(
                        name: app.name,
                        bundleId: app.bundleId,
                        isEnabled: excludedBundleIdsState.contains(app.bundleId),
                        onToggle: {
                            toggleBundleId(app.bundleId)
                        }
                    )
                }
            }
        }
    }

    private var customBundleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Custom bundle ID")
                .font(.system(size: 11.5, weight: .semibold))

            Text("Add an app manually if its toggle is missing or not working.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("com.example.app", text: $customBundleId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                Button("Add") {
                    addCustomBundleId()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(customBundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Extra privacy")
                .font(.system(size: 11.5, weight: .semibold))

            Toggle("Block content that looks like passwords or secrets", isOn: $blockSensitiveLookingContent)
                .font(.system(size: 11))

            Text("Useful when passwords are copied from browser extensions or autofill instead of the desktop password manager.")
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
    }

    private var activeExclusionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active exclusions")
                .font(.system(size: 11.5, weight: .semibold))

            ForEach(excludedBundleIdsState, id: \.self) { bundleId in
                HStack(spacing: 8) {
                    Text(bundleId)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)

                    Spacer()

                    Button {
                        removeBundleId(bundleId)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var customMinutesDialog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom auto-delete")
                .font(.system(size: 13.5, weight: .semibold))

            Text("Enter the number of minutes before unpinned items are deleted.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Minutes", text: $customMinutesInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onChange(of: customMinutesInput) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    let capped = String(filtered.prefix(6))
                    if capped != newValue {
                        customMinutesInput = capped
                    }
                }

            HStack {
                Spacer()

                Button("Cancel") {
                    showCustomMinutesSheet = false
                    syncExpirationSelectionFromStorage()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveCustomMinutes()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidCustomMinutes(customMinutesInput))
            }
        }
        .padding(16)
        .frame(width: 270)
    }

    private var expirationDescription: String {
        switch selectedExpirationOption {
        case .tenMinutes:
            return "Unpinned items are deleted after 10 minutes."
        case .oneHour:
            return "Unpinned items are deleted after 1 hour."
        case .oneDay:
            return "Unpinned items are deleted after 1 day."
        case .sevenDays:
            return "Unpinned items are deleted after 7 days."
        case .oneMonth:
            return "Unpinned items are deleted after 1 month."
        case .never:
            return "Clipboard history is kept until you delete it manually."
        case .custom:
            return expirationMinutes > 0
                ? "Unpinned items are deleted after \(expirationMinutes) minute\(expirationMinutes == 1 ? "" : "s")."
                : "Set a custom duration in minutes."
        }
    }

    private func syncExpirationSelectionFromStorage() {
        if expirationMinutes > 0 {
            switch expirationMinutes {
            case 10:
                selectedExpirationOption = .tenMinutes
            case 60:
                selectedExpirationOption = .oneHour
            default:
                selectedExpirationOption = .custom
            }
        } else {
            switch expirationDays {
            case 1:
                selectedExpirationOption = .oneDay
            case 7:
                selectedExpirationOption = .sevenDays
            case 30:
                selectedExpirationOption = .oneMonth
            default:
                selectedExpirationOption = .never
            }
        }
    }

    private func applyExpirationOption(_ option: ExpirationOption) {
        selectedExpirationOption = option

        switch option {
        case .tenMinutes:
            expirationMinutes = 10
            expirationDays = 0
        case .oneHour:
            expirationMinutes = 60
            expirationDays = 0
        case .oneDay:
            expirationMinutes = 0
            expirationDays = 1
        case .sevenDays:
            expirationMinutes = 0
            expirationDays = 7
        case .oneMonth:
            expirationMinutes = 0
            expirationDays = 30
        case .never:
            expirationMinutes = 0
            expirationDays = 0
        case .custom:
            break
        }
    }

    private func saveCustomMinutes() {
        let trimmed = customMinutesInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmed), minutes > 0, minutes <= 999999 else { return }

        expirationMinutes = minutes
        expirationDays = 0
        selectedExpirationOption = .custom
        showCustomMinutesSheet = false
    }

    private func isValidCustomMinutes(_ value: String) -> Bool {
        guard let minutes = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return minutes > 0 && minutes <= 999999
    }

    private func refreshExcludedBundleIds() {
        excludedBundleIdsState = (UserDefaults.standard.stringArray(forKey: "excludedBundleIds") ?? [])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted()
    }

    private func saveExcludedBundleIds(_ newValue: [String]) {
        let cleaned = Array(Set(newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }))
            .filter { !$0.isEmpty }
            .sorted()

        excludedBundleIdsState = cleaned
        UserDefaults.standard.set(cleaned, forKey: "excludedBundleIds")
    }

    private func toggleBundleId(_ bundleId: String) {
        var current = Set(excludedBundleIdsState)

        if current.contains(bundleId) {
            current.remove(bundleId)
        } else {
            current.insert(bundleId)
        }

        saveExcludedBundleIds(Array(current))
    }

    private func addCustomBundleId() {
        let cleaned = customBundleId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !cleaned.isEmpty else { return }

        var current = Set(excludedBundleIdsState)
        current.insert(cleaned)

        saveExcludedBundleIds(Array(current))
        customBundleId = ""
    }

    private func removeBundleId(_ bundleId: String) {
        var current = Set(excludedBundleIdsState)
        current.remove(bundleId)
        saveExcludedBundleIds(Array(current))
    }
}

private enum ExpirationOption: CaseIterable {
    case tenMinutes
    case oneHour
    case oneDay
    case sevenDays
    case oneMonth
    case never
    case custom

    var title: String {
        switch self {
        case .tenMinutes: return "10 min"
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        case .sevenDays: return "7 days"
        case .oneMonth: return "1 month"
        case .never: return "Never"
        case .custom: return "Custom"
        }
    }
}

struct SensitiveAppRow: View {
    let name: String
    let bundleId: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.primary)

                    Text(bundleId)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .quaternarySystemFill).opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

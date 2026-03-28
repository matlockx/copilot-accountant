import SwiftUI
import ServiceManagement

/// Settings view for configuring the app
struct SettingsView: View {
    @ObservedObject var tracker: UsageTracker
    @State private var username: String
    @State private var token: String = ""
    @State private var showToken: Bool = false
    @State private var revealedSavedToken: String = ""
    @State private var monthlyBudget: String
    @State private var pollingInterval: String
    @State private var notificationsEnabled: Bool
    @State private var alertAt80: Bool
    @State private var alertAt90: Bool
    @State private var customAlerts: [CustomAlertThreshold]
    @State private var notifyEveryPercent: Bool
    @State private var launchAtLogin: Bool
    @State private var showingTokenSaved = false
    @State private var showingValidationAlert = false
    @State private var validationAlertTitle = SettingsAlertConfiguration.failureTitle
    @State private var validationMessage = ""
    @State private var isValidating = false
    @State private var savedTokenPreview: String = ""
    
    private let keychainService = KeychainService()
    
    init(tracker: UsageTracker) {
        self.tracker = tracker
        _username = State(initialValue: tracker.config.username)
        _monthlyBudget = State(initialValue: String(tracker.config.monthlyBudget))
        _pollingInterval = State(initialValue: String(tracker.config.pollingIntervalMinutes))
        _notificationsEnabled = State(initialValue: tracker.config.notificationsEnabled)
        _alertAt80 = State(initialValue: tracker.config.alertAt80Percent)
        _alertAt90 = State(initialValue: tracker.config.alertAt90Percent)
        _customAlerts = State(initialValue: tracker.config.normalizedCustomAlerts)
        _notifyEveryPercent = State(initialValue: tracker.config.notifyEveryPercent)
        _launchAtLogin = State(initialValue: tracker.config.launchAtLogin)
        
        // Load saved token preview
        if let savedToken = try? KeychainService().loadToken() {
            let prefix = String(savedToken.prefix(12))
            let suffix = String(savedToken.suffix(4))
            _savedTokenPreview = State(initialValue: "\(prefix)...\(suffix)")
            _revealedSavedToken = State(initialValue: savedToken)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    settingsSection("GitHub Account") {
                        settingsGrid {
                            GridRow {
                                gridLabel("GitHub Username")
                                TextField("GitHub Username", text: $username)
                                    .textFieldStyle(.roundedBorder)
                                    .textContentType(.username)
                            }

                            GridRow {
                                gridLabel("Personal Access Token")
                                trailingControlRow {
                                    HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                        tokenField
                                        Button(action: toggleTokenVisibility) {
                                            Image(systemName: showToken ? "eye.slash" : "eye")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help(showToken ? "Hide saved token" : "Show saved token")
                                    }
                                }
                            }

                            if !savedTokenPreview.isEmpty {
                                GridRow {
                                    gridLabel("Saved token")
                                    trailingControlRow {
                                        HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                            Text(showToken ? revealedSavedToken : savedTokenPreview.isEmpty ? SettingsViewConfiguration.hiddenTokenMask : savedTokenPreview)
                                                .font(.caption.monospaced())
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                            Button("Delete") { deleteToken() }
                                                .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                        }
                                    }
                                }
                            }

                            GridRow {
                                gridLabel("")
                                trailingControlRow {
                                    HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                        if showingTokenSaved {
                                            Text("Saved")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                        }

                                        if isValidating {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        }

                                        Button("Save Token") { saveToken() }
                                            .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                            .disabled(token.isEmpty)

                                        Button("Validate") {
                                            Task { await validateToken() }
                                        }
                                        .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                        .disabled(username.isEmpty || !keychainService.hasToken())
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            DisclosureGroup("How to create a token") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Go to github.com/settings/tokens")
                                    Text("2. Click 'Generate new token' → 'Fine-grained token'")
                                    Text("3. Set expiration (recommend 90 days)")
                                    Text("4. Under 'Account permissions', enable:")

                                    VStack(alignment: .leading, spacing: 4) {
                                        Label("Plan → Read-only", systemImage: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    .padding(.leading, 16)
                                    .font(.caption)

                                    Text("5. Click 'Generate token' and copy it")

                                    Divider()

                                    Text("Note: Your Copilot must be a personal subscription (you pay directly). Organization-managed Copilot requires different setup.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button("Open GitHub Tokens") {
                                        if let url = URL(string: "https://github.com/settings/tokens?type=beta") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.link)
                                }
                                .font(.callout)
                                .padding(.top, 8)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    settingsSection("Budget Settings") {
                        settingsGrid {
                            GridRow {
                                gridLabel("Monthly Budget")
                                trailingControlRow {
                                    HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                    TextField("300", text: $monthlyBudget)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: SettingsViewConfiguration.valueFieldWidth)
                                        .multilineTextAlignment(.trailing)
                                    Text("requests")
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }

                            GridRow {
                                gridLabel("Check every")
                                trailingControlRow {
                                    HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                    TextField("5", text: $pollingInterval)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: SettingsViewConfiguration.valueFieldWidth)
                                        .multilineTextAlignment(.trailing)
                                    Text("minutes")
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    settingsSection("Notifications") {
                        settingsGrid {
                            toggleGridRow("Enable Notifications", isOn: $notificationsEnabled)
                            toggleGridRow("Alert at 80% usage", isOn: $alertAt80, disabled: !notificationsEnabled)
                            toggleGridRow("Alert at 90% usage", isOn: $alertAt90, disabled: !notificationsEnabled)
                            toggleGridRow(NotificationSettingsConfiguration.everyPercentToggleTitle, isOn: $notifyEveryPercent, disabled: !notificationsEnabled)

                            GridRow(alignment: .top) {
                                gridLabel(NotificationSettingsConfiguration.customAlertFieldTitle)
                                trailingControlRow {
                                    VStack(alignment: .trailing, spacing: SettingsViewConfiguration.formFieldSpacing) {
                                    ForEach($customAlerts) { $alert in
                                        HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                            TextField("75", value: $alert.percent, formatter: integerFormatter)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: NotificationSettingsConfiguration.customAlertFieldWidth)
                                                .multilineTextAlignment(.trailing)
                                                .disabled(!notificationsEnabled)
                                            Text(NotificationSettingsConfiguration.customAlertSuffix)
                                                .foregroundColor(.secondary)
                                            Toggle(NotificationSettingsConfiguration.customAlertToggleTitle, isOn: $alert.isEnabled)
                                                .toggleStyle(.checkbox)
                                                .labelsHidden()
                                                .frame(width: SettingsViewConfiguration.toggleColumnWidth)
                                                .disabled(!notificationsEnabled)
                                            Button(NotificationSettingsConfiguration.removeCustomAlertButtonTitle) {
                                                removeCustomAlert(id: alert.id)
                                            }
                                            .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                            .disabled(!notificationsEnabled)
                                        }
                                    }

                                    Button(NotificationSettingsConfiguration.addCustomAlertButtonTitle) {
                                        addCustomAlert()
                                    }
                                    .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!notificationsEnabled)
                                    }
                                }
                            }

                            GridRow {
                                gridLabel("")
                                trailingControlRow {
                                    Button(NotificationSettingsConfiguration.testButtonTitle) {
                                        Task {
                                            _ = await NotificationService.shared.requestAuthorization()
                                            tracker.sendTestNotification()
                                        }
                                    }
                                    .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                    .disabled(!notificationsEnabled)
                                }
                            }
                        }
                    }

                    settingsSection("Startup") {
                        settingsGrid {
                            toggleGridRow("Launch at Login", isOn: $launchAtLogin)
                        }
                    }

                    settingsSection("Troubleshooting") {
                        settingsGrid {
                            GridRow {
                                gridLabel("Log file")
                                HStack(spacing: SettingsViewConfiguration.formFieldSpacing) {
                                    Text(LogService.shared.logFilePath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button("Open in Finder") {
                                        let url = URL(fileURLWithPath: LogService.shared.logFilePath)
                                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                                    }
                                    .frame(width: SettingsViewConfiguration.utilityButtonWidth)
                                }
                            }
                        }
                    }
                }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color.accentColor.opacity(0.07),
                        Color(nsColor: .underPageBackgroundColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()

                Button(SettingsViewConfiguration.footerButtonTitles[0]) {
                    NSApplication.shared.keyWindow?.close()
                }

                Button(SettingsViewConfiguration.footerButtonTitles[1]) {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: SettingsViewConfiguration.footerHeight)
            .background(.ultraThinMaterial)
        }
        .frame(width: SettingsViewConfiguration.windowSize.width, height: SettingsViewConfiguration.windowSize.height)
        .alert(validationAlertTitle, isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    private var tokenField: some View {
        Group {
            if showToken {
                TextField("Personal Access Token (ghp_...)", text: Binding(
                    get: { token.isEmpty ? revealedSavedToken : token },
                    set: { token = $0 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .frame(width: SettingsViewConfiguration.toggleColumnWidth)
            } else {
                ZStack(alignment: .leading) {
                    TextField("", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .foregroundColor(.clear)
                        .frame(width: SettingsViewConfiguration.toggleColumnWidth)

                    if token.isEmpty {
                        Text(revealedSavedToken.isEmpty ? "Personal Access Token (ghp_...)" : SettingsViewConfiguration.hiddenTokenMask)
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.leading, 4)
                    } else {
                        Text(String(repeating: "•", count: min(token.count, 40)))
                            .foregroundColor(.primary)
                            .padding(.leading, 4)
                    }
                }
            }
        }
    }

    private var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color.accentColor.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private func settingsGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: SettingsViewConfiguration.formFieldSpacing, verticalSpacing: SettingsViewConfiguration.formFieldSpacing) {
            content()
        }
    }

    private func gridLabel(_ title: String) -> some View {
        Text(title)
            .frame(width: SettingsViewConfiguration.formLabelWidth, alignment: .leading)
            .foregroundColor(title.isEmpty ? .clear : .primary)
    }

    private func trailingControlRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
        }
        .frame(width: SettingsViewConfiguration.notificationControlWidth, alignment: .trailing)
    }

    private func toggleGridRow(_ title: String, isOn: Binding<Bool>, disabled: Bool = false) -> GridRow<TupleView<(some View, some View)>> {
        GridRow {
            gridLabel(title)
            trailingControlRow {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .disabled(disabled)
            }
        }
    }

    private func addCustomAlert() {
        customAlerts.append(CustomAlertThreshold(percent: 75, isEnabled: true))
    }

    private func removeCustomAlert(id: UUID) {
        customAlerts.removeAll { $0.id == id }
    }
    
    private func saveToken() {
        guard !token.isEmpty else { return }
        
        // Trim whitespace from token
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try keychainService.saveToken(cleanToken)
            showingTokenSaved = true
            
            // Update preview
            let prefix = String(cleanToken.prefix(12))
            let suffix = String(cleanToken.suffix(4))
            savedTokenPreview = "\(prefix)...\(suffix)"
            revealedSavedToken = cleanToken

            token = "" // Clear the field for security
            
            // Hide the message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingTokenSaved = false
            }
        } catch {
            validationAlertTitle = SettingsAlertConfiguration.failureTitle
            validationMessage = "Failed to save token: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }
    
    private func deleteToken() {
        do {
            try keychainService.deleteToken()
            savedTokenPreview = ""
            revealedSavedToken = ""
            showToken = false
        } catch {
            validationAlertTitle = SettingsAlertConfiguration.failureTitle
            validationMessage = "Failed to delete token: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }
    
    private func validateToken() async {
        guard !username.isEmpty else { return }
        guard let token = try? keychainService.loadToken() else {
            validationAlertTitle = SettingsAlertConfiguration.failureTitle
            validationMessage = "No token found. Please save your token first."
            showingValidationAlert = true
            return
        }
        
        isValidating = true
        let apiService = GitHubAPIService()
        let result = await apiService.validateToken(username: username, token: token)
        isValidating = false
        
        if result.success {
            validationAlertTitle = SettingsAlertConfiguration.successTitle
            validationMessage = "Token is valid!"
            showingValidationAlert = true
        } else {
            validationAlertTitle = SettingsAlertConfiguration.failureTitle
            validationMessage = result.error ?? "Token validation failed. Check your username and token."
            showingValidationAlert = true
        }
    }

    private func toggleTokenVisibility() {
        guard !revealedSavedToken.isEmpty else { return }
        showToken.toggle()
    }
    
    private func saveSettings() {
        tracker.config.username = username
        tracker.config.monthlyBudget = Int(monthlyBudget) ?? 300
        tracker.config.pollingIntervalMinutes = Int(pollingInterval) ?? 5
        tracker.config.notificationsEnabled = notificationsEnabled
        tracker.config.alertAt80Percent = alertAt80
        tracker.config.alertAt90Percent = alertAt90
        tracker.config.customAlerts = customAlerts
        tracker.config.customAlerts = tracker.config.normalizedCustomAlerts
        customAlerts = tracker.config.normalizedCustomAlerts
        tracker.config.notifyEveryPercent = notifyEveryPercent
        tracker.config.launchAtLogin = launchAtLogin
        updateLaunchAtLoginRegistration(enabled: launchAtLogin)
        
        tracker.saveConfig()
        
        // Close window
        NSApplication.shared.keyWindow?.close()
    }

    private func updateLaunchAtLoginRegistration(enabled: Bool) {
        guard LaunchAtLoginConfiguration.usesServiceManagement else { return }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                validationAlertTitle = SettingsAlertConfiguration.failureTitle
                validationMessage = "Failed to update launch at login: \(error.localizedDescription)"
                showingValidationAlert = true
            }
        }
    }
}

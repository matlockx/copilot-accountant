import SwiftUI

/// Settings view for configuring the app
struct SettingsView: View {
    @ObservedObject var tracker: UsageTracker
    @State private var username: String
    @State private var token: String = ""
    @State private var showToken: Bool = false
    @State private var monthlyBudget: String
    @State private var pollingInterval: String
    @State private var notificationsEnabled: Bool
    @State private var alertAt80: Bool
    @State private var alertAt90: Bool
    @State private var launchAtLogin: Bool
    @State private var showingTokenSaved = false
    @State private var showingValidationError = false
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
        _launchAtLogin = State(initialValue: tracker.config.launchAtLogin)
        
        // Load saved token preview
        if let savedToken = try? KeychainService().loadToken() {
            let prefix = String(savedToken.prefix(12))
            let suffix = String(savedToken.suffix(4))
            _savedTokenPreview = State(initialValue: "\(prefix)...\(suffix)")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("GitHub Account") {
                    TextField("GitHub Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)

                    HStack {
                        if showToken {
                            TextField("Personal Access Token (ghp_...)", text: $token)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.none)
                                .autocorrectionDisabled()
                        } else {
                            ZStack(alignment: .leading) {
                                TextField("", text: $token)
                                    .textFieldStyle(.roundedBorder)
                                    .textContentType(.none)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.clear)

                                if token.isEmpty {
                                    Text("Personal Access Token (ghp_...)")
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.leading, 4)
                                } else {
                                    Text(String(repeating: "•", count: min(token.count, 40)))
                                        .foregroundColor(.primary)
                                        .padding(.leading, 4)
                                }
                            }
                        }

                        Button(action: { showToken.toggle() }) {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(showToken ? "Hide token" : "Show token")
                    }

                    if !savedTokenPreview.isEmpty {
                        HStack {
                            Text("Saved token:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(savedTokenPreview)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Delete") {
                                deleteToken()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }

                    HStack {
                        Button("Save Token") {
                            saveToken()
                        }
                        .disabled(token.isEmpty)

                        if showingTokenSaved {
                            Text("Saved")
                                .foregroundColor(.green)
                                .font(.caption)
                        }

                        Spacer()

                        Button("Validate") {
                            Task {
                                await validateToken()
                            }
                        }
                        .disabled(username.isEmpty || !keychainService.hasToken())

                        if isValidating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

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

                            HStack {
                                Button("Open GitHub Tokens") {
                                    if let url = URL(string: "https://github.com/settings/tokens?type=beta") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.link)
                            }
                        }
                        .font(.callout)
                        .padding(.vertical, 4)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section("Budget Settings") {
                    HStack {
                        Text("Monthly Budget:")
                        TextField("300", text: $monthlyBudget)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("requests")
                    }

                    HStack {
                        Text("Check every:")
                        TextField("5", text: $pollingInterval)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("minutes")
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Alert at 80% usage", isOn: $alertAt80)
                        .disabled(!notificationsEnabled)
                    Toggle("Alert at 90% usage", isOn: $alertAt90)
                        .disabled(!notificationsEnabled)
                }

                Section("Startup") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                }

                Section("Troubleshooting") {
                    HStack {
                        Text("Log file:")
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
                    }
                }
            }
            .formStyle(.grouped)
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
            .background(.regularMaterial)
        }
        .frame(width: SettingsViewConfiguration.windowSize.width, height: SettingsViewConfiguration.windowSize.height)
        .alert("Validation Failed", isPresented: $showingValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
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
            
            token = "" // Clear the field for security
            
            // Hide the message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingTokenSaved = false
            }
        } catch {
            validationMessage = "Failed to save token: \(error.localizedDescription)"
            showingValidationError = true
        }
    }
    
    private func deleteToken() {
        do {
            try keychainService.deleteToken()
            savedTokenPreview = ""
        } catch {
            validationMessage = "Failed to delete token: \(error.localizedDescription)"
            showingValidationError = true
        }
    }
    
    private func validateToken() async {
        guard !username.isEmpty else { return }
        guard let token = try? keychainService.loadToken() else {
            validationMessage = "No token found. Please save your token first."
            showingValidationError = true
            return
        }
        
        isValidating = true
        let apiService = GitHubAPIService()
        let result = await apiService.validateToken(username: username, token: token)
        isValidating = false
        
        if result.success {
            validationMessage = "Token is valid!"
            showingValidationError = true
        } else {
            validationMessage = result.error ?? "Token validation failed. Check your username and token."
            showingValidationError = true
        }
    }
    
    private func saveSettings() {
        tracker.config.username = username
        tracker.config.monthlyBudget = Int(monthlyBudget) ?? 300
        tracker.config.pollingIntervalMinutes = Int(pollingInterval) ?? 5
        tracker.config.notificationsEnabled = notificationsEnabled
        tracker.config.alertAt80Percent = alertAt80
        tracker.config.alertAt90Percent = alertAt90
        tracker.config.launchAtLogin = launchAtLogin
        
        tracker.saveConfig()
        
        // Close window
        NSApplication.shared.keyWindow?.close()
    }
}

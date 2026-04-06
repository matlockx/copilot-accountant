import Foundation
import Combine

enum FetchReason {
    case polling
    case manualRefresh

    var shouldSendMilestoneNotifications: Bool {
        switch self {
        case .polling:
            true
        case .manualRefresh:
            NotificationSettingsConfiguration.manualRefreshSendsMilestones
        }
    }
}

/// Main tracker that manages usage data and polling
@MainActor
class UsageTracker: ObservableObject {
    static let usageUpdatedNotification = Notification.Name("UsageUpdated")

    @Published var currentUsage: UsageResponse?
    @Published var dailyUsage: [DailyUsage] = []
    @Published var spendingBudget: SpendingBudgetSummary?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var lastUpdateTime: Date?
    @Published var config: BudgetConfig
    
    private let apiService = GitHubAPIService()
    private let keychainService = KeychainService()
    private let notificationService = NotificationService.shared
    private let userDefaults = UserDefaults.standard
    private let log = LogService.shared
    
    private var pollingTimer: Timer?
    // AIDEV-NOTE: Alert state extracted into AlertState struct for testability.
    // See AlertState.swift for the deduplication and reset logic.
    private var alertState = AlertState()
    
    private let configKey = "budgetConfig"
    private let dailyUsageKey = "cachedDailyUsage"
    private let lastUsageKey = "cachedUsage"
    private let alert80Key = "hasAlerted80"
    private let alert90Key = "hasAlerted90"
    private let alertCustomPercentagesKey = "alertedCustomPercentages"
    private let lastAlertedWholePercentKey = "lastAlertedWholePercent"
    
    init() {
        log.info("UsageTracker initializing")
        
        // Load config from UserDefaults
        if let data = userDefaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(BudgetConfig.self, from: data) {
            self.config = decoded
            log.info("Loaded config: username=\(decoded.username), budget=\(decoded.monthlyBudget)")
        } else {
            self.config = .default
            log.info("Using default config")
        }
        
        // Load cached data
        loadCachedData()
        
        // Load alert states
        alertState.hasAlerted80 = userDefaults.bool(forKey: alert80Key)
        alertState.hasAlerted90 = userDefaults.bool(forKey: alert90Key)
        if let storedCustomPercentages = userDefaults.array(forKey: alertCustomPercentagesKey) as? [Int] {
            alertState.alertedCustomPercentages = Set(storedCustomPercentages)
        }
        alertState.lastAlertedWholePercent = userDefaults.integer(forKey: lastAlertedWholePercentKey)
    }

    static func postUsageUpdatedNotification() {
        NotificationCenter.default.post(name: usageUpdatedNotification, object: nil)
    }
    
    /// Start polling for updates
    func startPolling() {
        stopPolling()
        
        log.info("Starting polling with interval: \(config.pollingIntervalMinutes) minutes")
        
        // Fetch immediately
        Task {
            await fetchUsage()
        }
        
        // Set up timer
        let interval = TimeInterval(config.pollingIntervalMinutes * 60)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchUsage()
            }
        }
    }
    
    /// Stop polling
    func stopPolling() {
        log.info("Stopping polling")
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    /// Fetch usage data from GitHub
    func fetchUsage(reason: FetchReason = .polling) async {
        log.info("Fetching usage data...")
        
        guard !config.username.isEmpty else {
            log.warning("Username not configured")
            lastError = "Username not configured"
            return
        }
        
        guard let token = try? keychainService.loadToken() else {
            log.warning("GitHub token not found in keychain")
            lastError = "GitHub token not found. Please configure in Settings."
            return
        }
        
        log.debug("Token loaded successfully (length: \(token.count) chars)")
        
        isLoading = true
        lastError = nil
        
        do {
            // Fetch current month usage
            let usage = try await apiService.fetchUsage(username: config.username, token: token)
            currentUsage = usage
            lastUpdateTime = Date()
            Self.postUsageUpdatedNotification()
            
            log.info("Usage fetched successfully: \(usage.totalRequests) total requests")
            
            // Save to cache
            if let encoded = try? JSONEncoder().encode(usage) {
                userDefaults.set(encoded, forKey: lastUsageKey)
            }
            
            // Compute spending budget from usage data + config
            updateSpendingBudget(from: usage)
            
            // Check for alerts
            checkAndSendAlerts(usage: usage, reason: reason)
            
            // Fetch daily breakdown in background
            Task {
                await fetchDailyUsage()
            }
            
        } catch {
            log.error("Failed to fetch usage: \(error.localizedDescription)")
            lastError = error.localizedDescription
            if config.notificationsEnabled {
                notificationService.sendNotification(
                    type: .apiError,
                    currentUsage: 0,
                    budget: config.monthlyBudget
                )
            }
        }
        
        isLoading = false
    }
    
    /// Fetch daily usage for charting
    private func fetchDailyUsage() async {
        guard !config.username.isEmpty,
              let token = try? keychainService.loadToken() else {
            return
        }
        
        do {
            let daily = try await apiService.fetchDailyUsage(username: config.username, token: token)
            dailyUsage = daily
            log.info("Daily usage fetched: \(daily.count) days")
            
            // Save to cache
            if let encoded = try? JSONEncoder().encode(daily) {
                userDefaults.set(encoded, forKey: dailyUsageKey)
            }
        } catch {
            log.error("Failed to fetch daily usage: \(error.localizedDescription)")
        }
    }
    
    /// Compute spending budget summary from usage data and user config.
    /// Called after each usage fetch and when loading cached data.
    /// Only produces a summary when the user has configured a dollar budget > 0.
    private func updateSpendingBudget(from usage: UsageResponse) {
        guard config.dollarBudget > 0 else {
            spendingBudget = nil
            return
        }
        
        let summary = SpendingBudgetSummary(
            budgetAmount: config.dollarBudget,
            amountSpent: usage.totalNetCost,
            preventFurtherUsage: config.preventFurtherUsage,
            pricePerRequest: usage.pricePerRequest
        )
        
        spendingBudget = summary
        log.info("Spending budget: $\(String(format: "%.2f", config.dollarBudget)), spent: $\(String(format: "%.2f", usage.totalNetCost)), prevent: \(config.preventFurtherUsage)")
    }
    
    /// Check thresholds and send alerts
    private func checkAndSendAlerts(usage: UsageResponse, reason: FetchReason) {
        let used = usage.totalRequests

        // AIDEV-NOTE: Alert logic delegated to AlertState for testability.
        // AlertState.processUsageUpdate returns which notifications to send
        // and mutates state to prevent duplicate notifications.
        let actions = alertState.processUsageUpdate(
            used: used,
            config: config,
            shouldSendMilestones: reason.shouldSendMilestoneNotifications
        )

        // Persist alert state to UserDefaults
        userDefaults.set(alertState.hasAlerted80, forKey: alert80Key)
        userDefaults.set(alertState.hasAlerted90, forKey: alert90Key)
        userDefaults.set(Array(alertState.alertedCustomPercentages).sorted(), forKey: alertCustomPercentagesKey)
        userDefaults.set(alertState.lastAlertedWholePercent, forKey: lastAlertedWholePercentKey)

        // Send notifications for each action
        for action in actions {
            switch action {
            case .milestone(let percent):
                notificationService.sendNotification(
                    type: .percentageMilestone(percent),
                    currentUsage: used,
                    budget: config.monthlyBudget
                )
            case .threshold80:
                notificationService.sendNotification(
                    type: .threshold80,
                    currentUsage: used,
                    budget: config.monthlyBudget
                )
            case .threshold90:
                notificationService.sendNotification(
                    type: .threshold90,
                    currentUsage: used,
                    budget: config.monthlyBudget
                )
            case .customThreshold(let percent):
                notificationService.sendNotification(
                    type: .customThreshold(percent),
                    currentUsage: used,
                    budget: config.monthlyBudget
                )
            }
        }

        // Reset soon alert (independent of alert state tracking)
        if config.notificationsEnabled && notificationService.shouldNotifyResetSoon() {
            notificationService.sendNotification(
                type: .resetSoon,
                currentUsage: used,
                budget: config.monthlyBudget
            )
        }
    }

    func sendTestNotification() {
        notificationService.sendNotification(type: .test, currentUsage: currentUsage?.totalRequests ?? 0, budget: config.monthlyBudget)
    }
    
    /// Save configuration
    func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            userDefaults.set(encoded, forKey: configKey)
        }
        
        // Restart polling with new interval
        startPolling()
    }
    
    /// Load cached data
    private func loadCachedData() {
        // Load last usage
        if let data = userDefaults.data(forKey: lastUsageKey),
           let decoded = try? JSONDecoder().decode(UsageResponse.self, from: data) {
            currentUsage = decoded
            Self.postUsageUpdatedNotification()
            
            // Compute spending budget from cached usage + config
            updateSpendingBudget(from: decoded)
        }
        
        // Load daily usage
        if let data = userDefaults.data(forKey: dailyUsageKey),
           let decoded = try? JSONDecoder().decode([DailyUsage].self, from: data) {
            dailyUsage = decoded
        }
    }
    
    /// Calculate days until reset (1st of next month)
    func daysUntilReset() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let firstOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
            return 0
        }
        
        let components = calendar.dateComponents([.day], from: now, to: firstOfNextMonth)
        return components.day ?? 0
    }
    
    /// Get model usage breakdown (sorted by count descending, then by name for stability)
    func getModelUsage() -> [ModelUsage] {
        guard let usage = currentUsage else { return [] }
        
        let byModel = usage.usageByModel
        let total = usage.totalRequests
        
        return byModel.map { model, count in
            let percentage = total > 0 ? (count / Double(total)) * 100.0 : 0
            return ModelUsage(modelName: model, requestCount: count, percentage: percentage)
        }.sorted { 
            if $0.requestCount != $1.requestCount {
                return $0.requestCount > $1.requestCount
            }
            return $0.modelName < $1.modelName
        }
    }
}

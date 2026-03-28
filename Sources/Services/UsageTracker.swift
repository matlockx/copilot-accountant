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
    private var hasAlerted80 = false
    private var hasAlerted90 = false
    private var alertedCustomPercentages: Set<Int> = []
    private var lastAlertedWholePercent = 0
    
    private let configKey = "budgetConfig"
    private let dailyUsageKey = "cachedDailyUsage"
    private let lastUsageKey = "cachedUsage"
    private let spendingBudgetKey = "cachedSpendingBudget"
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
        hasAlerted80 = userDefaults.bool(forKey: alert80Key)
        hasAlerted90 = userDefaults.bool(forKey: alert90Key)
        if let storedCustomPercentages = userDefaults.array(forKey: alertCustomPercentagesKey) as? [Int] {
            alertedCustomPercentages = Set(storedCustomPercentages)
        }
        lastAlertedWholePercent = userDefaults.integer(forKey: lastAlertedWholePercentKey)
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
            
            // Check for alerts
            checkAndSendAlerts(usage: usage, reason: reason)
            
            // Fetch daily breakdown and budgets in background
            Task {
                await fetchDailyUsage()
            }
            Task {
                await fetchSpendingBudgets(usage: usage)
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
    
    /// Fetch spending budgets from GitHub API
    private func fetchSpendingBudgets(usage: UsageResponse) async {
        guard !config.username.isEmpty,
              let token = try? keychainService.loadToken() else {
            return
        }
        
        do {
            guard let budgetResponse = try await apiService.fetchBudgets(username: config.username, token: token) else {
                log.info("No budget data available for this account")
                spendingBudget = nil
                userDefaults.removeObject(forKey: spendingBudgetKey)
                return
            }
            
            guard let premiumBudget = GitHubAPIService.findPremiumRequestBudget(in: budgetResponse) else {
                log.info("No premium request budget found among \(budgetResponse.budgets.count) budget(s)")
                spendingBudget = nil
                userDefaults.removeObject(forKey: spendingBudgetKey)
                return
            }
            
            let summary = SpendingBudgetSummary(
                budgetAmount: Double(premiumBudget.budgetAmount),
                amountSpent: usage.totalNetCost,
                preventFurtherUsage: premiumBudget.preventFurtherUsage,
                pricePerRequest: usage.pricePerRequest
            )
            
            spendingBudget = summary
            log.info("Spending budget: $\(premiumBudget.budgetAmount), spent: $\(String(format: "%.2f", usage.totalNetCost)), prevent: \(premiumBudget.preventFurtherUsage)")
            
            // Cache the budget response
            if let encoded = try? JSONEncoder().encode(premiumBudget) {
                userDefaults.set(encoded, forKey: spendingBudgetKey)
            }
        } catch {
            log.error("Failed to fetch spending budgets: \(error.localizedDescription)")
        }
    }
    
    /// Check thresholds and send alerts
    private func checkAndSendAlerts(usage: UsageResponse, reason: FetchReason) {
        let used = usage.totalRequests
        let threshold80 = config.threshold80
        let threshold90 = config.threshold90
        let wholePercentUsed = config.wholePercentUsed(for: used)
        
        let minimumTrackedThreshold = ([threshold80, threshold90] + config.customAlertThresholds.map { config.customThresholdValue(for: $0) }).min() ?? threshold80

        // Reset alerts if usage dropped enough to indicate a new month
        if used < minimumTrackedThreshold {
            hasAlerted80 = false
            hasAlerted90 = false
            alertedCustomPercentages = []
            lastAlertedWholePercent = 0
            userDefaults.set(false, forKey: alert80Key)
            userDefaults.set(false, forKey: alert90Key)
            userDefaults.removeObject(forKey: alertCustomPercentagesKey)
            userDefaults.set(0, forKey: lastAlertedWholePercentKey)
        }
        
        guard config.notificationsEnabled else { return }

        if config.notifyEveryPercent &&
            reason.shouldSendMilestoneNotifications &&
            wholePercentUsed > lastAlertedWholePercent &&
            wholePercentUsed > 0 &&
            !config.shouldSkipMilestoneNotification(for: wholePercentUsed) {
            notificationService.sendNotification(
                type: .percentageMilestone(wholePercentUsed),
                currentUsage: used,
                budget: config.monthlyBudget
            )
            lastAlertedWholePercent = wholePercentUsed
            userDefaults.set(wholePercentUsed, forKey: lastAlertedWholePercentKey)
        } else if wholePercentUsed > lastAlertedWholePercent {
            lastAlertedWholePercent = wholePercentUsed
            userDefaults.set(wholePercentUsed, forKey: lastAlertedWholePercentKey)
        }
        
        // 90% alert
        if config.alertAt90Percent && used >= threshold90 && !hasAlerted90 {
            notificationService.sendNotification(
                type: .threshold90,
                currentUsage: used,
                budget: config.monthlyBudget
            )
            hasAlerted90 = true
            userDefaults.set(true, forKey: alert90Key)
        }

        for customPercent in config.customAlertThresholds where used >= config.customThresholdValue(for: customPercent) && !alertedCustomPercentages.contains(customPercent) {
            notificationService.sendNotification(
                type: .customThreshold(customPercent),
                currentUsage: used,
                budget: config.monthlyBudget
            )
            alertedCustomPercentages.insert(customPercent)
            userDefaults.set(Array(alertedCustomPercentages).sorted(), forKey: alertCustomPercentagesKey)
        }
        
        // 80% alert
        if config.alertAt80Percent && used >= threshold80 && !hasAlerted80 {
            notificationService.sendNotification(
                type: .threshold80,
                currentUsage: used,
                budget: config.monthlyBudget
            )
            hasAlerted80 = true
            userDefaults.set(true, forKey: alert80Key)
        }
        
        // Reset soon alert
        if notificationService.shouldNotifyResetSoon() {
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
            
            // Load cached budget and reconstruct spending summary
            if let budgetData = userDefaults.data(forKey: spendingBudgetKey),
               let budgetItem = try? JSONDecoder().decode(BudgetItem.self, from: budgetData) {
                spendingBudget = SpendingBudgetSummary(
                    budgetAmount: Double(budgetItem.budgetAmount),
                    amountSpent: decoded.totalNetCost,
                    preventFurtherUsage: budgetItem.preventFurtherUsage,
                    pricePerRequest: decoded.pricePerRequest
                )
            }
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

import Foundation

/// Configuration for budget and user settings
struct BudgetConfig: Codable {
    var monthlyBudget: Int
    var username: String
    var pollingIntervalMinutes: Int
    var notificationsEnabled: Bool
    var alertAt80Percent: Bool
    var alertAt90Percent: Bool
    var customAlerts: [CustomAlertThreshold]
    var notifyEveryPercent: Bool
    var launchAtLogin: Bool
    var dollarBudget: Double              // Dollar spending cap (0 = disabled)
    var preventFurtherUsage: Bool         // Whether GitHub stops usage at dollar cap
    
    static let `default` = BudgetConfig(
        monthlyBudget: 300,
        username: "",
        pollingIntervalMinutes: 5,
        notificationsEnabled: true,
        alertAt80Percent: false,
        alertAt90Percent: true,
        customAlerts: [],
        notifyEveryPercent: true,
        launchAtLogin: false,
        dollarBudget: 0,
        preventFurtherUsage: true
    )

    enum CodingKeys: String, CodingKey {
        case monthlyBudget
        case username
        case pollingIntervalMinutes
        case notificationsEnabled
        case alertAt80Percent
        case alertAt90Percent
        case customAlerts
        case notifyEveryPercent
        case launchAtLogin
        case customAlertEnabled
        case customAlertPercent
        case dollarBudget
        case preventFurtherUsage
    }

    init(
        monthlyBudget: Int,
        username: String,
        pollingIntervalMinutes: Int,
        notificationsEnabled: Bool,
        alertAt80Percent: Bool,
        alertAt90Percent: Bool,
        customAlerts: [CustomAlertThreshold],
        notifyEveryPercent: Bool,
        launchAtLogin: Bool,
        dollarBudget: Double = 0,
        preventFurtherUsage: Bool = true
    ) {
        self.monthlyBudget = monthlyBudget
        self.username = username
        self.pollingIntervalMinutes = pollingIntervalMinutes
        self.notificationsEnabled = notificationsEnabled
        self.alertAt80Percent = alertAt80Percent
        self.alertAt90Percent = alertAt90Percent
        self.customAlerts = customAlerts
        self.notifyEveryPercent = notifyEveryPercent
        self.launchAtLogin = launchAtLogin
        self.dollarBudget = dollarBudget
        self.preventFurtherUsage = preventFurtherUsage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyBudget = try container.decode(Int.self, forKey: .monthlyBudget)
        username = try container.decode(String.self, forKey: .username)
        pollingIntervalMinutes = try container.decode(Int.self, forKey: .pollingIntervalMinutes)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        alertAt80Percent = try container.decodeIfPresent(Bool.self, forKey: .alertAt80Percent) ?? false
        alertAt90Percent = try container.decodeIfPresent(Bool.self, forKey: .alertAt90Percent) ?? true
        notifyEveryPercent = try container.decodeIfPresent(Bool.self, forKey: .notifyEveryPercent) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        dollarBudget = try container.decodeIfPresent(Double.self, forKey: .dollarBudget) ?? 0
        preventFurtherUsage = try container.decodeIfPresent(Bool.self, forKey: .preventFurtherUsage) ?? true

        if let decodedCustomAlerts = try container.decodeIfPresent([CustomAlertThreshold].self, forKey: .customAlerts) {
            customAlerts = decodedCustomAlerts
        } else {
            let legacyCustomAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .customAlertEnabled) ?? false
            let legacyCustomAlertPercent = try container.decodeIfPresent(Int.self, forKey: .customAlertPercent) ?? 75
            customAlerts = legacyCustomAlertEnabled ? [CustomAlertThreshold(percent: legacyCustomAlertPercent, isEnabled: true)] : []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlyBudget, forKey: .monthlyBudget)
        try container.encode(username, forKey: .username)
        try container.encode(pollingIntervalMinutes, forKey: .pollingIntervalMinutes)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(alertAt80Percent, forKey: .alertAt80Percent)
        try container.encode(alertAt90Percent, forKey: .alertAt90Percent)
        try container.encode(normalizedCustomAlerts, forKey: .customAlerts)
        try container.encode(notifyEveryPercent, forKey: .notifyEveryPercent)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(dollarBudget, forKey: .dollarBudget)
        try container.encode(preventFurtherUsage, forKey: .preventFurtherUsage)
    }
    
    /// Returns the alert threshold value for 80%
    var threshold80: Int {
        Int(Double(monthlyBudget) * 0.8)
    }
    
    /// Returns the alert threshold value for 90%
    var threshold90: Int {
        Int(Double(monthlyBudget) * 0.9)
    }

    var normalizedCustomAlerts: [CustomAlertThreshold] {
        let groupedAlerts = Dictionary(grouping: customAlerts) { clampedCustomAlertPercent($0.percent) }
        return groupedAlerts.keys.sorted().map { percent in
            let alerts = groupedAlerts[percent] ?? []
            return CustomAlertThreshold(percent: percent, isEnabled: alerts.contains { $0.isEnabled })
        }
    }

    var customAlertThresholds: [Int] {
        normalizedCustomAlerts.filter(\.isEnabled).map(\.percent)
    }

    func clampedCustomAlertPercent(_ percent: Int) -> Int {
        min(max(percent, NotificationSettingsConfiguration.customAlertMinPercent), NotificationSettingsConfiguration.customAlertMaxPercent)
    }

    func customThresholdValue(for percent: Int) -> Int {
        Int(Double(monthlyBudget) * (Double(clampedCustomAlertPercent(percent)) / 100.0))
    }
    
    /// Calculate usage percentage
    func usagePercentage(used: Int) -> Double {
        guard monthlyBudget > 0 else { return 0 }
        return (Double(used) / Double(monthlyBudget)) * 100.0
    }

    /// Whole-number usage percentage used for milestone notifications
    func wholePercentUsed(for used: Int) -> Int {
        Int(usagePercentage(used: used).rounded(.down))
    }

    func shouldSkipMilestoneNotification(for percentage: Int) -> Bool {
        customAlertThresholds.contains(percentage)
    }
    
    /// Determine status color based on usage
    func statusColor(used: Int) -> StatusColor {
        let percentage = usagePercentage(used: used)
        if percentage >= 90 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else if percentage >= 60 {
            return .yellow
        } else {
            return .green
        }
    }
}

enum StatusColor {
    case green, yellow, orange, red
}

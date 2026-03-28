import Foundation

/// Configuration for budget and user settings
struct BudgetConfig: Codable {
    var monthlyBudget: Int
    var username: String
    var pollingIntervalMinutes: Int
    var notificationsEnabled: Bool
    var alertAt80Percent: Bool
    var alertAt90Percent: Bool
    var launchAtLogin: Bool
    
    static let `default` = BudgetConfig(
        monthlyBudget: 300,
        username: "",
        pollingIntervalMinutes: 5,
        notificationsEnabled: true,
        alertAt80Percent: true,
        alertAt90Percent: true,
        launchAtLogin: false
    )
    
    /// Returns the alert threshold value for 80%
    var threshold80: Int {
        Int(Double(monthlyBudget) * 0.8)
    }
    
    /// Returns the alert threshold value for 90%
    var threshold90: Int {
        Int(Double(monthlyBudget) * 0.9)
    }
    
    /// Calculate usage percentage
    func usagePercentage(used: Int) -> Double {
        guard monthlyBudget > 0 else { return 0 }
        return (Double(used) / Double(monthlyBudget)) * 100.0
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

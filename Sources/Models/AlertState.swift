import Foundation

/// Pure-value alert tracking state, extracted from UsageTracker for testability.
/// Tracks which threshold alerts and milestone notifications have been sent
/// to prevent duplicate notifications across polling cycles.
///
/// AIDEV-NOTE: The milestone tracker (`lastAlertedWholePercent`) uses its own
/// reset logic separate from threshold alerts. Threshold alerts (80%, 90%,
/// custom) reset when usage drops below the minimum configured threshold
/// (indicating a new billing month). Milestone tracking resets only when
/// usage percentage drops below the previously recorded level — this prevents
/// the bug where milestones re-fire every poll cycle when usage is below
/// the minimum threshold value.
struct AlertState: Equatable {
    var hasAlerted80: Bool = false
    var hasAlerted90: Bool = false
    var alertedCustomPercentages: Set<Int> = []
    var lastAlertedWholePercent: Int = 0

    /// Notification types that should be sent this cycle
    enum Action: Equatable {
        case milestone(Int)
        case threshold80
        case threshold90
        case customThreshold(Int)
    }

    /// Process a usage update and return which notifications should be sent.
    /// Mutates `self` to record what was sent so subsequent calls deduplicate.
    ///
    /// - Parameters:
    ///   - used: current total requests used
    ///   - config: the budget config (thresholds, flags)
    ///   - shouldSendMilestones: whether milestone notifications are allowed
    ///     (false for manual refresh by default)
    /// - Returns: array of notification actions to perform
    mutating func processUsageUpdate(
        used: Int,
        config: BudgetConfig,
        shouldSendMilestones: Bool
    ) -> [Action] {
        let threshold80 = config.threshold80
        let threshold90 = config.threshold90
        let wholePercentUsed = config.wholePercentUsed(for: used)

        // AIDEV-NOTE: minimumTrackedThreshold includes 80%/90% values even when
        // those alerts are disabled. This is conservative — it resets threshold
        // flags earlier than strictly necessary. Consider filtering to only
        // enabled thresholds in a future PR.
        let minimumTrackedThreshold = (
            [threshold80, threshold90]
            + config.customAlertThresholds.map { config.customThresholdValue(for: $0) }
        ).min() ?? threshold80

        // AIDEV-NOTE: Reset threshold alerts (80%, 90%, custom) when usage drops
        // below the minimum configured threshold, indicating a new billing month.
        // Do NOT reset lastAlertedWholePercent here — it has its own reset logic
        // below to prevent the duplicate milestone notification bug.
        if used < minimumTrackedThreshold {
            hasAlerted80 = false
            hasAlerted90 = false
            alertedCustomPercentages = []
        }

        // AIDEV-NOTE: Milestone (per-percent) tracker resets independently.
        // It resets only when the usage *percentage* drops below the previously
        // recorded level, which naturally happens at billing month boundaries.
        // This is the fix for the bug where milestones re-fired every poll cycle
        // because the old code reset lastAlertedWholePercent to 0 whenever
        // usage was below minimumTrackedThreshold.
        if wholePercentUsed < lastAlertedWholePercent {
            lastAlertedWholePercent = 0
        }

        guard config.notificationsEnabled else {
            // Still track the high-water mark even when notifications are off
            // so we don't spam when notifications are re-enabled
            if wholePercentUsed > lastAlertedWholePercent {
                lastAlertedWholePercent = wholePercentUsed
            }
            return []
        }

        var actions: [Action] = []

        // Per-percent milestone
        if config.notifyEveryPercent &&
            shouldSendMilestones &&
            wholePercentUsed > lastAlertedWholePercent &&
            wholePercentUsed > 0 &&
            !config.shouldSkipMilestoneNotification(for: wholePercentUsed) {
            actions.append(.milestone(wholePercentUsed))
            lastAlertedWholePercent = wholePercentUsed
        } else if wholePercentUsed > lastAlertedWholePercent {
            lastAlertedWholePercent = wholePercentUsed
        }

        // 90% alert
        if config.alertAt90Percent && used >= threshold90 && !hasAlerted90 {
            actions.append(.threshold90)
            hasAlerted90 = true
        }

        // Custom threshold alerts
        for customPercent in config.customAlertThresholds
            where used >= config.customThresholdValue(for: customPercent)
            && !alertedCustomPercentages.contains(customPercent)
        {
            actions.append(.customThreshold(customPercent))
            alertedCustomPercentages.insert(customPercent)
        }

        // 80% alert
        if config.alertAt80Percent && used >= threshold80 && !hasAlerted80 {
            actions.append(.threshold80)
            hasAlerted80 = true
        }

        return actions
    }
}

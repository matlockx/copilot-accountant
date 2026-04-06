import Foundation

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        if actual == expected { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertEqual" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message) — got \(actual), expected \(expected)") }
    }
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertFalse(_ condition: Bool, _ message: String = "") { assertTrue(!condition, message) }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

// AIDEV-NOTE: These tests exercise the pure AlertState logic extracted from
// UsageTracker to verify milestone deduplication and threshold alert behavior.
// The key regression test is test_MilestoneDuplicate_DoesNotReFireBelowThreshold
// which validates the fix for the bug where milestone notifications fired on
// every poll cycle when usage was below the minimum configured alert threshold.

@main
struct AlertStateTests {
    /// Helper: default config with per-percent milestones enabled
    static func makeConfig(
        budget: Int = 300,
        alertAt80: Bool = false,
        alertAt90: Bool = true,
        customAlerts: [CustomAlertThreshold] = [],
        notifyEveryPercent: Bool = true,
        notificationsEnabled: Bool = true
    ) -> BudgetConfig {
        BudgetConfig(
            monthlyBudget: budget,
            username: "test",
            pollingIntervalMinutes: 5,
            notificationsEnabled: notificationsEnabled,
            alertAt80Percent: alertAt80,
            alertAt90Percent: alertAt90,
            customAlerts: customAlerts,
            notifyEveryPercent: notifyEveryPercent,
            launchAtLogin: false
        )
    }

    static func main() {
        let test = TestCase()
        print("=========================================")
        print("AlertState Tests (Milestone Dedup Fix)")
        print("=========================================")

        // -----------------------------------------------------------
        // REGRESSION TEST: The core bug
        // -----------------------------------------------------------
        test.run("test_MilestoneDuplicate_DoesNotReFireBelowThreshold") {
            // Budget=100, 90% threshold=90 requests.
            // Usage at 6 requests = 6%.  This is well below the minimum
            // tracked threshold (90), so the old code would reset
            // lastAlertedWholePercent to 0 on every call.
            let config = makeConfig(budget: 100, alertAt80: false, alertAt90: true)
            var state = AlertState()

            // First poll at 6 requests → should fire milestone for 6%
            let actions1 = state.processUsageUpdate(used: 6, config: config, shouldSendMilestones: true)
            test.assertEqual(actions1, [.milestone(6)], "First poll at 6% fires milestone")
            test.assertEqual(state.lastAlertedWholePercent, 6, "lastAlertedWholePercent set to 6")

            // Second poll at 6 requests → should NOT fire again
            let actions2 = state.processUsageUpdate(used: 6, config: config, shouldSendMilestones: true)
            test.assertTrue(actions2.isEmpty, "Second poll at 6% produces no duplicate milestone")
            test.assertEqual(state.lastAlertedWholePercent, 6, "lastAlertedWholePercent remains 6")

            // Third poll still at 6 requests → should NOT fire again
            let actions3 = state.processUsageUpdate(used: 6, config: config, shouldSendMilestones: true)
            test.assertTrue(actions3.isEmpty, "Third poll at 6% produces no duplicate milestone")
        }

        test.run("test_MilestoneDuplicate_DoesNotReFireOnMinorFluctuation") {
            // Simulate API returning slightly varying request counts that
            // all map to the same whole-percent (e.g. 6%).
            // Budget=1000: 64 requests = 6.4%, 65 = 6.5%, 69 = 6.9%
            let config = makeConfig(budget: 1000)
            var state = AlertState()

            let a1 = state.processUsageUpdate(used: 64, config: config, shouldSendMilestones: true)
            test.assertEqual(a1, [.milestone(6)], "64/1000 = 6.4% → fires milestone(6)")

            let a2 = state.processUsageUpdate(used: 65, config: config, shouldSendMilestones: true)
            test.assertTrue(a2.isEmpty, "65/1000 = 6.5% → no duplicate milestone(6)")

            let a3 = state.processUsageUpdate(used: 69, config: config, shouldSendMilestones: true)
            test.assertTrue(a3.isEmpty, "69/1000 = 6.9% → no duplicate milestone(6)")
        }

        // -----------------------------------------------------------
        // Milestone fires once per whole-percent increment
        // -----------------------------------------------------------
        test.run("test_Milestone_FiresOncePerWholePercent") {
            let config = makeConfig(budget: 100)
            var state = AlertState()

            let a1 = state.processUsageUpdate(used: 5, config: config, shouldSendMilestones: true)
            test.assertEqual(a1, [.milestone(5)], "5% milestone fires")

            let a2 = state.processUsageUpdate(used: 6, config: config, shouldSendMilestones: true)
            test.assertEqual(a2, [.milestone(6)], "6% milestone fires on next percent")

            let a3 = state.processUsageUpdate(used: 7, config: config, shouldSendMilestones: true)
            test.assertEqual(a3, [.milestone(7)], "7% milestone fires on next percent")

            // Repeat 7 → nothing
            let a4 = state.processUsageUpdate(used: 7, config: config, shouldSendMilestones: true)
            test.assertTrue(a4.isEmpty, "Repeated 7% does not fire again")
        }

        // -----------------------------------------------------------
        // New month detection: milestone resets when usage drops
        // -----------------------------------------------------------
        test.run("test_Milestone_ResetsOnNewMonth") {
            let config = makeConfig(budget: 100)
            var state = AlertState()

            // Usage grows to 50%
            _ = state.processUsageUpdate(used: 50, config: config, shouldSendMilestones: true)
            test.assertEqual(state.lastAlertedWholePercent, 50, "Tracked 50%")

            // New month: usage resets to 2%
            let actions = state.processUsageUpdate(used: 2, config: config, shouldSendMilestones: true)
            test.assertEqual(actions, [.milestone(2)], "After usage drop (new month), milestone fires for 2%")
            test.assertEqual(state.lastAlertedWholePercent, 2, "lastAlertedWholePercent reset to 2")
        }

        // -----------------------------------------------------------
        // Threshold alerts (80%, 90%) fire exactly once
        // -----------------------------------------------------------
        test.run("test_ThresholdAlerts_FireOnceAndAreDeduplicated") {
            let config = makeConfig(budget: 100, alertAt80: true, alertAt90: true, notifyEveryPercent: false)
            var state = AlertState()

            // Below thresholds
            let a1 = state.processUsageUpdate(used: 79, config: config, shouldSendMilestones: true)
            test.assertTrue(a1.isEmpty, "79 requests = below 80 threshold")

            // Cross 80%
            let a2 = state.processUsageUpdate(used: 80, config: config, shouldSendMilestones: true)
            test.assertTrue(a2.contains(.threshold80), "80 requests triggers 80% alert")
            test.assertFalse(a2.contains(.threshold90), "80 requests does not trigger 90% alert")

            // 80% should not re-fire
            let a3 = state.processUsageUpdate(used: 85, config: config, shouldSendMilestones: true)
            test.assertFalse(a3.contains(.threshold80), "80% alert does not re-fire at 85")

            // Cross 90%
            let a4 = state.processUsageUpdate(used: 90, config: config, shouldSendMilestones: true)
            test.assertTrue(a4.contains(.threshold90), "90 requests triggers 90% alert")

            // Neither should re-fire
            let a5 = state.processUsageUpdate(used: 95, config: config, shouldSendMilestones: true)
            test.assertFalse(a5.contains(.threshold80), "80% alert stays suppressed")
            test.assertFalse(a5.contains(.threshold90), "90% alert stays suppressed")
        }

        // -----------------------------------------------------------
        // Threshold alerts reset on new month (usage drop)
        // -----------------------------------------------------------
        test.run("test_ThresholdAlerts_ResetOnNewMonth") {
            let config = makeConfig(budget: 100, alertAt80: true, alertAt90: true, notifyEveryPercent: false)
            var state = AlertState()

            // Fire both thresholds
            _ = state.processUsageUpdate(used: 95, config: config, shouldSendMilestones: true)
            test.assertTrue(state.hasAlerted80, "80% alert fired")
            test.assertTrue(state.hasAlerted90, "90% alert fired")

            // New month: usage drops below minimum threshold (80)
            _ = state.processUsageUpdate(used: 10, config: config, shouldSendMilestones: true)
            test.assertFalse(state.hasAlerted80, "80% alert reset for new month")
            test.assertFalse(state.hasAlerted90, "90% alert reset for new month")

            // Alerts can fire again
            let actions = state.processUsageUpdate(used: 90, config: config, shouldSendMilestones: true)
            test.assertTrue(actions.contains(.threshold80), "80% alert fires again in new month")
            test.assertTrue(actions.contains(.threshold90), "90% alert fires again in new month")
        }

        // -----------------------------------------------------------
        // Custom threshold alerts
        // -----------------------------------------------------------
        test.run("test_CustomThreshold_FiresOnceAndResets") {
            let config = makeConfig(
                budget: 100,
                alertAt80: false,
                alertAt90: false,
                customAlerts: [CustomAlertThreshold(percent: 50, isEnabled: true)],
                notifyEveryPercent: false
            )
            var state = AlertState()

            let a1 = state.processUsageUpdate(used: 49, config: config, shouldSendMilestones: true)
            test.assertTrue(a1.isEmpty, "Below custom 50% threshold")

            let a2 = state.processUsageUpdate(used: 50, config: config, shouldSendMilestones: true)
            test.assertEqual(a2, [.customThreshold(50)], "Crosses custom 50% threshold")

            let a3 = state.processUsageUpdate(used: 55, config: config, shouldSendMilestones: true)
            test.assertTrue(a3.isEmpty, "Custom 50% threshold does not re-fire")

            // New month (drops below min threshold which is 50)
            _ = state.processUsageUpdate(used: 5, config: config, shouldSendMilestones: true)
            test.assertTrue(state.alertedCustomPercentages.isEmpty, "Custom percentages reset on new month")
        }

        // -----------------------------------------------------------
        // Milestone suppressed when matching custom threshold
        // -----------------------------------------------------------
        test.run("test_MilestoneDedup_SkipsMatchingCustomThreshold") {
            let config = makeConfig(
                budget: 100,
                alertAt80: false,
                alertAt90: false,
                customAlerts: [CustomAlertThreshold(percent: 50, isEnabled: true)]
            )
            var state = AlertState()

            // Get to 49%
            _ = state.processUsageUpdate(used: 49, config: config, shouldSendMilestones: true)

            // At 50: should fire custom threshold but NOT milestone (dedup)
            let actions = state.processUsageUpdate(used: 50, config: config, shouldSendMilestones: true)
            test.assertTrue(actions.contains(.customThreshold(50)), "Custom threshold fires at 50%")
            test.assertFalse(actions.contains(.milestone(50)), "Milestone suppressed at 50% because custom threshold covers it")
            // lastAlertedWholePercent should still advance even without milestone notification
            test.assertEqual(state.lastAlertedWholePercent, 50, "Percent tracker advances to 50 even without milestone")
        }

        // -----------------------------------------------------------
        // Manual refresh suppresses milestones
        // -----------------------------------------------------------
        test.run("test_ManualRefresh_SuppressesMilestones") {
            let config = makeConfig(budget: 100)
            var state = AlertState()

            let actions = state.processUsageUpdate(used: 5, config: config, shouldSendMilestones: false)
            test.assertTrue(actions.isEmpty, "Manual refresh does not fire milestone")
            // But the percent tracker should still advance
            test.assertEqual(state.lastAlertedWholePercent, 5, "Percent tracker advances even without notification")
        }

        // -----------------------------------------------------------
        // Notifications disabled: no actions, but state still tracks
        // -----------------------------------------------------------
        test.run("test_NotificationsDisabled_NoActionsButTracksPercent") {
            let config = makeConfig(budget: 100, notificationsEnabled: false)
            var state = AlertState()

            let a1 = state.processUsageUpdate(used: 50, config: config, shouldSendMilestones: true)
            test.assertTrue(a1.isEmpty, "No actions when notifications disabled")
            test.assertEqual(state.lastAlertedWholePercent, 50, "Percent tracked even when disabled")

            // Re-enable and bump to 51 — should only fire for 51, not replay 1-50
            let enabledConfig = makeConfig(budget: 100, notificationsEnabled: true)
            let a2 = state.processUsageUpdate(used: 51, config: enabledConfig, shouldSendMilestones: true)
            test.assertEqual(a2, [.milestone(51)], "Only new percent fires after re-enabling")
        }

        // -----------------------------------------------------------
        // Zero usage produces no milestone
        // -----------------------------------------------------------
        test.run("test_ZeroUsage_NoMilestone") {
            let config = makeConfig(budget: 100)
            var state = AlertState()

            let actions = state.processUsageUpdate(used: 0, config: config, shouldSendMilestones: true)
            test.assertTrue(actions.isEmpty, "0% usage does not fire milestone")
            test.assertEqual(state.lastAlertedWholePercent, 0, "Percent stays at 0")
        }

        // -----------------------------------------------------------
        // Edge case: zero budget produces no milestone
        // -----------------------------------------------------------
        test.run("test_ZeroBudget_NoMilestone") {
            // With budget=0, wholePercentUsed is always 0, so no milestone fires.
            // Disable threshold alerts to isolate milestone behavior.
            let config = makeConfig(budget: 0, alertAt80: false, alertAt90: false)
            var state = AlertState()

            let actions = state.processUsageUpdate(used: 100, config: config, shouldSendMilestones: true)
            test.assertTrue(actions.isEmpty, "Zero budget produces no milestone")
        }

        // -----------------------------------------------------------
        // Edge case: usage above 100% continues firing milestones
        // -----------------------------------------------------------
        test.run("test_OverBudget_MilestoneContinuesAbove100") {
            let config = makeConfig(budget: 100)
            var state = AlertState()

            _ = state.processUsageUpdate(used: 99, config: config, shouldSendMilestones: true)
            let actions = state.processUsageUpdate(used: 101, config: config, shouldSendMilestones: true)
            test.assertEqual(actions, [.milestone(101)], "Milestone fires above 100%")
        }

        // -----------------------------------------------------------
        // Edge case: multi-percent jump only fires latest percent
        // -----------------------------------------------------------
        test.run("test_MultiPercentJump_OnlyFiresLatestPercent") {
            let config = makeConfig(budget: 100)
            var state = AlertState()

            _ = state.processUsageUpdate(used: 5, config: config, shouldSendMilestones: true)
            let actions = state.processUsageUpdate(used: 8, config: config, shouldSendMilestones: true)
            test.assertEqual(actions, [.milestone(8)], "Only latest percent fires on multi-percent jump")
        }

        test.printSummary()
    }
}

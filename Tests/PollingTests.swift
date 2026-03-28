import Foundation

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        if actual == expected { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertEqual" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct PollingTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F006: Polling Tests")
        print("=========================================")
        
        test.run("test_Polling_DefaultInterval_Is5Minutes") {
            let config = BudgetConfig.default
            test.assertEqual(config.pollingIntervalMinutes, 5, "Default is 5 minutes")
        }
        
        test.run("test_Polling_IntervalIsConfigurable") {
            var config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 10, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            test.assertEqual(config.pollingIntervalMinutes, 10, "Accepts 10 minutes")
            config.pollingIntervalMinutes = 1
            test.assertEqual(config.pollingIntervalMinutes, 1, "Accepts 1 minute")
        }
        
        test.run("test_Polling_IntervalConvertsToSeconds") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            test.assertEqual(TimeInterval(config.pollingIntervalMinutes * 60), 300.0, "5 min = 300 sec")
        }
        
        test.run("test_Polling_ConfigSerialization_PreservesInterval") {
            let original = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 15, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            let encoded = try! JSONEncoder().encode(original)
            let decoded = try! JSONDecoder().decode(BudgetConfig.self, from: encoded)
            test.assertEqual(decoded.pollingIntervalMinutes, 15, "Interval survives serialization")
        }

        test.run("test_Polling_UsageUpdatedNotificationName_IsStable") {
            test.assertEqual(UsageTracker.usageUpdatedNotification.rawValue, "UsageUpdated", "Notification name matches AppDelegate observer")
        }

        test.run("test_Polling_PostUsageUpdatedNotification_PostsExpectedEvent") {
            var received = false
            let observer = NotificationCenter.default.addObserver(
                forName: UsageTracker.usageUpdatedNotification,
                object: nil,
                queue: nil
            ) { _ in
                received = true
            }

            UsageTracker.postUsageUpdatedNotification()

            test.assertTrue(received, "Posting usage update notification notifies observers synchronously")
            NotificationCenter.default.removeObserver(observer)
        }

        test.run("test_Polling_ManualRefreshReason_DoesNotSendMilestones") {
            test.assertTrue(!FetchReason.manualRefresh.shouldSendMilestoneNotifications, "Manual refresh skips milestone notifications")
            test.assertTrue(FetchReason.polling.shouldSendMilestoneNotifications, "Polling fetches still send milestone notifications")
        }
        
        test.printSummary()
    }
}

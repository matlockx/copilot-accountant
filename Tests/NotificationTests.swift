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
    func assertFalse(_ condition: Bool, _ message: String = "") { assertTrue(!condition, message) }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct NotificationTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F007: Notification Tests")
        print("=========================================")
        
        test.run("test_Notification_DefaultConfig_NotificationsEnabled") {
            let config = BudgetConfig.default
            test.assertTrue(config.notificationsEnabled, "Notifications enabled by default")
            test.assertTrue(config.alertAt80Percent, "80% alert enabled by default")
            test.assertTrue(config.alertAt90Percent, "90% alert enabled by default")
            test.assertFalse(config.customAlertEnabled, "Custom alert disabled by default")
            test.assertEqual(config.customAlertPercent, 75, "Custom alert default percent is 75")
        }
        
        test.run("test_Notification_Threshold80_CalculatesCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertEqual(config.threshold80, 240, "80% of 300 = 240")
        }
        
        test.run("test_Notification_Threshold90_CalculatesCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertEqual(config.threshold90, 270, "90% of 300 = 270")
        }

        test.run("test_Notification_CustomThreshold_CalculatesCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: true, customAlertPercent: 73, launchAtLogin: false)
            test.assertEqual(config.customThreshold, 219, "73% of 300 = 219")
        }

        test.run("test_Notification_CanBeDisabled") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: false, alertAt80Percent: false, alertAt90Percent: false, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertFalse(config.notificationsEnabled, "Notifications can be disabled")
            test.assertFalse(config.alertAt80Percent, "80% can be disabled")
            test.assertFalse(config.alertAt90Percent, "90% can be disabled")
            test.assertFalse(config.customAlertEnabled, "Custom alert can be disabled")
        }

        test.run("test_Notification_Serialization_PreservesSettings") {
            let original = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlertEnabled: true, customAlertPercent: 77, launchAtLogin: false)
            let encoded = try! JSONEncoder().encode(original)
            let decoded = try! JSONDecoder().decode(BudgetConfig.self, from: encoded)
            test.assertEqual(decoded.notificationsEnabled, true, "notificationsEnabled preserved")
            test.assertEqual(decoded.alertAt80Percent, false, "alertAt80Percent preserved")
            test.assertEqual(decoded.alertAt90Percent, true, "alertAt90Percent preserved")
            test.assertEqual(decoded.customAlertEnabled, true, "customAlertEnabled preserved")
            test.assertEqual(decoded.customAlertPercent, 77, "customAlertPercent preserved")
        }

        test.run("test_Notification_TestButton_UsesExpectedLabel") {
            test.assertEqual(NotificationSettingsConfiguration.testButtonTitle, "Test Notification", "Settings exposes a test notification button")
        }

        test.run("test_Notification_TestButton_UsesForegroundPresentation") {
            test.assertTrue(NotificationSettingsConfiguration.testNotificationDelaySeconds > 0, "Test notification uses a short delay for reliable delivery")
            test.assertEqual(NotificationSettingsConfiguration.foregroundPresentationOptionCount, 4, "Foreground notifications request all expected presentation options")
        }
        
        test.printSummary()
    }
}

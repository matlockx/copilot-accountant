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
            test.assertFalse(config.alertAt80Percent, "80% alert disabled by default")
            test.assertTrue(config.alertAt90Percent, "90% alert enabled by default")
            test.assertTrue(config.notifyEveryPercent, "Per-percent notifications enabled by default")
            test.assertTrue(config.customAlerts.isEmpty, "No custom alerts by default")
        }
        
        test.run("test_Notification_Threshold80_CalculatesCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: true, launchAtLogin: false)
            test.assertEqual(config.threshold80, 240, "80% of 300 = 240")
        }
        
        test.run("test_Notification_Threshold90_CalculatesCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: true, launchAtLogin: false)
            test.assertEqual(config.threshold90, 270, "90% of 300 = 270")
        }

        test.run("test_Notification_CustomThreshold_CalculatesCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlerts: [CustomAlertThreshold(percent: 73, isEnabled: true)], notifyEveryPercent: true, launchAtLogin: false)
            test.assertEqual(config.customAlertThresholds, [73], "Custom alert list is normalized")
            test.assertEqual(config.customThresholdValue(for: 73), 219, "73% of 300 = 219")
        }

        test.run("test_Notification_CustomThresholds_AreClampedSortedAndUnique") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlerts: [CustomAlertThreshold(percent: 150, isEnabled: true), CustomAlertThreshold(percent: 73, isEnabled: true), CustomAlertThreshold(percent: 73, isEnabled: true), CustomAlertThreshold(percent: -5, isEnabled: true)], notifyEveryPercent: true, launchAtLogin: false)
            test.assertEqual(config.customAlertThresholds, [1, 73, 100], "Custom thresholds clamp, sort, and deduplicate")
        }

        test.run("test_Notification_DisabledCustomAlert_IsIgnored") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlerts: [CustomAlertThreshold(percent: 55, isEnabled: false), CustomAlertThreshold(percent: 70, isEnabled: true)], notifyEveryPercent: true, launchAtLogin: false)
            test.assertEqual(config.customAlertThresholds, [70], "Only enabled custom alerts participate")
        }

        test.run("test_Notification_CanBeDisabled") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: false, alertAt80Percent: false, alertAt90Percent: false, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            test.assertFalse(config.notificationsEnabled, "Notifications can be disabled")
            test.assertFalse(config.alertAt80Percent, "80% can be disabled")
            test.assertFalse(config.alertAt90Percent, "90% can be disabled")
            test.assertFalse(config.notifyEveryPercent, "Per-percent notifications can be disabled")
        }

        test.run("test_Notification_Serialization_PreservesSettings") {
            let original = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlerts: [CustomAlertThreshold(percent: 44, isEnabled: false), CustomAlertThreshold(percent: 77, isEnabled: true)], notifyEveryPercent: true, launchAtLogin: false)
            let encoded = try! JSONEncoder().encode(original)
            let decoded = try! JSONDecoder().decode(BudgetConfig.self, from: encoded)
            test.assertEqual(decoded.notificationsEnabled, true, "notificationsEnabled preserved")
            test.assertEqual(decoded.alertAt80Percent, false, "alertAt80Percent preserved")
            test.assertEqual(decoded.alertAt90Percent, true, "alertAt90Percent preserved")
            test.assertEqual(decoded.customAlerts.count, 2, "customAlerts preserved")
            test.assertFalse(decoded.customAlerts[0].isEnabled, "disabled custom alert preserved")
            test.assertTrue(decoded.customAlerts[1].isEnabled, "enabled custom alert preserved")
            test.assertEqual(decoded.notifyEveryPercent, true, "notifyEveryPercent preserved")
        }

        test.run("test_Notification_LegacyCustomAlert_MigratesIntoArray") {
            let legacyJSON = "{\"monthlyBudget\":300,\"username\":\"test\",\"pollingIntervalMinutes\":5,\"notificationsEnabled\":true,\"alertAt80Percent\":true,\"alertAt90Percent\":true,\"customAlertEnabled\":true,\"customAlertPercent\":66,\"launchAtLogin\":false}".data(using: .utf8)!
            let decoded = try! JSONDecoder().decode(BudgetConfig.self, from: legacyJSON)
            test.assertEqual(decoded.customAlertThresholds, [66], "Legacy custom alert migrates into custom alert array")
            test.assertTrue(decoded.customAlerts.first?.isEnabled == true, "Migrated custom alert defaults to enabled")
            test.assertTrue(decoded.notifyEveryPercent, "New per-percent notification default applies during migration")
        }

        test.run("test_Notification_EveryPercent_UsesFlooredWholePercentage") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: true, launchAtLogin: false)
            test.assertEqual(config.wholePercentUsed(for: 128), 42, "128 of 300 floors to 42%")
            test.assertEqual(config.wholePercentUsed(for: 300), 100, "Full budget reports 100%")
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

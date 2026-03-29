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
struct SettingsTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F008: Settings Persistence Tests")
        print("=========================================")
        
        test.run("test_Settings_DefaultValues") {
            let config = BudgetConfig.default
            test.assertEqual(config.monthlyBudget, 300, "Default budget is 300")
            test.assertEqual(config.username, "", "Default username is empty")
            test.assertEqual(config.pollingIntervalMinutes, 5, "Default polling is 5")
            test.assertTrue(config.notificationsEnabled, "Notifications enabled")
            test.assertFalse(config.alertAt80Percent, "80% alert disabled by default")
            test.assertTrue(config.notifyEveryPercent, "Every-percent notifications enabled by default")
            test.assertEqual(config.customAlerts.count, 0, "No custom alerts by default")
            test.assertFalse(config.launchAtLogin, "Launch at login disabled")
        }
        
        test.run("test_Settings_ConfigIsCodable") {
            let config = BudgetConfig(monthlyBudget: 500, username: "testuser", pollingIntervalMinutes: 10, notificationsEnabled: false, alertAt80Percent: true, alertAt90Percent: false, customAlerts: [CustomAlertThreshold(percent: 68, isEnabled: false), CustomAlertThreshold(percent: 72, isEnabled: true)], notifyEveryPercent: true, launchAtLogin: true)
            do {
                let encoded = try JSONEncoder().encode(config)
                let decoded = try JSONDecoder().decode(BudgetConfig.self, from: encoded)
                test.assertEqual(decoded.monthlyBudget, 500, "monthlyBudget preserved")
                test.assertEqual(decoded.username, "testuser", "username preserved")
                test.assertEqual(decoded.pollingIntervalMinutes, 10, "pollingInterval preserved")
                test.assertEqual(decoded.notificationsEnabled, false, "notificationsEnabled preserved")
                test.assertFalse(decoded.customAlerts[0].isEnabled, "disabled custom alert preserved")
                test.assertTrue(decoded.customAlerts[1].isEnabled, "enabled custom alert preserved")
                test.assertEqual(decoded.notifyEveryPercent, true, "notifyEveryPercent preserved")
                test.assertEqual(decoded.launchAtLogin, true, "launchAtLogin preserved")
            } catch { test.assertTrue(false, "Should not throw: \(error)") }
        }
        
        test.run("test_Settings_ConfigFieldsAreMutable") {
            var config = BudgetConfig.default
            config.monthlyBudget = 1000
            test.assertEqual(config.monthlyBudget, 1000, "Budget mutable")
            config.username = "newuser"
            test.assertEqual(config.username, "newuser", "Username mutable")
        }
        
        test.run("test_Settings_UserDefaultsStorage") {
            let testKey = "testBudgetConfig_\(UUID().uuidString)"
            let userDefaults = UserDefaults.standard
            let config = BudgetConfig(monthlyBudget: 750, username: "persisteduser", pollingIntervalMinutes: 30, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlerts: [CustomAlertThreshold(percent: 82, isEnabled: false), CustomAlertThreshold(percent: 91, isEnabled: true)], notifyEveryPercent: true, launchAtLogin: false)
            if let encoded = try? JSONEncoder().encode(config) {
                userDefaults.set(encoded, forKey: testKey)
                if let data = userDefaults.data(forKey: testKey),
                   let decoded = try? JSONDecoder().decode(BudgetConfig.self, from: data) {
                    test.assertEqual(decoded.monthlyBudget, 750, "Budget persisted")
                    test.assertEqual(decoded.username, "persisteduser", "Username persisted")
                    test.assertFalse(decoded.customAlerts[0].isEnabled, "Disabled custom alert persisted")
                    test.assertTrue(decoded.customAlerts[1].isEnabled, "Enabled custom alert persisted")
                    test.assertEqual(decoded.notifyEveryPercent, true, "Per-percent preference persisted")
                } else { test.assertTrue(false, "Should decode") }
            } else { test.assertTrue(false, "Should encode") }
            userDefaults.removeObject(forKey: testKey)
        }

        test.run("test_Settings_NotificationSection_IncludesCustomAlertControl") {
            test.assertEqual(NotificationSettingsConfiguration.customAlertFieldTitle, "Custom alerts", "Settings exposes custom alerts label")
            test.assertEqual(NotificationSettingsConfiguration.customAlertSuffix, "%", "Custom threshold uses percent suffix")
            test.assertEqual(NotificationSettingsConfiguration.customAlertFieldWidth, 56, "Custom threshold field has a compact fixed width")
            test.assertEqual(NotificationSettingsConfiguration.customAlertRowSpacing, 8, "Custom threshold row uses consistent spacing")
            test.assertEqual(NotificationSettingsConfiguration.addCustomAlertButtonTitle, "Add alert", "Settings exposes add custom alert button")
            test.assertEqual(NotificationSettingsConfiguration.removeCustomAlertButtonTitle, "Remove", "Settings exposes remove custom alert button")
            test.assertEqual(NotificationSettingsConfiguration.customAlertToggleTitle, "Enabled", "Settings exposes per-alert enabled checkbox label")
            test.assertEqual(NotificationSettingsConfiguration.everyPercentToggleTitle, "Notify on every full percent", "Settings exposes per-percent notification toggle")
            test.assertEqual(SettingsViewConfiguration.formLabelWidth, 160, "Settings uses a stable label column width")
            test.assertEqual(SettingsViewConfiguration.formFieldSpacing, 10, "Settings rows use consistent field spacing")
            test.assertEqual(SettingsViewConfiguration.utilityButtonWidth, 100, "Settings utility buttons share a common width")
            test.assertEqual(SettingsAlertConfiguration.successTitle, "Validation Succeeded", "Success alert uses a success title")
            test.assertEqual(SettingsAlertConfiguration.failureTitle, "Validation Failed", "Failure alert keeps failure title")
        }

        test.run("test_Settings_Layout_UsesPinnedFooterForActions") {
            test.assertEqual(SettingsViewConfiguration.actionBarPlacement, .pinnedFooter, "Cancel and Save stay visible in a fixed footer")
            test.assertTrue(SettingsViewConfiguration.footerHeight > 0, "Pinned footer has a positive height")
        }

        test.run("test_Settings_Layout_UsesExpectedFooterButtons") {
            test.assertEqual(SettingsViewConfiguration.footerButtonTitles, ["Cancel", "Save"], "Footer uses Cancel and Save buttons")
            test.assertEqual(SettingsViewConfiguration.windowSize.width, 560, "Settings window width accommodates two-column grid")
            test.assertEqual(SettingsViewConfiguration.windowSize.height, 640, "Settings window height stays consistent")
        }

        test.run("test_Settings_EscapeKey_ClosesOpenWindows") {
            test.assertTrue(SettingsViewConfiguration.escapeKeyClosesWindow, "Settings window closes with Escape")
            test.assertTrue(DetailedStatsWindowConfiguration.escapeKeyClosesWindow, "Detailed stats window closes with Escape")
        }

        test.run("test_Settings_Footer_ShowsAuthorCredit") {
            test.assertEqual(SettingsViewConfiguration.authorHandle, "matlockx", "Footer credits the correct GitHub handle")
            test.assertEqual(SettingsViewConfiguration.authorURL, "https://github.com/matlockx/copilot-accountant", "Footer links to the project repository")
            test.assertTrue(URL(string: SettingsViewConfiguration.authorURL) != nil, "Author URL is a valid URL")
        }
        
        test.printSummary()
    }
}

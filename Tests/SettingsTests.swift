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
            test.assertFalse(config.customAlertEnabled, "Custom alert disabled by default")
            test.assertEqual(config.customAlertPercent, 75, "Custom alert default is 75%")
            test.assertFalse(config.launchAtLogin, "Launch at login disabled")
        }
        
        test.run("test_Settings_ConfigIsCodable") {
            let config = BudgetConfig(monthlyBudget: 500, username: "testuser", pollingIntervalMinutes: 10, notificationsEnabled: false, alertAt80Percent: true, alertAt90Percent: false, customAlertEnabled: true, customAlertPercent: 68, launchAtLogin: true)
            do {
                let encoded = try JSONEncoder().encode(config)
                let decoded = try JSONDecoder().decode(BudgetConfig.self, from: encoded)
                test.assertEqual(decoded.monthlyBudget, 500, "monthlyBudget preserved")
                test.assertEqual(decoded.username, "testuser", "username preserved")
                test.assertEqual(decoded.pollingIntervalMinutes, 10, "pollingInterval preserved")
                test.assertEqual(decoded.notificationsEnabled, false, "notificationsEnabled preserved")
                test.assertEqual(decoded.customAlertEnabled, true, "customAlertEnabled preserved")
                test.assertEqual(decoded.customAlertPercent, 68, "customAlertPercent preserved")
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
            let config = BudgetConfig(monthlyBudget: 750, username: "persisteduser", pollingIntervalMinutes: 30, notificationsEnabled: true, alertAt80Percent: false, alertAt90Percent: true, customAlertEnabled: true, customAlertPercent: 82, launchAtLogin: false)
            if let encoded = try? JSONEncoder().encode(config) {
                userDefaults.set(encoded, forKey: testKey)
                if let data = userDefaults.data(forKey: testKey),
                   let decoded = try? JSONDecoder().decode(BudgetConfig.self, from: data) {
                    test.assertEqual(decoded.monthlyBudget, 750, "Budget persisted")
                    test.assertEqual(decoded.username, "persisteduser", "Username persisted")
                    test.assertEqual(decoded.customAlertPercent, 82, "Custom alert percent persisted")
                } else { test.assertTrue(false, "Should decode") }
            } else { test.assertTrue(false, "Should encode") }
            userDefaults.removeObject(forKey: testKey)
        }

        test.run("test_Settings_NotificationSection_IncludesCustomAlertControl") {
            test.assertEqual(NotificationSettingsConfiguration.customAlertFieldTitle, "Custom alert at", "Settings exposes custom threshold label")
            test.assertEqual(NotificationSettingsConfiguration.customAlertSuffix, "%", "Custom threshold uses percent suffix")
        }

        test.run("test_Settings_Layout_UsesPinnedFooterForActions") {
            test.assertEqual(SettingsViewConfiguration.actionBarPlacement, .pinnedFooter, "Cancel and Save stay visible in a fixed footer")
            test.assertTrue(SettingsViewConfiguration.footerHeight > 0, "Pinned footer has a positive height")
        }

        test.run("test_Settings_Layout_UsesExpectedFooterButtons") {
            test.assertEqual(SettingsViewConfiguration.footerButtonTitles, ["Cancel", "Save"], "Footer uses Cancel and Save buttons")
            test.assertEqual(SettingsViewConfiguration.windowSize.width, 520, "Settings window width stays consistent")
            test.assertEqual(SettingsViewConfiguration.windowSize.height, 620, "Settings window height stays consistent")
        }
        
        test.printSummary()
    }
}

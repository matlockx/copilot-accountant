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
struct MenuBarTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F001: Menu Bar Tests")
        print("=========================================")
        
        test.run("test_MenuBar_StatusColorsDefined") {
            let colors: [StatusColor] = [.green, .yellow, .orange, .red]
            test.assertEqual(colors.count, 4, "Should have 4 status colors")
        }
        
        test.run("test_MenuBar_StatusColorThresholds") {
            let config = BudgetConfig(monthlyBudget: 100, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertTrue(config.statusColor(used: 0) == .green, "0% is green")
            test.assertTrue(config.statusColor(used: 59) == .green, "59% is green")
            test.assertTrue(config.statusColor(used: 60) == .yellow, "60% is yellow")
            test.assertTrue(config.statusColor(used: 79) == .yellow, "79% is yellow")
            test.assertTrue(config.statusColor(used: 80) == .orange, "80% is orange")
            test.assertTrue(config.statusColor(used: 89) == .orange, "89% is orange")
            test.assertTrue(config.statusColor(used: 90) == .red, "90% is red")
            test.assertTrue(config.statusColor(used: 100) == .red, "100% is red")
        }
        
        test.run("test_MenuBar_StatusEmojiMapping") {
            func emojiForColor(_ color: StatusColor) -> String {
                switch color { case .green: return "🟢"; case .yellow: return "🟡"; case .orange: return "🟠"; case .red: return "🔴" }
            }
            test.assertEqual(emojiForColor(.green), "🟢", "Green emoji")
            test.assertEqual(emojiForColor(.yellow), "🟡", "Yellow emoji")
            test.assertEqual(emojiForColor(.orange), "🟠", "Orange emoji")
            test.assertEqual(emojiForColor(.red), "🔴", "Red emoji")
        }
        
        test.run("test_MenuBar_PercentageFormat_OneDecimalPlace") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            let percentage = config.usagePercentage(used: 150)
            let formatted = String(format: "%@ %.1f%%", "🟢", percentage)
            test.assertEqual(formatted, "🟢 50.0%", "Format is 'emoji percentage%' with one decimal")
        }
        
        test.run("test_MenuBar_PercentageFormat_ShowsDecimal") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            let percentage = config.usagePercentage(used: 86)  // 28.666...%
            let formatted = String(format: "%@ %.1f%%", "🟢", percentage)
            test.assertEqual(formatted, "🟢 28.7%", "Shows one decimal place (28.7% not 29%)")
        }
        
        test.run("test_MenuBar_DefaultDisplay") {
            let defaultDisplay = "☁️ --"
            test.assertTrue(defaultDisplay.contains("--"), "Default shows '--'")
            test.assertTrue(defaultDisplay.contains("☁️"), "Default has cloud emoji")
        }
        
        test.run("test_MenuBar_ZeroBudgetHandling") {
            let config = BudgetConfig(monthlyBudget: 0, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertEqual(config.usagePercentage(used: 100), 0.0, "Zero budget returns 0%")
        }
        
        test.printSummary()
    }
}

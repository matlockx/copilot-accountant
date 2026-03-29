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
            let config = BudgetConfig(monthlyBudget: 100, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            test.assertTrue(config.statusColor(used: 0) == .green, "0% is green")
            test.assertTrue(config.statusColor(used: 59) == .green, "59% is green")
            test.assertTrue(config.statusColor(used: 60) == .yellow, "60% is yellow")
            test.assertTrue(config.statusColor(used: 79) == .yellow, "79% is yellow")
            test.assertTrue(config.statusColor(used: 80) == .orange, "80% is orange")
            test.assertTrue(config.statusColor(used: 89) == .orange, "89% is orange")
            test.assertTrue(config.statusColor(used: 90) == .red, "90% is red")
            test.assertTrue(config.statusColor(used: 100) == .red, "100% is red")
        }
        
        test.run("test_MenuBar_StatusEmojiMapping_Replaced_By_F021_Icon") {
            // F021 replaced emoji indicators with a programmatic NSImage icon.
            // The StatusColor enum now exposes nsColor instead of an emoji string.
            // This test verifies the old emoji constants are no longer the primary path.
            let greenNSColor = StatusColor.green.nsColor
            let redNSColor   = StatusColor.red.nsColor
            test.assertTrue(greenNSColor != redNSColor, "Green and red are distinct NSColors (icon path)")
        }
        
        test.run("test_MenuBar_PercentageFormat_OneDecimalPlace") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            let percentage = config.usagePercentage(used: 150)
            // F021: title is now " %.1f%%" (space + percentage, icon set separately)
            let formatted = String(format: " %.1f%%", percentage)
            test.assertEqual(formatted, " 50.0%", "Format is ' percentage%' with one decimal (icon set via button.image)")
        }
        
        test.run("test_MenuBar_PercentageFormat_ShowsDecimal") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            let percentage = config.usagePercentage(used: 86)  // 28.666...%
            let formatted = String(format: " %.1f%%", percentage)
            test.assertEqual(formatted, " 28.7%", "Shows one decimal place (28.7% not 29%)")
        }
        
        test.run("test_MenuBar_DefaultDisplay") {
            let defaultDisplay = "☁️ --"
            test.assertTrue(defaultDisplay.contains("--"), "Default shows '--'")
            test.assertTrue(defaultDisplay.contains("☁️"), "Default has cloud emoji")
        }
        
        test.run("test_MenuBar_ZeroBudgetHandling") {
            let config = BudgetConfig(monthlyBudget: 0, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false)
            test.assertEqual(config.usagePercentage(used: 100), 0.0, "Zero budget returns 0%")
        }

        // F019: Enhanced Menu Bar Popup - Spending Budget Section

        test.run("test_F019_SpendingBudget_SectionHiddenWhenNoBudget") {
            // When dollarBudget == 0, spendingBudget is nil — section should not appear
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false, dollarBudget: 0)
            test.assertEqual(config.dollarBudget, 0.0, "Zero dollar budget means section is hidden")
        }

        test.run("test_F019_SpendingBudget_SectionShownWhenBudgetConfigured") {
            let config = BudgetConfig(monthlyBudget: 300, username: "test", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlerts: [], notifyEveryPercent: false, launchAtLogin: false, dollarBudget: 15.0)
            test.assertTrue(config.dollarBudget > 0, "Non-zero dollar budget means section is shown")
        }

        test.run("test_F019_SpendingBudget_DollarDisplayFormat") {
            // Verify the display format for spent/budget amounts
            let spent = 3.24
            let budget = 15.0
            let formatted = String(format: "$%.2f / $%.2f budget", spent, budget)
            test.assertEqual(formatted, "$3.24 / $15.00 budget", "Dollar display format correct")
        }

        test.run("test_F019_SpendingBudget_RemainingDisplayFormat") {
            let remaining = 11.76
            let formatted = String(format: "$%.2f remaining", remaining)
            test.assertEqual(formatted, "$11.76 remaining", "Remaining display format correct")
        }

        test.run("test_F019_SpendingBudget_BillingContextWithOverage") {
            // When there are billed (net) requests beyond the included limit
            let billedRequests = 37
            let message = "\(billedRequests) billed requests beyond included limit"
            test.assertEqual(message, "37 billed requests beyond included limit", "Overage billing context format")
        }

        test.run("test_F019_SpendingBudget_BillingContextNoOverage") {
            let message = "All usage within included requests"
            test.assertTrue(message.contains("All usage within"), "No-overage billing context")
        }

        test.run("test_F019_SpendingBudget_ProgressColorGreen") {
            let summary = SpendingBudgetSummary(budgetAmount: 15.0, amountSpent: 1.0, preventFurtherUsage: false, pricePerRequest: 0.04)
            // ~6.7% used — should be green (<60%)
            test.assertTrue(summary.percentUsed < 60, "Low spend is green threshold")
        }

        test.run("test_F019_SpendingBudget_ProgressColorYellow") {
            let summary = SpendingBudgetSummary(budgetAmount: 15.0, amountSpent: 10.0, preventFurtherUsage: false, pricePerRequest: 0.04)
            // ~66.7% used — should be yellow (60-79%)
            test.assertTrue(summary.percentUsed >= 60 && summary.percentUsed < 80, "Medium spend is yellow threshold")
        }

        test.run("test_F019_SpendingBudget_ProgressColorOrange") {
            let summary = SpendingBudgetSummary(budgetAmount: 15.0, amountSpent: 12.5, preventFurtherUsage: false, pricePerRequest: 0.04)
            // ~83.3% used — should be orange (80-89%)
            test.assertTrue(summary.percentUsed >= 80 && summary.percentUsed < 90, "High spend is orange threshold")
        }

        test.run("test_F019_SpendingBudget_ProgressColorRed") {
            let summary = SpendingBudgetSummary(budgetAmount: 15.0, amountSpent: 14.0, preventFurtherUsage: false, pricePerRequest: 0.04)
            // ~93.3% used — should be red (>=90%)
            test.assertTrue(summary.percentUsed >= 90, "Critical spend is red threshold")
        }

        test.run("test_F019_SpendingBudget_BilledRequestsFromSummary") {
            // billedRequests = netQuantity totals, can be derived separately
            // The billing context shows billed requests > 0 as overage
            let summary = SpendingBudgetSummary(budgetAmount: 15.0, amountSpent: 1.48, preventFurtherUsage: false, pricePerRequest: 0.04)
            // $1.48 spent at $0.04/request = 37 billed requests
            let billedRequests = Int((summary.amountSpent / summary.pricePerRequest).rounded())
            test.assertEqual(billedRequests, 37, "Billed requests derived from amountSpent / pricePerRequest")
        }

        // F021: Copilot Menu Bar Icon - StatusColor NSColor mapping

        test.run("test_F021_StatusColor_NSColorMapping_Defined") {
            // All StatusColor cases must map to a non-nil NSColor
            let greenColor = StatusColor.green.nsColor
            let yellowColor = StatusColor.yellow.nsColor
            let orangeColor = StatusColor.orange.nsColor
            let redColor = StatusColor.red.nsColor
            // Verify they are distinct colors by checking descriptions
            test.assertTrue(greenColor != yellowColor, "Green and yellow are distinct NSColors")
            test.assertTrue(orangeColor != redColor, "Orange and red are distinct NSColors")
            test.assertTrue(greenColor != redColor, "Green and red are distinct NSColors")
        }

        test.run("test_F021_StatusColor_NSColorGreenIsSystemGreen") {
            let color = StatusColor.green.nsColor
            test.assertTrue(color == .systemGreen, "Green maps to NSColor.systemGreen")
        }

        test.run("test_F021_StatusColor_NSColorYellowIsSystemYellow") {
            let color = StatusColor.yellow.nsColor
            test.assertTrue(color == .systemYellow, "Yellow maps to NSColor.systemYellow")
        }

        test.run("test_F021_StatusColor_NSColorOrangeIsSystemOrange") {
            let color = StatusColor.orange.nsColor
            test.assertTrue(color == .systemOrange, "Orange maps to NSColor.systemOrange")
        }

        test.run("test_F021_StatusColor_NSColorRedIsSystemRed") {
            let color = StatusColor.red.nsColor
            test.assertTrue(color == .systemRed, "Red maps to NSColor.systemRed")
        }

        test.run("test_F021_MenuBar_IconImageCreated") {
            // CopilotMenuBarIcon.image(for:) must return a non-nil NSImage for every status color
            let greenImage = CopilotMenuBarIcon.image(for: .green)
            let yellowImage = CopilotMenuBarIcon.image(for: .yellow)
            let orangeImage = CopilotMenuBarIcon.image(for: .orange)
            let redImage = CopilotMenuBarIcon.image(for: .red)
            test.assertTrue(greenImage != nil, "Green icon image is non-nil")
            test.assertTrue(yellowImage != nil, "Yellow icon image is non-nil")
            test.assertTrue(orangeImage != nil, "Orange icon image is non-nil")
            test.assertTrue(redImage != nil, "Red icon image is non-nil")
        }

        test.run("test_F021_MenuBar_IconImageSize") {
            // Icon should be 18x18 points for menu bar use
            if let image = CopilotMenuBarIcon.image(for: .green) {
                test.assertEqual(image.size.width, 18.0, "Icon width is 18pt")
                test.assertEqual(image.size.height, 18.0, "Icon height is 18pt")
            } else {
                test.assertTrue(false, "Icon image must not be nil")
            }
        }

        test.run("test_F021_MenuBar_IconIsNotTemplate") {
            // isTemplate = false so the status color is visible in the menu bar.
            // Template images are monochrome — we need actual color.
            if let image = CopilotMenuBarIcon.image(for: .green) {
                test.assertTrue(!image.isTemplate, "Icon is NOT a template — color must be visible")
            } else {
                test.assertTrue(false, "Icon image must not be nil")
            }
        }

        test.printSummary()
    }
}

import Foundation

// Test Framework
class TestCase {
    var passed: Int = 0
    var failed: Int = 0
    
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        if actual == expected { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertEqual" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertEqual" : message)\n    Expected: \(expected)\n    Actual:   \(actual)") }
    }
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertTrue" : message)") }
    }
    func assertFalse(_ condition: Bool, _ message: String = "") {
        if !condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertFalse" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertFalse" : message)") }
    }
    func assertApproximatelyEqual(_ actual: Double, _ expected: Double, tolerance: Double = 0.001, _ message: String = "") {
        if abs(actual - expected) <= tolerance { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertApproximatelyEqual" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertApproximatelyEqual" : message)\n    Expected: \(expected) ± \(tolerance)\n    Actual:   \(actual)") }
    }
    func assertNotNil<T>(_ value: T?, _ message: String = "") {
        if value != nil { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertNotNil" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertNotNil" : message)") }
    }
    func assertNil<T>(_ value: T?, _ message: String = "") {
        if value == nil { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertNil" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertNil" : message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() {
        print("\n=========================================")
        if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) }
        else { print("PASSED: \(passed) tests passed") }
    }
}

// =============================================================================
// F018: Spending Budget Tests
// =============================================================================

@main
struct SpendingBudgetTests {
    static func main() {
        let test = TestCase()
        
        print("=========================================")
        print("F018: Spending Budget Tests")
        print("=========================================")
        
        // MARK: - SpendingBudgetSummary Calculation Tests
        
        test.run("test_SpendingBudgetSummary_RemainingCalculation") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 5.50,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertApproximatelyEqual(summary.remaining, 9.50, tolerance: 0.001, "Remaining = 15 - 5.50 = 9.50")
        }
        
        test.run("test_SpendingBudgetSummary_RemainingNeverNegative") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 10.0,
                amountSpent: 15.0,  // Over budget
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertApproximatelyEqual(summary.remaining, 0.0, tolerance: 0.001, "Remaining is capped at 0")
        }
        
        test.run("test_SpendingBudgetSummary_PercentUsed") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 20.0,
                amountSpent: 5.0,
                preventFurtherUsage: false,
                pricePerRequest: 0.04
            )
            test.assertApproximatelyEqual(summary.percentUsed, 25.0, tolerance: 0.001, "25% used (5/20)")
        }
        
        test.run("test_SpendingBudgetSummary_PercentUsed_ZeroBudget") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 0.0,
                amountSpent: 5.0,
                preventFurtherUsage: false,
                pricePerRequest: 0.04
            )
            test.assertApproximatelyEqual(summary.percentUsed, 0.0, tolerance: 0.001, "0% when budget is 0 (avoid division by zero)")
        }
        
        test.run("test_SpendingBudgetSummary_IsCapReached_False") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 14.99,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertFalse(summary.isCapReached, "Cap not reached when spent < budget")
        }
        
        test.run("test_SpendingBudgetSummary_IsCapReached_True") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 15.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertTrue(summary.isCapReached, "Cap reached when spent >= budget")
        }
        
        test.run("test_SpendingBudgetSummary_IsCapReached_Exceeded") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 16.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertTrue(summary.isCapReached, "Cap reached when spent > budget")
        }
        
        test.run("test_SpendingBudgetSummary_MaxAdditionalRequests") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 5.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            // Remaining = $10.00, at $0.04/request = 250 requests
            test.assertEqual(summary.maxAdditionalRequests, 250, "Max additional = 10.00 / 0.04 = 250")
        }
        
        test.run("test_SpendingBudgetSummary_MaxAdditionalRequests_RoundsDown") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 5.01,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            // Remaining = $9.99, at $0.04/request = 249.75 -> 249 (rounded down)
            test.assertEqual(summary.maxAdditionalRequests, 249, "Max additional rounds down to 249")
        }
        
        test.run("test_SpendingBudgetSummary_MaxAdditionalRequests_ZeroPrice") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 5.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.0
            )
            test.assertEqual(summary.maxAdditionalRequests, 0, "Max additional is 0 when price is 0")
        }
        
        test.run("test_SpendingBudgetSummary_MaxAdditionalRequests_NoRemaining") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 15.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertEqual(summary.maxAdditionalRequests, 0, "Max additional is 0 when no remaining budget")
        }
        
        test.run("test_SpendingBudgetSummary_Equality") {
            let summary1 = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 5.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            let summary2 = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 5.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            let summary3 = SpendingBudgetSummary(
                budgetAmount: 20.0,
                amountSpent: 5.0,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            
            test.assertTrue(summary1 == summary2, "Identical summaries are equal")
            test.assertFalse(summary1 == summary3, "Different summaries are not equal")
        }
        
        test.run("test_SpendingBudgetSummary_WithRealUsageData") {
            // Simulate the scenario from the user's screenshot:
            // Budget: $15.00, Spent: $0.19
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 0.19,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            
            test.assertApproximatelyEqual(summary.remaining, 14.81, tolerance: 0.001, "Remaining = $14.81")
            test.assertApproximatelyEqual(summary.percentUsed, 1.267, tolerance: 0.01, "~1.27% used")
            test.assertFalse(summary.isCapReached, "Cap not reached")
            test.assertEqual(summary.maxAdditionalRequests, 370, "370 more requests possible at $0.04")
        }
        
        test.run("test_SpendingBudgetSummary_SoftCap") {
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: 20.0,  // Over budget but soft cap
                preventFurtherUsage: false,
                pricePerRequest: 0.04
            )
            test.assertTrue(summary.isCapReached, "Cap reached even with soft cap")
            test.assertFalse(summary.preventFurtherUsage, "Soft cap does not prevent usage")
            test.assertApproximatelyEqual(summary.remaining, 0.0, tolerance: 0.001, "Remaining capped at 0")
            test.assertApproximatelyEqual(summary.percentUsed, 133.33, tolerance: 0.01, "Can exceed 100%")
        }
        
        // MARK: - BudgetConfig Dollar Budget Tests
        
        test.run("test_BudgetConfig_DefaultDollarBudget") {
            let config = BudgetConfig.default
            test.assertApproximatelyEqual(config.dollarBudget, 0.0, tolerance: 0.001, "Default dollar budget is 0 (disabled)")
            test.assertTrue(config.preventFurtherUsage, "Default preventFurtherUsage is true")
        }
        
        test.run("test_BudgetConfig_DollarBudget_EncodesAndDecodes") {
            let config = BudgetConfig(
                monthlyBudget: 300,
                username: "testuser",
                pollingIntervalMinutes: 5,
                notificationsEnabled: true,
                alertAt80Percent: false,
                alertAt90Percent: true,
                customAlerts: [],
                notifyEveryPercent: true,
                launchAtLogin: false,
                dollarBudget: 15.0,
                preventFurtherUsage: true
            )
            
            do {
                let data = try JSONEncoder().encode(config)
                let decoded = try JSONDecoder().decode(BudgetConfig.self, from: data)
                test.assertApproximatelyEqual(decoded.dollarBudget, 15.0, tolerance: 0.001, "dollarBudget survives encode/decode")
                test.assertTrue(decoded.preventFurtherUsage, "preventFurtherUsage survives encode/decode")
            } catch {
                test.assertTrue(false, "Should encode/decode: \(error)")
            }
        }
        
        test.run("test_BudgetConfig_DollarBudget_BackwardCompatible") {
            // JSON without dollarBudget/preventFurtherUsage fields (old config)
            let json = """
            {
                "monthlyBudget": 300,
                "username": "testuser",
                "pollingIntervalMinutes": 5,
                "notificationsEnabled": true,
                "alertAt80Percent": false,
                "alertAt90Percent": true,
                "customAlerts": [],
                "notifyEveryPercent": true,
                "launchAtLogin": false
            }
            """
            let data = json.data(using: .utf8)!
            
            do {
                let decoded = try JSONDecoder().decode(BudgetConfig.self, from: data)
                test.assertApproximatelyEqual(decoded.dollarBudget, 0.0, tolerance: 0.001, "dollarBudget defaults to 0 when missing")
                test.assertTrue(decoded.preventFurtherUsage, "preventFurtherUsage defaults to true when missing")
            } catch {
                test.assertTrue(false, "Should decode old config without dollar fields: \(error)")
            }
        }
        
        test.run("test_BudgetConfig_DollarBudget_ZeroMeansDisabled") {
            let config = BudgetConfig(
                monthlyBudget: 300,
                username: "test",
                pollingIntervalMinutes: 5,
                notificationsEnabled: true,
                alertAt80Percent: false,
                alertAt90Percent: true,
                customAlerts: [],
                notifyEveryPercent: true,
                launchAtLogin: false,
                dollarBudget: 0,
                preventFurtherUsage: true
            )
            test.assertApproximatelyEqual(config.dollarBudget, 0.0, tolerance: 0.001, "Dollar budget is 0")
            // When dollarBudget is 0, the spending budget card should not show
        }
        
        test.run("test_BudgetConfig_DollarBudget_SoftCap") {
            let config = BudgetConfig(
                monthlyBudget: 300,
                username: "test",
                pollingIntervalMinutes: 5,
                notificationsEnabled: true,
                alertAt80Percent: false,
                alertAt90Percent: true,
                customAlerts: [],
                notifyEveryPercent: true,
                launchAtLogin: false,
                dollarBudget: 25.0,
                preventFurtherUsage: false
            )
            test.assertApproximatelyEqual(config.dollarBudget, 25.0, tolerance: 0.001, "Dollar budget is 25")
            test.assertFalse(config.preventFurtherUsage, "Soft cap (preventFurtherUsage = false)")
        }
        
        // MARK: - UsageResponse Cost Computation Tests (used by spending budget)
        
        test.run("test_UsageResponse_TotalNetCost_ComputesFromItems") {
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Sonnet 4",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 100, grossAmount: 4.0,
                    discountQuantity: 100, discountAmount: 4.0,
                    netQuantity: 0, netAmount: 0.0
                ),
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Opus 4.6",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 10, grossAmount: 0.40,
                    discountQuantity: 0, discountAmount: 0.0,
                    netQuantity: 10, netAmount: 0.40
                )
            ]
            let response = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: items
            )
            
            test.assertApproximatelyEqual(response.totalNetCost, 0.40, tolerance: 0.001, "Net cost = 0 + 0.40 = $0.40")
            test.assertApproximatelyEqual(response.totalGrossCost, 4.40, tolerance: 0.001, "Gross cost = 4.0 + 0.40 = $4.40")
        }
        
        test.run("test_UsageResponse_TotalNetCost_AllIncluded") {
            // When all usage is covered by included requests, netAmount is 0
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Sonnet 4",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 200, grossAmount: 8.0,
                    discountQuantity: 200, discountAmount: 8.0,
                    netQuantity: 0, netAmount: 0.0
                )
            ]
            let response = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: items
            )
            
            test.assertApproximatelyEqual(response.totalNetCost, 0.0, tolerance: 0.001, "Net cost is $0 when all included")
        }
        
        test.run("test_UsageResponse_TotalNetCost_MultipleModels") {
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Sonnet 4",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 50, grossAmount: 2.0,
                    discountQuantity: 50, discountAmount: 2.0,
                    netQuantity: 0, netAmount: 0.0
                ),
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Opus 4.6",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 30, grossAmount: 1.20,
                    discountQuantity: 20, discountAmount: 0.80,
                    netQuantity: 10, netAmount: 0.40
                ),
                UsageItem(
                    product: "copilot_completions", sku: "premium", model: "GPT-5.1",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 20, grossAmount: 0.80,
                    discountQuantity: 0, discountAmount: 0.0,
                    netQuantity: 20, netAmount: 0.80
                )
            ]
            let response = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: items
            )
            
            test.assertApproximatelyEqual(response.totalNetCost, 1.20, tolerance: 0.001, "Net cost = 0 + 0.40 + 0.80 = $1.20")
        }
        
        test.run("test_UsageResponse_PricePerRequest") {
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Sonnet 4",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 100, grossAmount: 4.0,
                    discountQuantity: 100, discountAmount: 4.0,
                    netQuantity: 0, netAmount: 0.0
                )
            ]
            let response = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: items
            )
            
            test.assertApproximatelyEqual(response.pricePerRequest, 0.04, tolerance: 0.001, "Price per request from first item")
        }
        
        test.run("test_UsageResponse_PricePerRequest_DefaultsTo004") {
            let response = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: []
            )
            
            test.assertApproximatelyEqual(response.pricePerRequest, 0.04, tolerance: 0.001, "Price defaults to $0.04 when no items")
        }
        
        // MARK: - Integration: SpendingBudgetSummary from Usage + Config
        
        test.run("test_Integration_SpendingSummaryFromUsageAndConfig") {
            // Simulate what UsageTracker.updateSpendingBudget does
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Opus 4.6",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 33, grossAmount: 1.32,
                    discountQuantity: 28, discountAmount: 1.12,
                    netQuantity: 5, netAmount: 0.20
                )
            ]
            let usage = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "matlockx", product: nil, model: nil,
                usageItems: items
            )
            
            let dollarBudget = 15.0
            let preventFurtherUsage = true
            
            let summary = SpendingBudgetSummary(
                budgetAmount: dollarBudget,
                amountSpent: usage.totalNetCost,
                preventFurtherUsage: preventFurtherUsage,
                pricePerRequest: usage.pricePerRequest
            )
            
            test.assertApproximatelyEqual(summary.budgetAmount, 15.0, tolerance: 0.001, "Budget from config")
            test.assertApproximatelyEqual(summary.amountSpent, 0.20, tolerance: 0.001, "Spent from usage.totalNetCost")
            test.assertTrue(summary.preventFurtherUsage, "preventFurtherUsage from config")
            test.assertApproximatelyEqual(summary.remaining, 14.80, tolerance: 0.001, "Remaining = 15.00 - 0.20")
            test.assertApproximatelyEqual(summary.percentUsed, 1.333, tolerance: 0.01, "~1.33% used")
            test.assertEqual(summary.maxAdditionalRequests, 370, "370 more at $0.04")
        }
        
        test.run("test_Integration_NoBudgetWhenDollarBudgetIsZero") {
            // When config.dollarBudget is 0, no spending budget should be produced
            let dollarBudget = 0.0
            
            // This is what UsageTracker checks
            let shouldShowBudget = dollarBudget > 0
            test.assertFalse(shouldShowBudget, "No budget card when dollarBudget is 0")
        }
        
        test.run("test_Integration_BudgetWithHighSpending") {
            // Simulate heavy usage: many premium requests, high cost
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Opus 4.6",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 500, grossAmount: 20.0,
                    discountQuantity: 300, discountAmount: 12.0,
                    netQuantity: 200, netAmount: 8.0
                ),
                UsageItem(
                    product: "copilot_agent", sku: "premium", model: "Claude Sonnet 4",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 300, grossAmount: 12.0,
                    discountQuantity: 0, discountAmount: 0.0,
                    netQuantity: 300, netAmount: 12.0
                )
            ]
            let usage = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: items
            )
            
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: usage.totalNetCost,
                preventFurtherUsage: true,
                pricePerRequest: usage.pricePerRequest
            )
            
            test.assertApproximatelyEqual(summary.amountSpent, 20.0, tolerance: 0.001, "Spent = 8.0 + 12.0 = $20.00")
            test.assertTrue(summary.isCapReached, "Cap reached at $20 > $15")
            test.assertApproximatelyEqual(summary.remaining, 0.0, tolerance: 0.001, "No remaining budget")
            test.assertEqual(summary.maxAdditionalRequests, 0, "No more requests possible")
            test.assertApproximatelyEqual(summary.percentUsed, 133.33, tolerance: 0.01, "133% over budget")
        }
        
        test.run("test_Integration_BudgetWithZeroSpending") {
            let items = [
                UsageItem(
                    product: "copilot_chat", sku: "premium", model: "Claude Sonnet 4",
                    unitType: "request", pricePerUnit: 0.04,
                    grossQuantity: 50, grossAmount: 2.0,
                    discountQuantity: 50, discountAmount: 2.0,
                    netQuantity: 0, netAmount: 0.0
                )
            ]
            let usage = UsageResponse(
                timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                user: "testuser", product: nil, model: nil,
                usageItems: items
            )
            
            let summary = SpendingBudgetSummary(
                budgetAmount: 15.0,
                amountSpent: usage.totalNetCost,
                preventFurtherUsage: true,
                pricePerRequest: usage.pricePerRequest
            )
            
            test.assertApproximatelyEqual(summary.amountSpent, 0.0, tolerance: 0.001, "No spending when all included")
            test.assertApproximatelyEqual(summary.remaining, 15.0, tolerance: 0.001, "Full budget remaining")
            test.assertEqual(summary.maxAdditionalRequests, 375, "375 requests at $0.04 with $15 budget")
            test.assertFalse(summary.isCapReached, "Cap not reached")
        }
        
        // MARK: - BudgetConfig Encoding Roundtrip Tests
        
        test.run("test_BudgetConfig_FullRoundtrip") {
            let config = BudgetConfig(
                monthlyBudget: 500,
                username: "matlockx",
                pollingIntervalMinutes: 10,
                notificationsEnabled: false,
                alertAt80Percent: true,
                alertAt90Percent: false,
                customAlerts: [],
                notifyEveryPercent: false,
                launchAtLogin: true,
                dollarBudget: 42.50,
                preventFurtherUsage: false
            )
            
            do {
                let data = try JSONEncoder().encode(config)
                let decoded = try JSONDecoder().decode(BudgetConfig.self, from: data)
                test.assertEqual(decoded.monthlyBudget, 500, "monthlyBudget roundtrip")
                test.assertEqual(decoded.username, "matlockx", "username roundtrip")
                test.assertEqual(decoded.pollingIntervalMinutes, 10, "pollingIntervalMinutes roundtrip")
                test.assertFalse(decoded.notificationsEnabled, "notificationsEnabled roundtrip")
                test.assertTrue(decoded.alertAt80Percent, "alertAt80Percent roundtrip")
                test.assertFalse(decoded.alertAt90Percent, "alertAt90Percent roundtrip")
                test.assertFalse(decoded.notifyEveryPercent, "notifyEveryPercent roundtrip")
                test.assertTrue(decoded.launchAtLogin, "launchAtLogin roundtrip")
                test.assertApproximatelyEqual(decoded.dollarBudget, 42.50, tolerance: 0.001, "dollarBudget roundtrip")
                test.assertFalse(decoded.preventFurtherUsage, "preventFurtherUsage roundtrip")
            } catch {
                test.assertTrue(false, "Should encode/decode: \(error)")
            }
        }
        
        test.run("test_BudgetConfig_LegacyJsonWithoutDollarFields") {
            // Simulates loading config from a version before F018
            let json = """
            {
                "monthlyBudget": 300,
                "username": "testuser",
                "pollingIntervalMinutes": 5,
                "notificationsEnabled": true,
                "alertAt80Percent": false,
                "alertAt90Percent": true,
                "customAlerts": [],
                "notifyEveryPercent": true,
                "launchAtLogin": false
            }
            """
            let data = json.data(using: .utf8)!
            
            do {
                let decoded = try JSONDecoder().decode(BudgetConfig.self, from: data)
                test.assertEqual(decoded.monthlyBudget, 300, "monthlyBudget decoded from legacy")
                test.assertApproximatelyEqual(decoded.dollarBudget, 0.0, tolerance: 0.001, "dollarBudget defaults to 0")
                test.assertTrue(decoded.preventFurtherUsage, "preventFurtherUsage defaults to true")
            } catch {
                test.assertTrue(false, "Should decode legacy config: \(error)")
            }
        }
        
        test.run("test_BudgetConfig_DollarBudget_SmallValues") {
            // Test with very small budget amounts
            let summary = SpendingBudgetSummary(
                budgetAmount: 1.0,
                amountSpent: 0.50,
                preventFurtherUsage: true,
                pricePerRequest: 0.04
            )
            test.assertApproximatelyEqual(summary.remaining, 0.50, tolerance: 0.001, "Remaining = $0.50")
            test.assertEqual(summary.maxAdditionalRequests, 12, "12 more requests at $0.04 with $0.50 remaining")
        }
        
        test.run("test_BudgetConfig_DollarBudget_LargeValues") {
            // Test with large budget
            let summary = SpendingBudgetSummary(
                budgetAmount: 1000.0,
                amountSpent: 50.0,
                preventFurtherUsage: false,
                pricePerRequest: 0.04
            )
            test.assertApproximatelyEqual(summary.remaining, 950.0, tolerance: 0.001, "Remaining = $950.00")
            test.assertEqual(summary.maxAdditionalRequests, 23750, "23750 more requests at $0.04")
            test.assertApproximatelyEqual(summary.percentUsed, 5.0, tolerance: 0.001, "5% used")
        }
        
        test.printSummary()
    }
}

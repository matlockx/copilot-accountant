import Foundation

// Test Framework
class TestCase {
    var passed: Int = 0
    var failed: Int = 0
    
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        if actual == expected {
            passed += 1
            print("  ✓ PASSED: \(message.isEmpty ? "assertEqual" : message)")
        } else {
            failed += 1
            print("  ✗ FAILED: \(message.isEmpty ? "assertEqual" : message)")
            print("    Expected: \(expected)")
            print("    Actual:   \(actual)")
        }
    }
    
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition {
            passed += 1
            print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)")
        } else {
            failed += 1
            print("  ✗ FAILED: \(message.isEmpty ? "assertTrue" : message)")
        }
    }
    
    func assertApproximatelyEqual(_ actual: Double, _ expected: Double, tolerance: Double = 0.001, _ message: String = "") {
        if abs(actual - expected) <= tolerance {
            passed += 1
            print("  ✓ PASSED: \(message.isEmpty ? "assertApproximatelyEqual" : message)")
        } else {
            failed += 1
            print("  ✗ FAILED: \(message.isEmpty ? "assertApproximatelyEqual" : message)")
            print("    Expected: \(expected) (±\(tolerance))")
            print("    Actual:   \(actual)")
        }
    }
    
    func run(_ name: String, _ testFunc: () -> Void) {
        print("\n▶ \(name)")
        testFunc()
    }
    
    func printSummary() {
        print("\n=========================================")
        if failed > 0 {
            print("FAILED: \(passed) passed, \(failed) failed")
            exit(1)
        } else {
            print("PASSED: \(passed) tests passed")
        }
    }
}

// =============================================================================
// F002: Usage Calculation Tests
// =============================================================================

@main
struct UsageCalculationTests {
    static func main() {
        let test = TestCase()
        
        print("=========================================")
        print("F002: Usage Calculation Tests")
        print("=========================================")
        
        // Test 1: Total requests uses grossQuantity
        test.run("test_UsageCalculation_TotalRequests_UsesGrossQuantity") {
            let json = """
            {
                "timePeriod": {"year": 2026, "month": 3},
                "user": "testuser",
                "usageItems": [
                    {
                        "product": "copilot",
                        "sku": "premium",
                        "model": "gpt-4",
                        "unitType": "requests",
                        "pricePerUnit": 0.05,
                        "grossQuantity": 33.0,
                        "grossAmount": 1.65,
                        "discountQuantity": 33.0,
                        "discountAmount": 1.65,
                        "netQuantity": 0.0,
                        "netAmount": 0.0
                    }
                ]
            }
            """
            
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let usage = try! decoder.decode(UsageResponse.self, from: data)
            
            let total = usage.totalRequests
            test.assertEqual(total, 33, "Total should be 33 (grossQuantity), not 0 (netQuantity)")
        }
        
        // Test 2: Multiple items sum correctly
        test.run("test_UsageCalculation_MultipleItems_SumsCorrectly") {
            let json = """
            {
                "timePeriod": {"year": 2026, "month": 3},
                "user": "testuser",
                "usageItems": [
                    {"product": "copilot", "sku": "premium", "model": "gpt-4", "unitType": "requests", "pricePerUnit": 0.05, "grossQuantity": 100.0, "grossAmount": 5.0, "discountQuantity": 0.0, "discountAmount": 0.0, "netQuantity": 0.0, "netAmount": 0.0},
                    {"product": "copilot", "sku": "premium", "model": "claude-3", "unitType": "requests", "pricePerUnit": 0.03, "grossQuantity": 50.0, "grossAmount": 1.5, "discountQuantity": 0.0, "discountAmount": 0.0, "netQuantity": 0.0, "netAmount": 0.0},
                    {"product": "copilot", "sku": "premium", "model": "o1", "unitType": "requests", "pricePerUnit": 0.10, "grossQuantity": 25.0, "grossAmount": 2.5, "discountQuantity": 0.0, "discountAmount": 0.0, "netQuantity": 0.0, "netAmount": 0.0}
                ]
            }
            """
            
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let usage = try! decoder.decode(UsageResponse.self, from: data)
            
            test.assertEqual(usage.totalRequests, 175, "Total should be 175 (sum of all grossQuantity)")
        }
        
        // Test 3: Empty usage items
        test.run("test_UsageCalculation_EmptyItems_ReturnsZero") {
            let json = """
            {"timePeriod": {"year": 2026, "month": 3}, "user": "testuser", "usageItems": []}
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let usage = try! decoder.decode(UsageResponse.self, from: data)
            test.assertEqual(usage.totalRequests, 0, "Empty usage items should return 0")
        }
        
        // Test 4: Usage percentage calculation
        test.run("test_UsageCalculation_Percentage_CalculatesCorrectly") {
            let config = BudgetConfig(
                monthlyBudget: 300,
                username: "testuser",
                pollingIntervalMinutes: 5,
                notificationsEnabled: true,
                alertAt80Percent: true,
                alertAt90Percent: true,
                customAlertEnabled: false,
                customAlertPercent: 75,
                launchAtLogin: false
            )
            
            test.assertApproximatelyEqual(config.usagePercentage(used: 0), 0.0, tolerance: 0.01, "0/300 = 0%")
            test.assertApproximatelyEqual(config.usagePercentage(used: 150), 50.0, tolerance: 0.01, "150/300 = 50%")
            test.assertApproximatelyEqual(config.usagePercentage(used: 240), 80.0, tolerance: 0.01, "240/300 = 80%")
            test.assertApproximatelyEqual(config.usagePercentage(used: 270), 90.0, tolerance: 0.01, "270/300 = 90%")
            test.assertApproximatelyEqual(config.usagePercentage(used: 300), 100.0, tolerance: 0.01, "300/300 = 100%")
        }
        
        // Test 5: Zero budget edge case
        test.run("test_UsageCalculation_ZeroBudget_ReturnsZeroPercentage") {
            let config = BudgetConfig(monthlyBudget: 0, username: "testuser", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertEqual(config.usagePercentage(used: 100), 0.0, "Zero budget should return 0%")
        }
        
        // Test 6: Threshold calculations
        test.run("test_UsageCalculation_Thresholds_CalculateCorrectly") {
            let config = BudgetConfig(monthlyBudget: 300, username: "testuser", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            test.assertEqual(config.threshold80, 240, "80% of 300 = 240")
            test.assertEqual(config.threshold90, 270, "90% of 300 = 270")
        }
        
        // Test 7: Status colors
        test.run("test_UsageCalculation_StatusColors_CorrectForThresholds") {
            let config = BudgetConfig(monthlyBudget: 100, username: "testuser", pollingIntervalMinutes: 5, notificationsEnabled: true, alertAt80Percent: true, alertAt90Percent: true, customAlertEnabled: false, customAlertPercent: 75, launchAtLogin: false)
            
            test.assertTrue(config.statusColor(used: 0) == .green, "0% should be green")
            test.assertTrue(config.statusColor(used: 59) == .green, "59% should be green")
            test.assertTrue(config.statusColor(used: 60) == .yellow, "60% should be yellow")
            test.assertTrue(config.statusColor(used: 79) == .yellow, "79% should be yellow")
            test.assertTrue(config.statusColor(used: 80) == .orange, "80% should be orange")
            test.assertTrue(config.statusColor(used: 89) == .orange, "89% should be orange")
            test.assertTrue(config.statusColor(used: 90) == .red, "90% should be red")
            test.assertTrue(config.statusColor(used: 100) == .red, "100% should be red")
        }
        
        test.printSummary()
    }
}

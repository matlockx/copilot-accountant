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
    func assertApproximatelyEqual(_ actual: Double, _ expected: Double, tolerance: Double = 0.001, _ message: String = "") {
        if abs(actual - expected) <= tolerance { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertApproximatelyEqual" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertNotNil<T>(_ value: T?, _ message: String = "") {
        if value != nil { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertNotNil" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

func createTestUsage(models: [(String, Double, Double?)]) -> UsageResponse {
    var items: [[String: Any]] = []
    for (model, quantity, customPrice) in models {
        let price = customPrice ?? 0.05
        items.append(["product": "copilot", "sku": "premium", "model": model, "unitType": "requests",
                      "pricePerUnit": price, "grossQuantity": quantity, "grossAmount": quantity * price,
                      "discountQuantity": 0.0, "discountAmount": 0.0, "netQuantity": 0.0, "netAmount": 0.0])
    }
    let response: [String: Any] = ["timePeriod": ["year": 2026, "month": 3], "user": "testuser", "usageItems": items]
    let data = try! JSONSerialization.data(withJSONObject: response)
    let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try! decoder.decode(UsageResponse.self, from: data)
}

@main
struct DetailedStatsTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F013: Detailed Stats Tests")
        print("=========================================")
        
        test.run("test_DetailedStats_ModelUsageStructure") {
            let modelUsage = ModelUsage(modelName: "gpt-4", requestCount: 100.0, percentage: 50.0)
            test.assertEqual(modelUsage.modelName, "gpt-4", "Model name stored")
            test.assertEqual(modelUsage.requestCount, 100.0, "Request count stored")
            test.assertEqual(modelUsage.percentage, 50.0, "Percentage stored")
            test.assertNotNil(modelUsage.id, "Should have UUID id")
        }
        
        test.run("test_DetailedStats_DailyUsageStructure") {
            let daily = DailyUsage(date: Date(), requests: 42)
            test.assertEqual(daily.requests, 42, "Requests stored")
            test.assertNotNil(daily.id, "Should have UUID id")
        }
        
        test.run("test_DetailedStats_PercentageCalculations") {
            let usage = createTestUsage(models: [("model-a", 50.0, nil), ("model-b", 30.0, nil), ("model-c", 20.0, nil)])
            let total = Double(usage.totalRequests)
            let byModel = usage.usageByModel
            test.assertApproximatelyEqual((byModel["model-a"]! / total) * 100.0, 50.0, tolerance: 0.1, "model-a is 50%")
            test.assertApproximatelyEqual((byModel["model-b"]! / total) * 100.0, 30.0, tolerance: 0.1, "model-b is 30%")
            test.assertApproximatelyEqual((byModel["model-c"]! / total) * 100.0, 20.0, tolerance: 0.1, "model-c is 20%")
        }

        test.run("test_DetailedStats_BillingTotals_UseGrossAndNetAmounts") {
            let usage = createTestUsage(models: [("gpt-4", 10.0, nil), ("claude-opus", 5.0, nil)])
            test.assertApproximatelyEqual(usage.totalGrossCost, 0.75, tolerance: 0.001, "Gross cost sums all line items")
            test.assertApproximatelyEqual(usage.totalNetCost, 0.0, tolerance: 0.001, "Net cost reflects billed amount after included usage")
        }

        test.run("test_DetailedStats_ModelCostFactors_AreRelativeToCheapestModel") {
            let usage = createTestUsage(models: [("cheap-model", 10.0, 0.04), ("expensive-model", 10.0, 0.14)])
            let factors = usage.modelCostFactors
            test.assertApproximatelyEqual(factors["cheap-model"] ?? 0, 1.0, tolerance: 0.001, "Cheapest model has factor 1.0")
            test.assertApproximatelyEqual(factors["expensive-model"] ?? 0, 3.5, tolerance: 0.001, "More expensive model shows relative factor")
        }

        test.run("test_DetailedStats_ModelCostFactors_HideRelativeFactorWhenPricesMatch") {
            let usage = createTestUsage(models: [("model-a", 10.0, 0.04), ("model-b", 10.0, 0.04)])
            test.assertTrue(usage.hasMeaningfulModelFactors == false, "Equal prices do not claim different relative factors")
        }

        test.run("test_DetailedStats_IncludedBudgetAndOverageCalculation") {
            let usage = createTestUsage(models: [("model", 350.0, nil)])
            let summary = usage.billingSummary(includedRequests: 300)
            test.assertEqual(summary.includedRequests, 300, "Included budget mirrors configured monthly budget")
            test.assertEqual(summary.usedRequests, 350, "Used requests match usage total")
            test.assertEqual(summary.overageRequests, 50, "Overage requests are requests beyond included budget")
        }
        
        test.run("test_DetailedStats_DaysUntilReset") {
            let calendar = Calendar.current
            let now = Date()
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
                  let firstOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) else {
                test.assertTrue(false, "Should calculate next month"); return
            }
            let components = calendar.dateComponents([.day], from: now, to: firstOfNextMonth)
            let daysUntilReset = components.day ?? 0
            test.assertTrue(daysUntilReset >= 0, "Days >= 0")
            test.assertTrue(daysUntilReset <= 31, "Days <= 31")
        }
        
        test.run("test_DetailedStats_EmptyUsage_ZeroPercentages") {
            let usage = createTestUsage(models: [])
            test.assertEqual(usage.totalRequests, 0, "Empty usage has 0 total")
            test.assertEqual(usage.usageByModel.count, 0, "Empty usage has no models")
        }
        
        test.run("test_DetailedStats_TimePeriodInfo") {
            let usage = createTestUsage(models: [("model", 10.0, nil)])
            test.assertEqual(usage.timePeriod.year, 2026, "Year correct")
            test.assertEqual(usage.timePeriod.month, 3, "Month correct")
        }

        test.run("test_DetailedStats_WindowConfiguration_IsResizable") {
            test.assertTrue(DetailedStatsWindowConfiguration.styleMask.contains(.resizable), "Detailed stats window supports resizing")
            test.assertEqual(DetailedStatsWindowConfiguration.initialSize.width, 700, "Initial width is 700")
            test.assertEqual(DetailedStatsWindowConfiguration.initialSize.height, 600, "Initial height is 600")
        }

        test.run("test_DetailedStats_WindowConfiguration_HasMinimumSize") {
            test.assertEqual(DetailedStatsWindowConfiguration.minSize.width, 600, "Minimum width prevents cramped charts")
            test.assertEqual(DetailedStatsWindowConfiguration.minSize.height, 500, "Minimum height prevents cramped charts")
        }
        
        test.printSummary()
    }
}

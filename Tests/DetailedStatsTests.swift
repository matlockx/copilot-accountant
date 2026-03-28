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

/// Extended test helper that supports specifying billed (net) quantities for overage testing
func createTestUsageWithBilling(models: [(model: String, gross: Double, net: Double, price: Double)]) -> UsageResponse {
    var items: [[String: Any]] = []
    for item in models {
        let grossAmount = item.gross * item.price
        let netAmount = item.net * item.price
        let discountAmount = grossAmount - netAmount
        items.append([
            "product": "copilot", "sku": "premium", "model": item.model, "unitType": "requests",
            "pricePerUnit": item.price, 
            "grossQuantity": item.gross, "grossAmount": grossAmount,
            "discountQuantity": item.gross - item.net, "discountAmount": discountAmount,
            "netQuantity": item.net, "netAmount": netAmount
        ])
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
            test.assertEqual(DetailedStatsWindowConfiguration.initialSize.width, 820, "Initial width is 820")
            test.assertEqual(DetailedStatsWindowConfiguration.initialSize.height, 700, "Initial height is 700")
        }

        test.run("test_DetailedStats_WindowConfiguration_HasMinimumSize") {
            test.assertEqual(DetailedStatsWindowConfiguration.minSize.width, 750, "Minimum width prevents clipping")
            test.assertEqual(DetailedStatsWindowConfiguration.minSize.height, 550, "Minimum height prevents cramped charts")
        }

        // New tests for enhanced billing details
        
        test.run("test_DetailedStats_PricePerRequest_ExtractsFromUsageItems") {
            let usage = createTestUsage(models: [("claude-opus", 100.0, 0.04)])
            test.assertApproximatelyEqual(usage.pricePerRequest, 0.04, tolerance: 0.001, "Price per request extracted from usage items")
        }
        
        test.run("test_DetailedStats_PricePerRequest_DefaultsWhenEmpty") {
            let usage = createTestUsage(models: [])
            test.assertApproximatelyEqual(usage.pricePerRequest, 0.04, tolerance: 0.001, "Price per request defaults to 0.04 when no items")
        }
        
        test.run("test_DetailedStats_AllModelsSamePrice_TrueWhenEqual") {
            let usage = createTestUsage(models: [("model-a", 50.0, 0.04), ("model-b", 30.0, 0.04)])
            test.assertTrue(usage.allModelsSamePrice, "All models same price when prices equal")
        }
        
        test.run("test_DetailedStats_AllModelsSamePrice_FalseWhenDifferent") {
            let usage = createTestUsage(models: [("cheap", 50.0, 0.04), ("expensive", 30.0, 0.14)])
            test.assertTrue(!usage.allModelsSamePrice, "Not all same price when prices differ")
        }
        
        test.run("test_DetailedStats_BillingPeriodDescription_FormatsCorrectly") {
            let usage = createTestUsage(models: [("model", 10.0, nil)])
            test.assertEqual(usage.billingPeriodDescription, "Mar 1 - Mar 31, 2026", "Billing period formatted correctly")
        }
        
        test.run("test_DetailedStats_ResetDate_CalculatesNextMonth") {
            let usage = createTestUsage(models: [("model", 10.0, nil)])
            let calendar = Calendar.current
            let resetDate = usage.resetDate
            let components = calendar.dateComponents([.year, .month, .day], from: resetDate)
            test.assertEqual(components.year, 2026, "Reset year is 2026")
            test.assertEqual(components.month, 4, "Reset month is April (next month)")
            test.assertEqual(components.day, 1, "Reset day is 1st")
        }
        
        test.run("test_DetailedStats_ResetDateDescription_FormatsCorrectly") {
            let usage = createTestUsage(models: [("model", 10.0, nil)])
            test.assertEqual(usage.resetDateDescription, "April 1, 2026", "Reset date description formatted correctly")
        }
        
        test.run("test_DetailedStats_ModelBillingDetails_CalculatesIncludedVsBilled") {
            // When all requests are included (netQuantity = 0), all should be "included"
            let usage = createTestUsageWithBilling(models: [
                (model: "claude-opus", gross: 96.0, net: 0.0, price: 0.04),
                (model: "gpt-5.4", gross: 64.0, net: 0.0, price: 0.04)
            ])
            let details = usage.modelBillingDetails()
            test.assertEqual(details.count, 2, "Two models in details")
            
            // Claude Opus should be first (higher usage)
            let opus = details[0]
            test.assertEqual(opus.model, "claude-opus", "First model is claude-opus")
            test.assertApproximatelyEqual(opus.totalRequests, 96.0, tolerance: 0.01, "Total requests correct")
            test.assertApproximatelyEqual(opus.includedRequests, 96.0, tolerance: 0.01, "All requests included when net=0")
            test.assertApproximatelyEqual(opus.billedRequests, 0.0, tolerance: 0.01, "No billed requests when net=0")
            test.assertApproximatelyEqual(opus.grossAmount, 3.84, tolerance: 0.01, "Gross amount = 96 * 0.04")
            test.assertApproximatelyEqual(opus.billedAmount, 0.0, tolerance: 0.01, "Billed amount is 0")
        }
        
        test.run("test_DetailedStats_ModelBillingDetails_HandlesOverage") {
            // When there's overage, netQuantity > 0 represents billed requests
            let usage = createTestUsageWithBilling(models: [
                (model: "claude-opus", gross: 150.0, net: 50.0, price: 0.04)  // 100 included, 50 billed
            ])
            let details = usage.modelBillingDetails()
            test.assertEqual(details.count, 1, "One model in details")
            
            let opus = details[0]
            test.assertApproximatelyEqual(opus.totalRequests, 150.0, tolerance: 0.01, "Total requests correct")
            test.assertApproximatelyEqual(opus.includedRequests, 100.0, tolerance: 0.01, "100 requests included (gross - net)")
            test.assertApproximatelyEqual(opus.billedRequests, 50.0, tolerance: 0.01, "50 requests billed (net)")
            test.assertApproximatelyEqual(opus.grossAmount, 6.0, tolerance: 0.01, "Gross amount = 150 * 0.04")
            test.assertApproximatelyEqual(opus.billedAmount, 2.0, tolerance: 0.01, "Billed amount = 50 * 0.04")
        }
        
        test.run("test_DetailedStats_ModelBillingDetails_SortsByUsageDescending") {
            let usage = createTestUsageWithBilling(models: [
                (model: "low-usage", gross: 10.0, net: 0.0, price: 0.04),
                (model: "high-usage", gross: 100.0, net: 0.0, price: 0.04),
                (model: "medium-usage", gross: 50.0, net: 0.0, price: 0.04)
            ])
            let details = usage.modelBillingDetails()
            test.assertEqual(details[0].model, "high-usage", "Highest usage first")
            test.assertEqual(details[1].model, "medium-usage", "Medium usage second")
            test.assertEqual(details[2].model, "low-usage", "Lowest usage third")
        }
        
        test.run("test_DetailedStats_BillingSummary_IncludesDiscountAmount") {
            let usage = createTestUsageWithBilling(models: [
                (model: "model", gross: 100.0, net: 0.0, price: 0.04)
            ])
            let summary = usage.billingSummary(includedRequests: 300)
            test.assertApproximatelyEqual(summary.discountAmount, 4.0, tolerance: 0.01, "Discount amount = gross - net = 4.0")
            test.assertApproximatelyEqual(summary.includedUsed, 100.0, tolerance: 0.01, "Included used = min(used, included)")
            test.assertApproximatelyEqual(summary.includedPercentage, 33.33, tolerance: 0.1, "Included percentage = 100/300 * 100")
        }
        
        test.run("test_DetailedStats_BillingSummary_IncludedPercentageCapped") {
            let usage = createTestUsageWithBilling(models: [
                (model: "model", gross: 400.0, net: 100.0, price: 0.04)
            ])
            let summary = usage.billingSummary(includedRequests: 300)
            test.assertApproximatelyEqual(summary.includedUsed, 300.0, tolerance: 0.01, "Included used capped at budget")
            test.assertApproximatelyEqual(summary.includedPercentage, 100.0, tolerance: 0.01, "Included percentage capped at 100%")
        }
        
        test.run("test_DetailedStats_ModelBillingDetails_IncludesMultiplier") {
            let usage = createTestUsageWithBilling(models: [
                (model: "Claude Opus 4.5", gross: 10.0, net: 0.0, price: 0.04),
                (model: "Claude Haiku 4.5", gross: 10.0, net: 0.0, price: 0.04)
            ])
            let details = usage.modelBillingDetails()
            let opus = details.first { $0.model == "Claude Opus 4.5" }!
            let haiku = details.first { $0.model == "Claude Haiku 4.5" }!
            test.assertApproximatelyEqual(opus.multiplier, 3.0, tolerance: 0.001, "Claude Opus 4.5 has 3x multiplier")
            test.assertApproximatelyEqual(haiku.multiplier, 0.33, tolerance: 0.001, "Claude Haiku 4.5 has 0.33x multiplier")
        }

        test.run("test_DetailedStats_GrossQuantityAlreadyIncludesMultiplier") {
            // The API's grossQuantity already accounts for model multipliers.
            // Our "Included premium requests consumed" card should show the raw grossQuantity total,
            // matching GitHub's web UI, NOT grossQuantity * multiplier (which would double-count).
            let usage = createTestUsageWithBilling(models: [
                (model: "Claude Opus 4.5", gross: 114.0, net: 0.0, price: 0.04),
                (model: "GPT-5.4", gross: 80.0, net: 0.0, price: 0.04)
            ])
            // Total should be raw sum: 114 + 80 = 194, NOT 114*3 + 80*1 = 422
            test.assertEqual(usage.totalRequests, 194, "Total uses raw grossQuantity sum (API already applies multipliers)")
        }

        test.run("test_CopilotModelMultipliers_DirectMatch") {
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "Claude Opus 4.5"), 3.0, tolerance: 0.001, "Opus 4.5 = 3x")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "Claude Sonnet 4.5"), 1.0, tolerance: 0.001, "Sonnet 4.5 = 1x")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "Claude Haiku 4.5"), 0.33, tolerance: 0.001, "Haiku 4.5 = 0.33x")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "GPT-4o"), 0.0, tolerance: 0.001, "GPT-4o = 0 (included)")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "GPT-5.4"), 1.0, tolerance: 0.001, "GPT-5.4 = 1x")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "GPT-5.4 mini"), 0.33, tolerance: 0.001, "GPT-5.4 mini = 0.33x")
        }

        test.run("test_CopilotModelMultipliers_PartialMatch") {
            // Test fuzzy matching for models not exactly in the table
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "claude-opus-3"), 3.0, tolerance: 0.001, "Partial 'opus' match = 3x")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "claude-sonnet-3.7"), 1.0, tolerance: 0.001, "Partial 'sonnet' match = 1x")
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "claude-haiku-3.5"), 0.33, tolerance: 0.001, "Partial 'haiku' match = 0.33x")
        }

        test.run("test_CopilotModelMultipliers_UnknownModelDefaultsToOne") {
            test.assertApproximatelyEqual(CopilotModelMultipliers.multiplier(for: "some-unknown-model"), 1.0, tolerance: 0.001, "Unknown model defaults to 1x")
        }

        test.run("test_CopilotModelMultipliers_FormatMultiplier") {
            test.assertEqual(CopilotModelMultipliers.formatMultiplier(0.0), "Included", "0x displays as 'Included'")
            test.assertEqual(CopilotModelMultipliers.formatMultiplier(0.33), "0.33x", "0.33x formatted correctly")
            test.assertEqual(CopilotModelMultipliers.formatMultiplier(1.0), "1x", "1.0 formatted as '1x'")
            test.assertEqual(CopilotModelMultipliers.formatMultiplier(3.0), "3x", "3.0 formatted as '3x'")
            test.assertEqual(CopilotModelMultipliers.formatMultiplier(30.0), "30x", "30.0 formatted as '30x'")
        }

        test.printSummary()
    }
}

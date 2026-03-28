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
// F003: Model Usage Tests
// =============================================================================

func createUsageResponse(models: [(String, Double)]) -> UsageResponse {
    var items: [[String: Any]] = []
    for (model, quantity) in models {
        items.append([
            "product": "copilot", "sku": "premium", "model": model, "unitType": "requests",
            "pricePerUnit": 0.05, "grossQuantity": quantity, "grossAmount": quantity * 0.05,
            "discountQuantity": 0.0, "discountAmount": 0.0, "netQuantity": 0.0, "netAmount": 0.0
        ])
    }
    let response: [String: Any] = ["timePeriod": ["year": 2026, "month": 3], "user": "testuser", "usageItems": items]
    let data = try! JSONSerialization.data(withJSONObject: response)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try! decoder.decode(UsageResponse.self, from: data)
}

@main
struct ModelUsageTests {
    static func main() {
        let test = TestCase()
        
        print("=========================================")
        print("F003: Model Usage Tests")
        print("=========================================")
        
        // Test 1: Models sorted by count descending
        test.run("test_ModelUsage_SortedByCountDescending") {
            let usage = createUsageResponse(models: [("gpt-3.5", 10.0), ("gpt-4", 100.0), ("claude-3", 50.0)])
            let byModel = usage.usageByModel
            let sorted = byModel.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            
            test.assertEqual(sorted[0].key, "gpt-4", "First should be gpt-4 (100)")
            test.assertEqual(sorted[1].key, "claude-3", "Second should be claude-3 (50)")
            test.assertEqual(sorted[2].key, "gpt-3.5", "Third should be gpt-3.5 (10)")
        }
        
        // Test 2: Equal counts sorted alphabetically
        test.run("test_ModelUsage_EqualCounts_SortedAlphabetically") {
            let usage = createUsageResponse(models: [("zebra-model", 50.0), ("alpha-model", 50.0), ("beta-model", 50.0)])
            let byModel = usage.usageByModel
            let sorted = byModel.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            
            test.assertEqual(sorted[0].key, "alpha-model", "First should be alpha-model")
            test.assertEqual(sorted[1].key, "beta-model", "Second should be beta-model")
            test.assertEqual(sorted[2].key, "zebra-model", "Third should be zebra-model")
        }
        
        // Test 3: Sorting is deterministic
        test.run("test_ModelUsage_SortingIsDeterministic") {
            let usage = createUsageResponse(models: [("model-c", 50.0), ("model-a", 50.0), ("model-b", 50.0)])
            var results: [[String]] = []
            for _ in 0..<10 {
                let byModel = usage.usageByModel
                let sorted = byModel.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                results.append(sorted.map { $0.key })
            }
            let first = results[0]
            let allSame = results.allSatisfy { $0 == first }
            test.assertTrue(allSame, "Sorting should be deterministic")
            test.assertEqual(first, ["model-a", "model-b", "model-c"], "Order should be alphabetical")
        }
        
        // Test 4: Same model multiple entries aggregates
        test.run("test_ModelUsage_SameModelMultipleEntries_Aggregates") {
            let usage = createUsageResponse(models: [("gpt-4", 30.0), ("gpt-4", 20.0), ("gpt-4", 10.0), ("claude-3", 50.0)])
            let byModel = usage.usageByModel
            test.assertEqual(byModel.count, 2, "Should have 2 unique models")
            test.assertEqual(byModel["gpt-4"], 60.0, "gpt-4 should aggregate to 60")
            test.assertEqual(byModel["claude-3"], 50.0, "claude-3 should be 50")
        }
        
        // Test 5: Empty models
        test.run("test_ModelUsage_NoModels") {
            let usage = createUsageResponse(models: [])
            test.assertEqual(usage.usageByModel.count, 0, "Should have no models")
        }
        
        // Test 6: Percentage calculation
        test.run("test_ModelUsage_PercentageCalculation") {
            let usage = createUsageResponse(models: [("model-a", 50.0), ("model-b", 30.0), ("model-c", 20.0)])
            let total = Double(usage.totalRequests)
            let byModel = usage.usageByModel
            
            test.assertApproximatelyEqual((byModel["model-a"]! / total) * 100.0, 50.0, tolerance: 0.1, "model-a should be 50%")
            test.assertApproximatelyEqual((byModel["model-b"]! / total) * 100.0, 30.0, tolerance: 0.1, "model-b should be 30%")
            test.assertApproximatelyEqual((byModel["model-c"]! / total) * 100.0, 20.0, tolerance: 0.1, "model-c should be 20%")
        }
        
        test.printSummary()
    }
}

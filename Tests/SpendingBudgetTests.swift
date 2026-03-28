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
        
        // MARK: - BudgetResponse Decoding Tests
        
        test.run("test_BudgetResponse_DecodesValidJSON") {
            let json = """
            {
                "budgets": [
                    {
                        "id": "budget-123",
                        "budget_type": "SkuPricing",
                        "budget_amount": 15,
                        "prevent_further_usage": true,
                        "budget_scope": "user",
                        "budget_entity_name": "testuser",
                        "budget_product_sku": "premium_request",
                        "budget_alerting": {
                            "will_alert": true,
                            "alert_recipients": ["test@example.com"]
                        }
                    }
                ],
                "has_next_page": false,
                "total_count": 1
            }
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let response = try decoder.decode(BudgetResponse.self, from: data)
                test.assertEqual(response.budgets.count, 1, "Should have 1 budget")
                test.assertEqual(response.hasNextPage, false, "hasNextPage decoded")
                test.assertEqual(response.totalCount, 1, "totalCount decoded")
            } catch {
                test.assertTrue(false, "Should decode: \(error)")
            }
        }
        
        test.run("test_BudgetItem_DecodesAllFields") {
            let json = """
            {
                "id": "budget-456",
                "budget_type": "SkuPricing",
                "budget_amount": 25,
                "prevent_further_usage": false,
                "budget_scope": "user",
                "budget_entity_name": "matlockx",
                "budget_product_sku": "premium_request",
                "budget_alerting": {
                    "will_alert": true,
                    "alert_recipients": ["user@example.com"]
                }
            }
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let item = try decoder.decode(BudgetItem.self, from: data)
                test.assertEqual(item.id, "budget-456", "id decoded")
                test.assertEqual(item.budgetType, "SkuPricing", "budgetType decoded")
                test.assertEqual(item.budgetAmount, 25, "budgetAmount decoded")
                test.assertEqual(item.preventFurtherUsage, false, "preventFurtherUsage decoded")
                test.assertEqual(item.budgetScope, "user", "budgetScope decoded")
                test.assertEqual(item.budgetEntityName, "matlockx", "budgetEntityName decoded")
                test.assertEqual(item.budgetProductSku, "premium_request", "budgetProductSku decoded")
                test.assertNotNil(item.budgetAlerting, "budgetAlerting decoded")
                test.assertEqual(item.budgetAlerting?.willAlert, true, "willAlert decoded")
            } catch {
                test.assertTrue(false, "Should decode: \(error)")
            }
        }
        
        test.run("test_BudgetItem_HandlesMinimalFields") {
            // Some fields may be optional in practice
            let json = """
            {
                "budget_amount": 10,
                "prevent_further_usage": true
            }
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let item = try decoder.decode(BudgetItem.self, from: data)
                test.assertEqual(item.budgetAmount, 10, "budgetAmount decoded")
                test.assertEqual(item.preventFurtherUsage, true, "preventFurtherUsage decoded")
                test.assertNil(item.id, "id is nil when not provided")
                test.assertNil(item.budgetProductSku, "budgetProductSku is nil when not provided")
            } catch {
                test.assertTrue(false, "Should decode minimal JSON: \(error)")
            }
        }
        
        test.run("test_BudgetResponse_EmptyBudgets") {
            let json = """
            {
                "budgets": [],
                "has_next_page": false,
                "total_count": 0
            }
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let response = try decoder.decode(BudgetResponse.self, from: data)
                test.assertEqual(response.budgets.count, 0, "Should have 0 budgets")
                test.assertEqual(response.totalCount, 0, "totalCount is 0")
            } catch {
                test.assertTrue(false, "Should decode empty budgets: \(error)")
            }
        }
        
        // MARK: - SpendingBudgetSummary Tests
        
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
        
        // MARK: - findPremiumRequestBudget Tests
        
        test.run("test_FindPremiumRequestBudget_MatchesPremiumSku") {
            let budgets = [
                BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 10, preventFurtherUsage: false,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "actions", budgetAlerting: nil),
                BudgetItem(id: "2", budgetType: "SkuPricing", budgetAmount: 15, preventFurtherUsage: true,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "premium_request", budgetAlerting: nil),
                BudgetItem(id: "3", budgetType: "SkuPricing", budgetAmount: 20, preventFurtherUsage: false,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "codespaces", budgetAlerting: nil)
            ]
            let response = BudgetResponse(budgets: budgets, hasNextPage: false, totalCount: 3)
            
            let result = GitHubAPIService.findPremiumRequestBudget(in: response)
            test.assertNotNil(result, "Should find premium budget")
            test.assertEqual(result?.budgetAmount, 15, "Should return the premium_request budget")
            test.assertEqual(result?.preventFurtherUsage, true, "preventFurtherUsage should be true")
        }
        
        test.run("test_FindPremiumRequestBudget_MatchesPartialPremiumSku") {
            let budgets = [
                BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 25, preventFurtherUsage: true,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "All Premium Request SKUs", budgetAlerting: nil)
            ]
            let response = BudgetResponse(budgets: budgets, hasNextPage: false, totalCount: 1)
            
            let result = GitHubAPIService.findPremiumRequestBudget(in: response)
            test.assertNotNil(result, "Should match partial 'premium' in SKU")
            test.assertEqual(result?.budgetAmount, 25, "Should return the matching budget")
        }
        
        test.run("test_FindPremiumRequestBudget_FallsBackToSingleBudget") {
            let budgets = [
                BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 30, preventFurtherUsage: false,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "unknown_sku", budgetAlerting: nil)
            ]
            let response = BudgetResponse(budgets: budgets, hasNextPage: false, totalCount: 1)
            
            let result = GitHubAPIService.findPremiumRequestBudget(in: response)
            test.assertNotNil(result, "Should fall back to single budget")
            test.assertEqual(result?.budgetAmount, 30, "Should return the only budget")
        }
        
        test.run("test_FindPremiumRequestBudget_ReturnsNilForMultipleNonMatching") {
            let budgets = [
                BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 10, preventFurtherUsage: false,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "actions", budgetAlerting: nil),
                BudgetItem(id: "2", budgetType: "SkuPricing", budgetAmount: 20, preventFurtherUsage: false,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "codespaces", budgetAlerting: nil)
            ]
            let response = BudgetResponse(budgets: budgets, hasNextPage: false, totalCount: 2)
            
            let result = GitHubAPIService.findPremiumRequestBudget(in: response)
            test.assertNil(result, "Should return nil when multiple budgets exist but none match premium")
        }
        
        test.run("test_FindPremiumRequestBudget_ReturnsNilForEmpty") {
            let response = BudgetResponse(budgets: [], hasNextPage: false, totalCount: 0)
            
            let result = GitHubAPIService.findPremiumRequestBudget(in: response)
            test.assertNil(result, "Should return nil for empty budgets")
        }
        
        test.run("test_FindPremiumRequestBudget_CaseInsensitive") {
            let budgets = [
                BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 15, preventFurtherUsage: true,
                          budgetScope: nil, budgetEntityName: nil, budgetProductSku: "PREMIUM_REQUEST", budgetAlerting: nil)
            ]
            let response = BudgetResponse(budgets: budgets, hasNextPage: false, totalCount: 1)
            
            let result = GitHubAPIService.findPremiumRequestBudget(in: response)
            test.assertNotNil(result, "Should match case-insensitively")
        }
        
        // MARK: - BudgetAlerting Tests
        
        test.run("test_BudgetAlerting_Decodes") {
            let json = """
            {
                "will_alert": true,
                "alert_recipients": ["user1@example.com", "user2@example.com"]
            }
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let alerting = try decoder.decode(BudgetAlerting.self, from: data)
                test.assertEqual(alerting.willAlert, true, "willAlert decoded")
                test.assertEqual(alerting.alertRecipients?.count, 2, "alertRecipients decoded")
            } catch {
                test.assertTrue(false, "Should decode: \(error)")
            }
        }
        
        // MARK: - Integration with Usage Data
        
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
        
        test.run("test_BudgetItem_Equality") {
            let item1 = BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 15, preventFurtherUsage: true,
                                   budgetScope: "user", budgetEntityName: "test", budgetProductSku: "premium_request", budgetAlerting: nil)
            let item2 = BudgetItem(id: "1", budgetType: "SkuPricing", budgetAmount: 15, preventFurtherUsage: true,
                                   budgetScope: "user", budgetEntityName: "test", budgetProductSku: "premium_request", budgetAlerting: nil)
            let item3 = BudgetItem(id: "2", budgetType: "SkuPricing", budgetAmount: 20, preventFurtherUsage: false,
                                   budgetScope: "user", budgetEntityName: "test", budgetProductSku: "actions", budgetAlerting: nil)
            
            test.assertTrue(item1 == item2, "Identical items are equal")
            test.assertFalse(item1 == item3, "Different items are not equal")
        }
        
        test.printSummary()
    }
}

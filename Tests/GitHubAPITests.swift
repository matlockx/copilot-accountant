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
    func assertNotNil<T>(_ value: T?, _ message: String = "") {
        if value != nil { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertNotNil" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message.isEmpty ? "assertNotNil" : message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() {
        print("\n=========================================")
        if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) }
        else { print("PASSED: \(passed) tests passed") }
    }
}

// =============================================================================
// F004: GitHub API Tests
// =============================================================================

@main
struct GitHubAPITests {
    static func main() {
        let test = TestCase()
        
        print("=========================================")
        print("F004: GitHub API Tests")
        print("=========================================")
        
        // Test 1: Error types have descriptions
        test.run("test_GitHubAPI_ErrorTypes_HaveDescriptions") {
            let errors: [GitHubAPIService.APIError] = [
                .invalidURL, .noToken, .invalidResponse, .httpError(500, "Server error"),
                .decodingError(NSError(domain: "test", code: 1), "{}"),
                .networkError(NSError(domain: "test", code: 1)),
                .notFound("Not found"), .unauthorized, .forbidden("Forbidden")
            ]
            for error in errors {
                test.assertNotNil(error.errorDescription, "Error should have description")
            }
        }
        
        // Test 2: UsageResponse decoding
        test.run("test_GitHubAPI_UsageResponse_DecodesCorrectly") {
            let json = """
            {"time_period": {"year": 2026, "month": 3, "day": 15}, "user": "testuser", "product": "copilot", "model": null,
             "usage_items": [{"product": "copilot", "sku": "premium", "model": "gpt-4o", "unit_type": "requests",
             "price_per_unit": 0.05, "gross_quantity": 42.0, "gross_amount": 2.1, "discount_quantity": 0.0,
             "discount_amount": 0.0, "net_quantity": 0.0, "net_amount": 0.0}]}
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let usage = try decoder.decode(UsageResponse.self, from: data)
                test.assertEqual(usage.user, "testuser", "User decoded")
                test.assertEqual(usage.timePeriod.year, 2026, "Year decoded")
                test.assertEqual(usage.totalRequests, 42, "Total requests decoded")
            } catch { test.assertTrue(false, "Should decode: \(error)") }
        }
        
        // Test 3: TimePeriod optional fields
        test.run("test_GitHubAPI_TimePeriod_OptionalFields") {
            let json = "{\"year\": 2026}"
            let data = json.data(using: .utf8)!
            do {
                let period = try JSONDecoder().decode(TimePeriod.self, from: data)
                test.assertEqual(period.year, 2026, "Year decoded")
                test.assertTrue(period.month == nil, "Month should be nil")
            } catch { test.assertTrue(false, "Should decode: \(error)") }
        }
        
        // Test 4: HTTP error handling
        test.run("test_GitHubAPI_HttpErrors_CorrectErrorTypes") {
            let error401 = GitHubAPIService.APIError.unauthorized
            test.assertTrue(error401.errorDescription?.contains("Unauthorized") ?? false, "401 unauthorized")
            
            let error403 = GitHubAPIService.APIError.forbidden("Token lacks scope")
            test.assertTrue(error403.errorDescription?.contains("Forbidden") ?? false, "403 forbidden")
            
            let error404 = GitHubAPIService.APIError.notFound("Endpoint not found")
            test.assertTrue(error404.errorDescription?.contains("Not found") ?? false, "404 not found")
        }
        
        // Test 5: Empty usage items
        test.run("test_GitHubAPI_EmptyUsageItems_DecodesCorrectly") {
            let json = "{\"time_period\": {\"year\": 2026, \"month\": 3}, \"user\": \"newuser\", \"usage_items\": []}"
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let usage = try decoder.decode(UsageResponse.self, from: data)
                test.assertEqual(usage.usageItems.count, 0, "Should have 0 items")
                test.assertEqual(usage.totalRequests, 0, "Total should be 0")
            } catch { test.assertTrue(false, "Should decode: \(error)") }
        }
        
        // Test 6: DailyUsage structure
        test.run("test_GitHubAPI_DailyUsage_Structure") {
            let daily = DailyUsage(date: Date(), requests: 25)
            test.assertEqual(daily.requests, 25, "Requests stored")
            test.assertNotNil(daily.id, "Should have ID")
        }
        
        // Test 7: BillingSource descriptions
        test.run("test_GitHubAPI_BillingSource_Descriptions") {
            let personal = GitHubAPIService.BillingSource.personal
            test.assertEqual(personal.description, "Personal", "Personal source description")
            
            let org = GitHubAPIService.BillingSource.organization("my-org")
            test.assertEqual(org.description, "Organization: my-org", "Org source description")
        }
        
        // Test 8: BillingSource equality
        test.run("test_GitHubAPI_BillingSource_Equality") {
            test.assertTrue(GitHubAPIService.BillingSource.personal == .personal, "Personal == Personal")
            test.assertTrue(GitHubAPIService.BillingSource.organization("a") == .organization("a"), "Same org equal")
            test.assertTrue(GitHubAPIService.BillingSource.organization("a") != .organization("b"), "Different orgs not equal")
            test.assertTrue(GitHubAPIService.BillingSource.personal != .organization("a"), "Personal != Org")
        }
        
        // Test 9: BillingSource Codable round-trip
        test.run("test_GitHubAPI_BillingSource_CodableRoundTrip") {
            let sources: [GitHubAPIService.BillingSource] = [.personal, .organization("test-org")]
            for source in sources {
                do {
                    let data = try JSONEncoder().encode(source)
                    let decoded = try JSONDecoder().decode(GitHubAPIService.BillingSource.self, from: data)
                    test.assertTrue(decoded == source, "Round-trip for \(source.description)")
                } catch {
                    test.assertTrue(false, "Codable round-trip failed for \(source.description): \(error)")
                }
            }
        }
        
        // Test 10: shouldFallbackToOrg (fix A) - empty personal response triggers org fallback
        test.run("test_GitHubAPI_ShouldFallbackToOrg_WhenPersonalEmpty") {
            let empty = UsageResponse(timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                                      user: "orguser", product: "copilot", model: nil, usageItems: [])
            test.assertTrue(GitHubAPIService.shouldFallbackToOrg(personalResponse: empty),
                            "Empty personal usage (org-managed) should trigger org fallback")

            let item = UsageItem(product: "copilot", sku: "premium", model: "gpt-4o", unitType: "requests",
                                 pricePerUnit: 0.05, grossQuantity: 10, grossAmount: 0.5,
                                 discountQuantity: 0, discountAmount: 0, netQuantity: 0, netAmount: 0)
            let nonEmpty = UsageResponse(timePeriod: TimePeriod(year: 2026, month: 3, day: nil),
                                         user: "personaluser", product: "copilot", model: nil, usageItems: [item])
            test.assertTrue(!GitHubAPIService.shouldFallbackToOrg(personalResponse: nonEmpty),
                            "Non-empty personal usage should NOT trigger org fallback")
        }

        // Test 11: synthesizeUsage maps Copilot quota into UsageResponse (org-managed seats)
        test.run("test_GitHubAPI_SynthesizeUsage_FromCopilotQuota") {
            let quota = GitHubAPIService.CopilotQuota(
                used: 5218, entitlement: 40000, remaining: 34782,
                percentUsed: 13.1, unlimited: false, resetDate: "2026-08-01", plan: "business"
            )
            let usage = GitHubAPIService.synthesizeUsage(from: quota, username: "martin-joehren-bm", year: 2026, month: 7)
            test.assertEqual(usage.totalRequests, 5218, "totalRequests should equal used premium interactions")
            test.assertEqual(usage.usageItems.count, 1, "should synthesize exactly one usage item")
            test.assertEqual(usage.user, "martin-joehren-bm", "username should be carried through")
            test.assertEqual(usage.usageItems.first?.product, "copilot", "product should be copilot")
        }

        test.printSummary()
    }
}

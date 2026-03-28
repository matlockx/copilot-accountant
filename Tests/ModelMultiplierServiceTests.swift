import Foundation

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        let label = message.isEmpty ? "assertEqual" : message
        if actual == expected { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message) (got \(actual), expected \(expected))") }
    }
    func assertTrue(_ condition: Bool, _ message: String = "") {
        let label = message.isEmpty ? "assertTrue" : message
        if condition { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertFalse(_ condition: Bool, _ message: String = "") { assertTrue(!condition, message) }
    func assertApproximatelyEqual(_ actual: Double, _ expected: Double, tolerance: Double = 0.001, _ message: String = "") {
        let label = message.isEmpty ? "assertApprox" : message
        if abs(actual - expected) <= tolerance { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message) (got \(actual), expected \(expected))") }
    }
    func assertNotNil<T>(_ value: T?, _ message: String = "") {
        let label = message.isEmpty ? "assertNotNil" : message
        if value != nil { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertNil<T>(_ value: T?, _ message: String = "") {
        let label = message.isEmpty ? "assertNil" : message
        if value == nil { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct ModelMultiplierServiceTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F016: Model Multiplier Service Tests")
        print("=========================================")

        // MARK: - Configuration Tests

        test.run("test_Configuration_HasExpectedDefaults") {
            test.assertTrue(ModelMultiplierConfiguration.defaultMultipliersURL.contains("github.com"), "URL points to GitHub docs")
            test.assertEqual(ModelMultiplierConfiguration.minimumExpectedModels, 5, "Minimum expected models is 5")
            test.assertTrue(ModelMultiplierConfiguration.maxCacheAgeSeconds > 0, "Cache age is positive")
            test.assertFalse(ModelMultiplierConfiguration.cacheKey.isEmpty, "Cache key is not empty")
            test.assertFalse(ModelMultiplierConfiguration.cacheTimestampKey.isEmpty, "Timestamp key is not empty")
            test.assertFalse(ModelMultiplierConfiguration.urlKey.isEmpty, "URL key is not empty")
        }

        // MARK: - Parse Multiplier Value Tests

        test.run("test_ParseMultiplierValue_ValidNumbers") {
            let service = ModelMultiplierService()
            test.assertApproximatelyEqual(service.parseMultiplierValue("3") ?? -1, 3.0, tolerance: 0.001, "Parses integer '3'")
            test.assertApproximatelyEqual(service.parseMultiplierValue("0.33") ?? -1, 0.33, tolerance: 0.001, "Parses decimal '0.33'")
            test.assertApproximatelyEqual(service.parseMultiplierValue("0") ?? -1, 0.0, tolerance: 0.001, "Parses zero '0'")
            test.assertApproximatelyEqual(service.parseMultiplierValue("1") ?? -1, 1.0, tolerance: 0.001, "Parses '1'")
            test.assertApproximatelyEqual(service.parseMultiplierValue("30") ?? -1, 30.0, tolerance: 0.001, "Parses '30'")
            test.assertApproximatelyEqual(service.parseMultiplierValue("0.25") ?? -1, 0.25, tolerance: 0.001, "Parses '0.25'")
        }

        test.run("test_ParseMultiplierValue_InvalidValues") {
            let service = ModelMultiplierService()
            test.assertNil(service.parseMultiplierValue("Not applicable"), "Not applicable returns nil")
            test.assertNil(service.parseMultiplierValue("N/A"), "N/A returns nil")
            test.assertNil(service.parseMultiplierValue(""), "Empty string returns nil")
            test.assertNil(service.parseMultiplierValue("  "), "Whitespace returns nil")
        }

        // MARK: - HTML Table Parsing Tests

        test.run("test_ParseMultipliers_HTMLTable_ValidTable") {
            let service = ModelMultiplierService()
            let html = """
            <html><body>
            <table><thead><tr>
            <th scope="col">Model</th>
            <th scope="col">Multiplier for <strong>paid plans</strong></th>
            <th scope="col">Multiplier for <strong>Copilot Free</strong></th>
            </tr></thead><tbody>
            <tr><th scope="row">Claude Haiku 4.5</th><td>0.33</td><td>1</td></tr>
            <tr><th scope="row">Claude Opus 4.5</th><td>3</td><td>Not applicable</td></tr>
            <tr><th scope="row">Claude Sonnet 4</th><td>1</td><td>Not applicable</td></tr>
            <tr><th scope="row">GPT-4o</th><td>0</td><td>1</td></tr>
            <tr><th scope="row">GPT-5 mini</th><td>0</td><td>1</td></tr>
            <tr><th scope="row">GPT-5.4</th><td>1</td><td>Not applicable</td></tr>
            <tr><th scope="row">Gemini 2.5 Pro</th><td>1</td><td>Not applicable</td></tr>
            </tbody></table>
            </body></html>
            """

            let result = service.parseMultipliers(html: html)
            test.assertTrue(result.count >= 7, "Parsed at least 7 models from HTML (got \(result.count))")
            test.assertApproximatelyEqual(result["Claude Haiku 4.5"] ?? -1, 0.33, tolerance: 0.001, "Haiku = 0.33")
            test.assertApproximatelyEqual(result["Claude Opus 4.5"] ?? -1, 3.0, tolerance: 0.001, "Opus = 3")
            test.assertApproximatelyEqual(result["Claude Sonnet 4"] ?? -1, 1.0, tolerance: 0.001, "Sonnet = 1")
            test.assertApproximatelyEqual(result["GPT-4o"] ?? -1, 0.0, tolerance: 0.001, "GPT-4o = 0 (included)")
            test.assertApproximatelyEqual(result["GPT-5 mini"] ?? -1, 0.0, tolerance: 0.001, "GPT-5 mini = 0 (included)")
            test.assertApproximatelyEqual(result["GPT-5.4"] ?? -1, 1.0, tolerance: 0.001, "GPT-5.4 = 1")
        }

        test.run("test_ParseMultipliers_HTMLTable_SingleLine") {
            let service = ModelMultiplierService()
            // GitHub docs serve the table as a single line
            let html = "<table><thead><tr><th scope=\"col\">Model</th><th scope=\"col\">Multiplier for <strong>paid plans</strong></th><th scope=\"col\">Multiplier for <strong>Copilot Free</strong></th></tr></thead><tbody><tr><th scope=\"row\">Claude Opus 4.6</th><td>3</td><td>Not applicable</td></tr><tr><th scope=\"row\">GPT-4.1</th><td>0</td><td>1</td></tr><tr><th scope=\"row\">Grok Code Fast 1</th><td>0.25</td><td>1</td></tr><tr><th scope=\"row\">Claude Opus 4.6 (fast mode) (preview)</th><td>30</td><td>Not applicable</td></tr><tr><th scope=\"row\">Gemini 3 Flash</th><td>0.33</td><td>Not applicable</td></tr></tbody></table>"

            let result = service.parseMultipliers(html: html)
            test.assertTrue(result.count >= 5, "Parsed at least 5 models from single-line HTML (got \(result.count))")
            test.assertApproximatelyEqual(result["Claude Opus 4.6"] ?? -1, 3.0, tolerance: 0.001, "Opus 4.6 = 3")
            test.assertApproximatelyEqual(result["GPT-4.1"] ?? -1, 0.0, tolerance: 0.001, "GPT-4.1 = 0")
            test.assertApproximatelyEqual(result["Grok Code Fast 1"] ?? -1, 0.25, tolerance: 0.001, "Grok = 0.25")
            test.assertApproximatelyEqual(result["Claude Opus 4.6 (fast mode) (preview)"] ?? -1, 30.0, tolerance: 0.001, "Fast mode = 30")
            test.assertApproximatelyEqual(result["Gemini 3 Flash"] ?? -1, 0.33, tolerance: 0.001, "Gemini Flash = 0.33")
        }

        test.run("test_ParseMultipliers_HTMLTable_SkipsNotApplicable") {
            let service = ModelMultiplierService()
            let html = """
            <table><thead><tr>
            <th scope="col">Model</th>
            <th scope="col">Multiplier for <strong>paid plans</strong></th>
            <th scope="col">Multiplier for <strong>Copilot Free</strong></th>
            </tr></thead><tbody>
            <tr><th scope="row">Goldeneye</th><td>Not applicable</td><td>1</td></tr>
            <tr><th scope="row">Claude Opus 4.5</th><td>3</td><td>Not applicable</td></tr>
            </tbody></table>
            """

            let result = service.parseMultipliers(html: html)
            test.assertNil(result["Goldeneye"], "Goldeneye excluded (Not applicable for paid plans)")
            test.assertApproximatelyEqual(result["Claude Opus 4.5"] ?? -1, 3.0, tolerance: 0.001, "Opus still parsed")
        }

        test.run("test_ParseMultipliers_HTMLTable_IgnoresWrongTable") {
            let service = ModelMultiplierService()
            let html = """
            <table><thead><tr>
            <th>Feature</th><th>Description</th>
            </tr></thead><tbody>
            <tr><td>Chat</td><td>Talk to Copilot</td></tr>
            </tbody></table>
            """
            let result = service.parseMultipliers(html: html)
            test.assertEqual(result.count, 0, "Wrong table structure yields no models")
        }

        // MARK: - Markdown Table Fallback Tests

        test.run("test_ParseMultipliers_MarkdownFallback_ValidTable") {
            let service = ModelMultiplierService()
            let html = """
            # Model multipliers

            | Model | Multiplier for **paid plans** | Multiplier for **Copilot Free** |
            | --- | --- | --- |
            | Claude Haiku 4.5 | 0.33 | 1 |
            | Claude Opus 4.5 | 3 | Not applicable |
            | Claude Sonnet 4 | 1 | Not applicable |
            | GPT-4o | 0 | 1 |
            | GPT-5 mini | 0 | 1 |
            | GPT-5.4 | 1 | Not applicable |
            | Gemini 2.5 Pro | 1 | Not applicable |
            """

            let result = service.parseMultipliers(html: html)
            test.assertTrue(result.count >= 7, "Parsed at least 7 models from markdown (got \(result.count))")
            test.assertApproximatelyEqual(result["Claude Haiku 4.5"] ?? -1, 0.33, tolerance: 0.001, "Haiku = 0.33")
            test.assertApproximatelyEqual(result["Claude Opus 4.5"] ?? -1, 3.0, tolerance: 0.001, "Opus = 3")
        }

        test.run("test_ParseMultipliers_MarkdownFallback_SkipsNotApplicable") {
            let service = ModelMultiplierService()
            let html = """
            | Model | Multiplier for **paid plans** | Multiplier for **Copilot Free** |
            | --- | --- | --- |
            | Goldeneye | Not applicable | 1 |
            | Claude Opus 4.5 | 3 | Not applicable |
            """

            let result = service.parseMultipliers(html: html)
            test.assertNil(result["Goldeneye"], "Goldeneye excluded (Not applicable for paid plans)")
            test.assertApproximatelyEqual(result["Claude Opus 4.5"] ?? -1, 3.0, tolerance: 0.001, "Opus still parsed")
        }

        test.run("test_ParseMultipliers_EmptyHTML") {
            let service = ModelMultiplierService()
            let result = service.parseMultipliers(html: "")
            test.assertEqual(result.count, 0, "Empty HTML yields no models")
        }

        test.run("test_ParseMultipliers_NoTable") {
            let service = ModelMultiplierService()
            let result = service.parseMultipliers(html: "# Some page\nNo table here at all.\nJust text.")
            test.assertEqual(result.count, 0, "No table yields no models")
        }

        // MARK: - URL Configuration Tests

        test.run("test_MultipliersURL_DefaultValue") {
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.urlKey)
            let service = ModelMultiplierService()
            test.assertEqual(service.multipliersURL, ModelMultiplierConfiguration.defaultMultipliersURL, "Default URL is set")
        }

        test.run("test_MultipliersURL_CustomValue") {
            let service = ModelMultiplierService()
            let customURL = "https://example.com/custom-multipliers"
            service.multipliersURL = customURL
            test.assertEqual(service.multipliersURL, customURL, "Custom URL is persisted")

            // Clean up
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.urlKey)
        }

        // MARK: - Cache Tests

        test.run("test_Cache_SaveAndLoad") {
            let service = ModelMultiplierService()
            let testMultipliers: [String: Double] = ["TestModel": 2.5, "TestModel2": 0.5]
            
            // Save
            service.saveToCache(testMultipliers)
            
            // Load
            let loaded = service.loadCachedMultipliers()
            test.assertNotNil(loaded, "Cached multipliers loaded")
            test.assertApproximatelyEqual(loaded?["TestModel"] ?? 0, 2.5, tolerance: 0.001, "TestModel cached correctly")
            test.assertApproximatelyEqual(loaded?["TestModel2"] ?? 0, 0.5, tolerance: 0.001, "TestModel2 cached correctly")
            
            // Timestamp set
            test.assertNotNil(service.lastUpdateTime, "Last update time is set after save")
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheKey)
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
        }

        test.run("test_Cache_NilWhenEmpty") {
            // Ensure clean state
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheKey)
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
            
            let service = ModelMultiplierService()
            test.assertNil(service.loadCachedMultipliers(), "No cache returns nil")
            test.assertNil(service.lastUpdateTime, "No timestamp returns nil")
            test.assertTrue(service.isCacheStale, "Empty cache is stale")
        }

        test.run("test_EffectiveMultipliers_FallsBackToHardcoded") {
            // Ensure clean state
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheKey)
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
            
            let service = ModelMultiplierService()
            let effective = service.effectiveMultipliers()
            
            // Should return hardcoded values when no cache
            test.assertTrue(effective.count > 0, "Effective multipliers not empty")
            test.assertApproximatelyEqual(effective["Claude Opus 4.5"] ?? -1, 3.0, tolerance: 0.001, "Hardcoded Opus fallback works")
        }

        test.run("test_EffectiveMultipliers_PrefersCachedValues") {
            let service = ModelMultiplierService()
            let cached: [String: Double] = ["Claude Opus 4.5": 5.0, "NewModel": 2.0]
            service.saveToCache(cached)
            
            let effective = service.effectiveMultipliers()
            test.assertApproximatelyEqual(effective["Claude Opus 4.5"] ?? -1, 5.0, tolerance: 0.001, "Cached value overrides hardcoded")
            test.assertApproximatelyEqual(effective["NewModel"] ?? -1, 2.0, tolerance: 0.001, "New cached model available")
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheKey)
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
        }

        // MARK: - Last Update Description Tests

        test.run("test_LastUpdateDescription_NeverWhenNoCache") {
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
            let service = ModelMultiplierService()
            test.assertEqual(service.lastUpdateDescription, "Never", "No cache shows 'Never'")
        }

        test.run("test_LastUpdateDescription_JustNowWhenRecent") {
            let service = ModelMultiplierService()
            // Set timestamp to now
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: ModelMultiplierConfiguration.cacheTimestampKey)
            test.assertEqual(service.lastUpdateDescription, "Just now", "Recent update shows 'Just now'")
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
        }

        // MARK: - Catalog Builder Tests

        test.run("test_BuildCatalog_MergesUsedAndKnownModels") {
            let known: [String: Double] = [
                "Claude Opus 4.5": 3.0,
                "Claude Sonnet 4": 1.0,
                "GPT-4o": 0.0,
                "GPT-5.4": 1.0
            ]
            let usage: [String: Double] = [
                "Claude Opus 4.5": 50.0,
                "Claude Sonnet 4": 30.0
            ]
            
            let catalog = ModelMultiplierService.buildCatalog(knownMultipliers: known, usageByModel: usage)
            
            // Should have all 4 models
            test.assertEqual(catalog.count, 4, "Catalog has 4 entries (2 used + 2 unused)")
            
            // Used models first
            test.assertEqual(catalog[0].name, "Claude Opus 4.5", "Highest usage model first")
            test.assertEqual(catalog[1].name, "Claude Sonnet 4", "Second highest usage model second")
        }

        test.run("test_BuildCatalog_StatusAssignment") {
            let known: [String: Double] = [
                "Claude Opus 4.5": 3.0,
                "GPT-4o": 0.0,
                "GPT-5.4": 1.0
            ]
            let usage: [String: Double] = [
                "Claude Opus 4.5": 50.0,
                "GPT-4o": 10.0
            ]
            
            let catalog = ModelMultiplierService.buildCatalog(knownMultipliers: known, usageByModel: usage)
            
            let opus = catalog.first { $0.name == "Claude Opus 4.5" }!
            let gpt4o = catalog.first { $0.name == "GPT-4o" }!
            let gpt54 = catalog.first { $0.name == "GPT-5.4" }!
            
            test.assertEqual(opus.status, .used, "Opus is used")
            test.assertEqual(gpt4o.status, .free, "GPT-4o is free (multiplier=0, even if used)")
            test.assertEqual(gpt54.status, .available, "GPT-5.4 is available (not used)")
        }

        test.run("test_BuildCatalog_SortOrder_UsedFirst_ThenFree_ThenAvailable") {
            let known: [String: Double] = [
                "AvailableModel": 1.0,
                "FreeModel": 0.0,
                "UsedModel": 1.0
            ]
            let usage: [String: Double] = [
                "UsedModel": 20.0
            ]
            
            let catalog = ModelMultiplierService.buildCatalog(knownMultipliers: known, usageByModel: usage)
            
            test.assertEqual(catalog[0].name, "UsedModel", "Used model first")
            test.assertEqual(catalog[1].name, "FreeModel", "Free model before available")
            test.assertEqual(catalog[2].name, "AvailableModel", "Available model last")
        }

        test.run("test_BuildCatalog_UnknownUsedModels_DefaultMultiplier") {
            let known: [String: Double] = [:]
            let usage: [String: Double] = [
                "some-unknown-model": 15.0
            ]
            
            let catalog = ModelMultiplierService.buildCatalog(knownMultipliers: known, usageByModel: usage)
            test.assertEqual(catalog.count, 1, "Unknown used model included")
            test.assertApproximatelyEqual(catalog[0].multiplier, 1.0, tolerance: 0.001, "Unknown model defaults to 1x")
            test.assertEqual(catalog[0].status, .used, "Unknown used model is marked as used")
        }

        test.run("test_BuildCatalog_EmptyUsage") {
            let known: [String: Double] = [
                "Claude Opus 4.5": 3.0,
                "GPT-4o": 0.0
            ]
            let usage: [String: Double] = [:]
            
            let catalog = ModelMultiplierService.buildCatalog(knownMultipliers: known, usageByModel: usage)
            test.assertEqual(catalog.count, 2, "All known models shown even with no usage")
            test.assertTrue(catalog.allSatisfy { $0.usage == 0 }, "All entries have 0 usage")
        }

        // MARK: - Error Type Tests

        test.run("test_FetchError_HasDescriptions") {
            let errors: [ModelMultiplierService.MultiplierFetchError] = [
                .invalidURL,
                .httpError(404),
                .invalidData,
                .insufficientData(2)
            ]
            for error in errors {
                test.assertNotNil(error.errorDescription, "Error \(error) has description")
            }
        }

        // MARK: - Chart Tooltip Configuration Tests

        test.run("test_ChartTooltipConfiguration_Defaults") {
            test.assertTrue(ChartTooltipConfiguration.cornerRadius > 0, "Tooltip has positive corner radius")
            test.assertTrue(ChartTooltipConfiguration.shadowRadius > 0, "Tooltip has positive shadow radius")
            test.assertTrue(ChartTooltipConfiguration.padding > 0, "Tooltip has positive padding")
            test.assertTrue(ChartTooltipConfiguration.highlightOpacity > 0, "Highlighted bar opacity is positive")
            test.assertTrue(ChartTooltipConfiguration.highlightOpacity <= 1.0, "Highlighted bar opacity <= 1")
            test.assertTrue(ChartTooltipConfiguration.dimmedOpacity > 0, "Dimmed bar opacity is positive")
            test.assertTrue(ChartTooltipConfiguration.dimmedOpacity < ChartTooltipConfiguration.highlightOpacity, "Dimmed is less than highlighted")
        }

        test.run("test_EmptyStateMessages_AreNotEmpty") {
            test.assertFalse(DetailedStatsEmptyState.noUsage.isEmpty, "No usage message not empty")
            test.assertFalse(DetailedStatsEmptyState.noDailyData.isEmpty, "No daily data message not empty")
            test.assertFalse(DetailedStatsEmptyState.noModels.isEmpty, "No models message not empty")
        }

        test.printSummary()
    }
}

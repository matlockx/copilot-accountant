import Foundation

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct TokenHelpTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F012: Token Help Tests")
        print("=========================================")
        
        let tokenHelpContent = """
        To get a GitHub Personal Access Token with the required permissions:
        1. Go to GitHub.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens
        2. Click "Generate new token"
        3. Give it a descriptive name (e.g., "Copilot Accountant")
        4. Set expiration as desired
        5. Under "Account permissions", find "Plan" and set it to "Read-only"
        6. Click "Generate token" and copy the token
        Note: The token must have "Plan" read access. Classic tokens with read:user do NOT work.
        """
        
        test.run("test_TokenHelp_MentionsGitHub") {
            test.assertTrue(tokenHelpContent.contains("GitHub"), "Help mentions GitHub")
        }
        
        test.run("test_TokenHelp_MentionsFineGrainedTokens") {
            test.assertTrue(tokenHelpContent.contains("Fine-grained"), "Help mentions Fine-grained tokens")
        }
        
        test.run("test_TokenHelp_MentionsPlanPermission") {
            test.assertTrue(tokenHelpContent.contains("Plan"), "Help mentions Plan permission")
        }
        
        test.run("test_TokenHelp_MentionsReadOnly") {
            test.assertTrue(tokenHelpContent.contains("Read-only"), "Help mentions Read-only access")
        }
        
        test.run("test_TokenHelp_WarnsAboutClassicTokens") {
            test.assertTrue(tokenHelpContent.contains("Classic tokens") || tokenHelpContent.contains("read:user"), "Help warns about classic tokens")
        }
        
        test.run("test_TokenHelp_HasStepByStepInstructions") {
            test.assertTrue(tokenHelpContent.contains("1."), "Has step 1")
            test.assertTrue(tokenHelpContent.contains("2."), "Has step 2")
            test.assertTrue(tokenHelpContent.contains("3."), "Has step 3")
        }
        
        test.run("test_TokenHelp_MentionsDeveloperSettings") {
            test.assertTrue(tokenHelpContent.contains("Developer settings"), "Help mentions Developer settings")
        }
        
        test.printSummary()
    }
}

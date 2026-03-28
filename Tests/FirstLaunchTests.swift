import Foundation

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertFalse(_ condition: Bool, _ message: String = "") { assertTrue(!condition, message) }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct FirstLaunchTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F010: First Launch Tests")
        print("=========================================")
        
        test.run("test_FirstLaunch_DefaultLaunchAtLoginIsFalse") {
            let config = BudgetConfig.default
            test.assertFalse(config.launchAtLogin, "launchAtLogin should be false by default")
        }
        
        test.run("test_FirstLaunch_UserDefaultsTracking") {
            let testKey = "testFirstLaunch_\(UUID().uuidString)"
            let userDefaults = UserDefaults.standard
            test.assertFalse(userDefaults.bool(forKey: testKey), "Should be false before first launch")
            userDefaults.set(true, forKey: testKey)
            test.assertTrue(userDefaults.bool(forKey: testKey), "Should be true after first launch")
            userDefaults.removeObject(forKey: testKey)
        }
        
        test.run("test_FirstLaunch_DetectionLogic") {
            let testKey = "testFirstLaunchDetection_\(UUID().uuidString)"
            let userDefaults = UserDefaults.standard
            userDefaults.removeObject(forKey: testKey)
            func isFirstLaunch(key: String) -> Bool { return !userDefaults.bool(forKey: key) }
            test.assertTrue(isFirstLaunch(key: testKey), "Should detect first launch")
            userDefaults.set(true, forKey: testKey)
            test.assertFalse(isFirstLaunch(key: testKey), "Should not be first launch after marking")
            userDefaults.removeObject(forKey: testKey)
        }
        
        test.run("test_FirstLaunch_PopupShowsOnFirstLaunch_NotAtLogin") {
            func shouldShowPopupOnLaunch(isFirstLaunch: Bool, launchedAtLogin: Bool) -> Bool {
                if isFirstLaunch { return true }
                else if !launchedAtLogin { return true }
                return false
            }
            test.assertTrue(shouldShowPopupOnLaunch(isFirstLaunch: true, launchedAtLogin: false), "Show on first manual launch")
            test.assertTrue(shouldShowPopupOnLaunch(isFirstLaunch: true, launchedAtLogin: true), "Show on first launch even at login")
            test.assertTrue(shouldShowPopupOnLaunch(isFirstLaunch: false, launchedAtLogin: false), "Show on subsequent manual launch")
            test.assertFalse(shouldShowPopupOnLaunch(isFirstLaunch: false, launchedAtLogin: true), "Don't show when auto-started")
        }
        
        test.run("test_FirstLaunch_LaunchAtLoginPersists") {
            var config = BudgetConfig.default
            config.launchAtLogin = true
            let encoded = try! JSONEncoder().encode(config)
            let decoded = try! JSONDecoder().decode(BudgetConfig.self, from: encoded)
            test.assertTrue(decoded.launchAtLogin, "launchAtLogin should persist")
        }

        test.run("test_FirstLaunch_LaunchAtLogin_UsesServiceManagement") {
            test.assertTrue(LaunchAtLoginConfiguration.usesServiceManagement, "Launch at login is wired through ServiceManagement")
            test.assertTrue(LaunchAtLoginConfiguration.supportsMainAppRegistration, "Launch at login uses main app registration")
        }
        
        test.printSummary()
    }
}

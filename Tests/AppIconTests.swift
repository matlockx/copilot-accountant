import Foundation

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        let label = message.isEmpty ? "assertEqual" : message
        if actual == expected { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertTrue(_ condition: Bool, _ message: String = "") {
        let label = message.isEmpty ? "assertTrue" : message
        if condition { passed += 1; print("  ✓ PASSED: \(label)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct AppIconTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F014: App Icon Tests")
        print("=========================================")

        test.run("test_AppIcon_InfoPlist_UsesAppIconFile") {
            let iconConfig = AppIconConfiguration.iconFileName
            test.assertEqual(iconConfig, "AppIcon", "Info.plist should use AppIcon without extension")
        }

        test.run("test_AppIcon_BundleResource_IsIcnsFile") {
            test.assertEqual(AppIconConfiguration.resourceFileName, "AppIcon.icns", "Bundle resource should be AppIcon.icns")
        }

        test.run("test_AppIcon_ResourcePath_ResidesInResourcesDirectory") {
            test.assertTrue(AppIconConfiguration.sourcePath.hasPrefix("Resources/"), "Source icon should live in Resources/")
            test.assertTrue(AppIconConfiguration.sourcePath.hasSuffix("AppIcon.icns"), "Source icon path should point to AppIcon.icns")
        }

        test.printSummary()
    }
}

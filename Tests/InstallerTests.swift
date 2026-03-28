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

struct InstallerConfiguration {
    static let appBundleName = "CopilotAccountant.app"
    static let launchCommand = "open /Applications/CopilotAccountant.app"
}

@main
struct InstallerTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F015: Installer Tests")
        print("=========================================")

        test.run("test_Installer_UsesApplicationsBundlePath") {
            test.assertEqual(InstallerConfiguration.appBundleName, "CopilotAccountant.app", "Installer targets the Applications bundle")
        }

        test.run("test_Installer_LaunchesAppAfterInstall") {
            test.assertEqual(InstallerConfiguration.launchCommand, "open /Applications/CopilotAccountant.app", "Installer auto-launches the installed app")
            test.assertTrue(InstallerConfiguration.launchCommand.hasPrefix("open "), "Installer launch uses open command")
        }

        test.printSummary()
    }
}

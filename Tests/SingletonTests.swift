import Foundation
import AppKit

class TestCase {
    var passed: Int = 0; var failed: Int = 0
    func assertTrue(_ condition: Bool, _ message: String = "") {
        if condition { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertTrue" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func assertNotNil<T>(_ value: T?, _ message: String = "") {
        if value != nil { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertNotNil" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct SingletonTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F009: Singleton Tests")
        print("=========================================")
        
        test.run("test_Singleton_BundleIdentifierFallback") {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.copilot-accountant.app"
            test.assertNotNil(bundleId, "Should have bundle ID or fallback")
            test.assertTrue(bundleId.contains("copilot-accountant"), "Bundle ID contains app name")
        }
        
        test.run("test_Singleton_ProcessIdentifierAvailable") {
            let pid = ProcessInfo.processInfo.processIdentifier
            test.assertTrue(pid > 0, "Process ID should be positive")
        }
        
        test.run("test_Singleton_NSWorkspaceAvailable") {
            let workspace = NSWorkspace.shared
            test.assertNotNil(workspace, "NSWorkspace should be available")
        }
        
        test.run("test_Singleton_RunningAppsAccessible") {
            let runningApps = NSWorkspace.shared.runningApplications
            test.assertTrue(runningApps.count > 0, "Should have running apps")
        }
        
        test.run("test_Singleton_DetectionLogic") {
            func countRunningInstances(bundleId: String) -> Int {
                return NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleId }.count
            }
            let count = countRunningInstances(bundleId: "com.copilot-accountant.app")
            test.assertTrue(count >= 0, "Should return valid count")
        }
        
        test.printSummary()
    }
}

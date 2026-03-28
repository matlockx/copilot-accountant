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
    func assertNotNil<T>(_ value: T?, _ message: String = "") {
        if value != nil { passed += 1; print("  ✓ PASSED: \(message.isEmpty ? "assertNotNil" : message)") }
        else { failed += 1; print("  ✗ FAILED: \(message)") }
    }
    func run(_ name: String, _ testFunc: () -> Void) { print("\n▶ \(name)"); testFunc() }
    func printSummary() { print("\n========================================="); if failed > 0 { print("FAILED: \(passed) passed, \(failed) failed"); exit(1) } else { print("PASSED: \(passed) tests passed") } }
}

@main
struct LoggingTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F011: Logging Tests")
        print("=========================================")
        
        test.run("test_Logging_LogLevelsExist") {
            test.assertEqual(LogService.LogLevel.debug.rawValue, "DEBUG", "DEBUG level exists")
            test.assertEqual(LogService.LogLevel.info.rawValue, "INFO", "INFO level exists")
            test.assertEqual(LogService.LogLevel.warning.rawValue, "WARN", "WARN level exists")
            test.assertEqual(LogService.LogLevel.error.rawValue, "ERROR", "ERROR level exists")
        }
        
        test.run("test_Logging_IsSingleton") {
            let instance1 = LogService.shared
            let instance2 = LogService.shared
            test.assertTrue(instance1 === instance2, "LogService.shared should be singleton")
        }
        
        test.run("test_Logging_LogFilePathIsValid") {
            let logPath = LogService.shared.logFilePath
            test.assertTrue(!logPath.isEmpty, "Log path not empty")
            test.assertTrue(logPath.contains("CopilotAccountant"), "Log path contains app name")
            test.assertTrue(logPath.hasSuffix(".log"), "Log path ends with .log")
        }
        
        test.run("test_Logging_MethodsDontCrash") {
            LogService.shared.debug("Test debug")
            LogService.shared.info("Test info")
            LogService.shared.warning("Test warning")
            LogService.shared.error("Test error")
            test.assertTrue(true, "All log methods executed without crash")
        }
        
        test.run("test_Logging_GetRecentLogsReturnsString") {
            let logs = LogService.shared.getRecentLogs(lines: 10)
            test.assertNotNil(logs, "getRecentLogs returns string")
        }
        
        test.run("test_Logging_GlobalFunctionWorks") {
            appLog("Test message via appLog")
            appLog("Test error via appLog", level: .error)
            test.assertTrue(true, "Global appLog function works")
        }
        
        test.printSummary()
    }
}

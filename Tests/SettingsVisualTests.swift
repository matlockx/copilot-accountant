import Foundation

class TestCase {
    var passed: Int = 0
    var failed: Int = 0

    func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") {
        let label = message.isEmpty ? "assertEqual" : message
        if actual == expected {
            passed += 1
            print("  ✓ PASSED: \(label)")
        } else {
            failed += 1
            print("  ✗ FAILED: \(message)")
        }
    }

    func assertTrue(_ condition: Bool, _ message: String = "") {
        let label = message.isEmpty ? "assertTrue" : message
        if condition {
            passed += 1
            print("  ✓ PASSED: \(label)")
        } else {
            failed += 1
            print("  ✗ FAILED: \(message)")
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

@main
struct SettingsVisualTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F008: Settings Visual Tests")
        print("=========================================")

        test.run("test_SettingsVisual_TokenField_UsesDedicatedVisualWidth") {
            test.assertEqual(SettingsViewConfiguration.tokenFieldWidth, 236, "Token field width is large enough for visible editing")
            test.assertTrue(SettingsViewConfiguration.tokenFieldWidth > SettingsViewConfiguration.valueFieldWidth, "Token field is wider than numeric fields")
        }

        test.run("test_SettingsVisual_CheckboxesAndActions_UseSeparateColumns") {
            test.assertEqual(SettingsViewConfiguration.checkboxColumnWidth, 32, "Checkbox column has fixed width")
            test.assertEqual(SettingsViewConfiguration.actionColumnWidth, 120, "Action column has fixed width")
            test.assertEqual(SettingsViewConfiguration.notificationControlWidth, 316, "Notification row width accounts for value, checkbox, and action columns")
            test.assertEqual(SettingsViewConfiguration.formOuterPadding, 24, "Settings uses balanced outer padding")
        }

        test.run("test_SettingsVisual_Footer_UsesClickableInsetBar") {
            test.assertEqual(SettingsViewConfiguration.footerPresentation, .safeAreaInsetBar, "Footer uses a dedicated inset bar for clickability")
            test.assertEqual(SettingsViewConfiguration.footerButtonWidth, 120, "Footer buttons keep stable width")
        }

        test.printSummary()
    }
}

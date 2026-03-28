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
struct SettingsLayoutTests {
    static func main() {
        let test = TestCase()
        print("=========================================")
        print("F008: Settings Layout Tests")
        print("=========================================")

        test.run("test_SettingsLayout_UsesTwoColumnGridContract") {
            test.assertEqual(SettingsViewConfiguration.layoutStyle, .twoColumnGrid, "Settings use a two-column grid layout")
            test.assertEqual(SettingsViewConfiguration.controlColumnAlignment, .trailing, "Controls align to the trailing edge")
            test.assertEqual(SettingsViewConfiguration.surfaceStyle, .flatCards, "Settings use modern flat cards")
            test.assertEqual(SettingsViewConfiguration.colorStyle, .neutralGray, "Settings use a neutral gray palette")
        }

        test.run("test_SettingsLayout_UsesSharedButtonAndFieldWidths") {
            test.assertEqual(SettingsViewConfiguration.utilityButtonWidth, 100, "Utility buttons use a shared width")
            test.assertEqual(SettingsViewConfiguration.valueFieldWidth, 80, "Value fields use a shared width")
            test.assertEqual(SettingsViewConfiguration.toggleColumnWidth, 32, "Toggle column uses a stable width")
            test.assertEqual(SettingsViewConfiguration.notificationControlWidth, 300, "Notification controls reserve a stable right column")
            test.assertEqual(SettingsViewConfiguration.footerButtonWidth, 100, "Footer buttons share a common width")
        }

        test.run("test_SettingsLayout_CustomAlertsSupportCheckboxes") {
            test.assertEqual(NotificationSettingsConfiguration.customAlertFieldTitle, "Custom alerts", "Custom alert section label is stable")
            test.assertEqual(NotificationSettingsConfiguration.customAlertToggleTitle, "Enabled", "Custom alerts include an enabled checkbox")
            test.assertEqual(SettingsViewConfiguration.customAlertLayout, .valueCheckboxRemove, "Custom alerts place value before checkbox and remove action")
            test.assertEqual(SettingsViewConfiguration.checkboxColumnAlignment, .sharedVerticalColumn, "Checkboxes align in one vertical column")
            test.assertEqual(SettingsViewConfiguration.formOuterPadding, 24, "Settings cards keep consistent horizontal padding")
        }

        test.run("test_SettingsLayout_TokenRevealTargetsSavedToken") {
            test.assertEqual(SettingsViewConfiguration.tokenRevealBehavior, .savedTokenOnly, "Eye control reveals the saved token value")
            test.assertEqual(SettingsViewConfiguration.hiddenTokenMask, "••••••••••••", "Saved token uses a stable hidden mask")
        }

        test.printSummary()
    }
}

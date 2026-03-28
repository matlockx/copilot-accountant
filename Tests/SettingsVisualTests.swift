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
            test.assertEqual(SettingsViewConfiguration.actionColumnWidth, 100, "Action column has fixed width")
            test.assertEqual(SettingsViewConfiguration.notificationControlWidth, 300, "Notification row width accounts for value, checkbox, and action columns")
            test.assertEqual(SettingsViewConfiguration.formOuterPadding, 24, "Settings uses balanced outer padding")
        }

        test.run("test_SettingsVisual_Footer_UsesClickableInsetBar") {
            test.assertEqual(SettingsViewConfiguration.footerPresentation, .safeAreaInsetBar, "Footer uses a dedicated inset bar for clickability")
            test.assertEqual(SettingsViewConfiguration.footerButtonWidth, 100, "Footer buttons keep stable width")
        }

        test.run("test_SettingsVisual_ContentFitsWithinWindowBounds") {
            // Window width minus horizontal padding on both sides = available content width
            let windowWidth = SettingsViewConfiguration.windowSize.width
            let horizontalPadding = SettingsViewConfiguration.formOuterPadding * 2
            let availableContentWidth = windowWidth - horizontalPadding
            
            // The card has internal padding of 20 on each side
            let cardInternalPadding: CGFloat = 20 * 2
            let availableGridWidth = availableContentWidth - cardInternalPadding
            
            // Grid must fit: label column + spacing + control column
            let labelWidth = SettingsViewConfiguration.formLabelWidth
            let spacing = SettingsViewConfiguration.formFieldSpacing
            let controlWidth = SettingsViewConfiguration.notificationControlWidth
            let requiredGridWidth = labelWidth + spacing + controlWidth
            
            test.assertTrue(availableContentWidth > 0, "Available content width is positive: \(availableContentWidth)")
            test.assertTrue(availableGridWidth >= requiredGridWidth, 
                "Grid fits within card: available=\(availableGridWidth), required=\(requiredGridWidth)")
            
            // Verify token row fits: tokenFieldWidth + spacing + eye button (~24)
            let eyeButtonWidth: CGFloat = 24
            let tokenRowWidth = SettingsViewConfiguration.tokenFieldWidth + spacing + eyeButtonWidth
            test.assertTrue(tokenRowWidth <= controlWidth, 
                "Token row fits in control column: row=\(tokenRowWidth), column=\(controlWidth)")
        }

        test.run("test_SettingsVisual_HorizontalPaddingIsSymmetric") {
            // Ensure padding is applied equally on both sides
            let padding = SettingsViewConfiguration.formOuterPadding
            test.assertTrue(padding > 0, "Outer padding is positive")
            test.assertTrue(padding >= 20, "Outer padding provides sufficient margin (>=20pt)")
            test.assertTrue(padding <= 40, "Outer padding is not excessive (<=40pt)")
            
            // Content width after padding should leave room for two-column layout
            let windowWidth = SettingsViewConfiguration.windowSize.width
            let contentWidth = windowWidth - (padding * 2)
            let minTwoColumnWidth: CGFloat = 400 // Minimum for readable two-column layout
            test.assertTrue(contentWidth >= minTwoColumnWidth, 
                "Content area supports two-column layout: \(contentWidth) >= \(minTwoColumnWidth)")
        }

        test.run("test_SettingsVisual_SectionTitlesHaveSpaceToRender") {
            // Section titles render at the left edge of content area
            // They need the full content width available
            let windowWidth = SettingsViewConfiguration.windowSize.width
            let padding = SettingsViewConfiguration.formOuterPadding
            let contentWidth = windowWidth - (padding * 2)
            
            // Longest section title is approximately "Troubleshooting" = 15 chars
            // At ~8pt per character in .title3 weight, that's ~120pt minimum
            let estimatedTitleWidth: CGFloat = 150 // Conservative estimate with font weight
            test.assertTrue(contentWidth >= estimatedTitleWidth, 
                "Content width accommodates section titles: \(contentWidth) >= \(estimatedTitleWidth)")
            
            // Verify padding doesn't eat into required label space
            let labelWidth = SettingsViewConfiguration.formLabelWidth
            test.assertTrue(contentWidth > labelWidth, 
                "Content width exceeds label column: \(contentWidth) > \(labelWidth)")
        }

        test.printSummary()
    }
}

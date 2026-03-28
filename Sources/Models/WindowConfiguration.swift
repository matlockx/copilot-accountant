import Foundation
import AppKit

enum SettingsActionBarPlacement {
    case pinnedFooter
}

enum SettingsLayoutStyle {
    case twoColumnGrid
}

enum SettingsColumnAlignment {
    case trailing
}

enum CheckboxColumnAlignment {
    case sharedVerticalColumn
}

enum FooterPresentationStyle {
    case safeAreaInsetBar
}

enum TokenRevealBehavior {
    case savedTokenOnly
}

enum SettingsSurfaceStyle {
    case tintedCards
}

enum CustomAlertLayoutStyle {
    case valueCheckboxRemove
}

enum SettingsColorStyle {
    case neutralGray
}

struct SettingsViewConfiguration {
    static let actionBarPlacement: SettingsActionBarPlacement = .pinnedFooter
    static let layoutStyle: SettingsLayoutStyle = .twoColumnGrid
    static let controlColumnAlignment: SettingsColumnAlignment = .trailing
    static let tokenRevealBehavior: TokenRevealBehavior = .savedTokenOnly
    static let surfaceStyle: SettingsSurfaceStyle = .tintedCards
    static let customAlertLayout: CustomAlertLayoutStyle = .valueCheckboxRemove
    static let colorStyle: SettingsColorStyle = .neutralGray
    static let footerHeight: CGFloat = 60
    static let footerButtonTitles = ["Cancel", "Save"]
    static let windowSize = CGSize(width: 620, height: 620)
    static let formOuterPadding: CGFloat = 24
    static let formLabelWidth: CGFloat = 190
    static let formFieldSpacing: CGFloat = 12
    static let utilityButtonWidth: CGFloat = 120
    static let footerButtonWidth: CGFloat = 120
    static let actionColumnWidth: CGFloat = 120
    static let valueFieldWidth: CGFloat = 96
    static let tokenFieldWidth: CGFloat = 236
    static let toggleColumnWidth: CGFloat = 32
    static let checkboxColumnWidth: CGFloat = 32
    static let customAlertValueColumnWidth: CGFloat = 140
    static let notificationControlWidth: CGFloat = 316
    static let checkboxColumnAlignment: CheckboxColumnAlignment = .sharedVerticalColumn
    static let footerPresentation: FooterPresentationStyle = .safeAreaInsetBar
    static let escapeKeyClosesWindow = true
    static let hiddenTokenMask = "••••••••••••"
}

struct SettingsAlertConfiguration {
    static let successTitle = "Validation Succeeded"
    static let failureTitle = "Validation Failed"
}

struct DetailedStatsWindowConfiguration {
    static let initialSize = CGSize(width: 700, height: 600)
    static let minSize = CGSize(width: 600, height: 500)
    static let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]
    static let escapeKeyClosesWindow = true
}

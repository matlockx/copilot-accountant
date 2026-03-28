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
    case flatCards
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
    static let surfaceStyle: SettingsSurfaceStyle = .flatCards
    static let customAlertLayout: CustomAlertLayoutStyle = .valueCheckboxRemove
    static let colorStyle: SettingsColorStyle = .neutralGray
    static let footerHeight: CGFloat = 56
    static let footerButtonTitles = ["Cancel", "Save"]
    static let windowSize = CGSize(width: 560, height: 640)
    static let formOuterPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 10
    static let formLabelWidth: CGFloat = 160
    static let formFieldSpacing: CGFloat = 10
    static let utilityButtonWidth: CGFloat = 100
    static let footerButtonWidth: CGFloat = 100
    static let actionColumnWidth: CGFloat = 100
    static let valueFieldWidth: CGFloat = 80
    static let tokenFieldWidth: CGFloat = 236
    static let toggleColumnWidth: CGFloat = 32
    static let checkboxColumnWidth: CGFloat = 32
    static let customAlertValueColumnWidth: CGFloat = 120
    static let notificationControlWidth: CGFloat = 300
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
    static let initialSize = CGSize(width: 820, height: 700)
    static let minSize = CGSize(width: 750, height: 550)
    static let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]
    static let escapeKeyClosesWindow = true
}

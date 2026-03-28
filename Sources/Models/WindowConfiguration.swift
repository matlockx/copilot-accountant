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

enum TokenRevealBehavior {
    case savedTokenOnly
}

enum SettingsSurfaceStyle {
    case tintedCards
}

enum CustomAlertLayoutStyle {
    case valueCheckboxRemove
}

struct SettingsViewConfiguration {
    static let actionBarPlacement: SettingsActionBarPlacement = .pinnedFooter
    static let layoutStyle: SettingsLayoutStyle = .twoColumnGrid
    static let controlColumnAlignment: SettingsColumnAlignment = .trailing
    static let tokenRevealBehavior: TokenRevealBehavior = .savedTokenOnly
    static let surfaceStyle: SettingsSurfaceStyle = .tintedCards
    static let customAlertLayout: CustomAlertLayoutStyle = .valueCheckboxRemove
    static let footerHeight: CGFloat = 60
    static let footerButtonTitles = ["Cancel", "Save"]
    static let windowSize = CGSize(width: 520, height: 620)
    static let formLabelWidth: CGFloat = 190
    static let formFieldSpacing: CGFloat = 12
    static let utilityButtonWidth: CGFloat = 120
    static let valueFieldWidth: CGFloat = 96
    static let toggleColumnWidth: CGFloat = 32
    static let notificationControlWidth: CGFloat = 272
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
}

import Foundation
import AppKit

enum SettingsActionBarPlacement {
    case pinnedFooter
}

struct SettingsViewConfiguration {
    static let actionBarPlacement: SettingsActionBarPlacement = .pinnedFooter
    static let footerHeight: CGFloat = 60
    static let footerButtonTitles = ["Cancel", "Save"]
    static let windowSize = CGSize(width: 520, height: 620)
}

struct DetailedStatsWindowConfiguration {
    static let initialSize = CGSize(width: 700, height: 600)
    static let minSize = CGSize(width: 600, height: 500)
    static let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]
}

import SwiftUI

@main
struct CopilotAccountantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Don't show any main window - we're a menu bar app
        Settings {
            EmptyView()
        }
    }
}

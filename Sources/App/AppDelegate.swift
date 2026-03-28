import SwiftUI
import AppKit

final class EscapeClosableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

/// Application delegate for menu bar management
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var tracker: UsageTracker?
    private var settingsWindow: NSWindow?
    private var detailedStatsWindow: NSWindow?
    private var eventMonitor: Any?
    
    private let isFirstLaunchKey = "hasLaunchedBefore"
    private let launchedAtLoginKey = "launchedAtLogin"
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Check if another instance is already running
        if isAnotherInstanceRunning() {
            // Activate the existing instance
            activateExistingInstance()
            // Terminate this instance
            NSApp.terminate(nil)
            return
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize tracker
        tracker = UsageTracker()
        
        // Request notification permissions
        Task {
            await NotificationService.shared.requestAuthorization()
        }
        
        // Create status bar item
        setupStatusBarItem()
        
        // Start polling
        Task { @MainActor in
            tracker?.startPolling()
        }
        
        // Show popup on first launch (unless launched at login)
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: isFirstLaunchKey)
        let launchedAtLogin = tracker?.config.launchAtLogin ?? false
        
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: isFirstLaunchKey)
            // Small delay to ensure status item is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        } else if !launchedAtLogin {
            // For manual launches (not at login), show popup briefly
            // This helps users see the app has started
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showPopover()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        tracker?.stopPolling()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    @MainActor
    private func setupStatusBarItem() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button,
              let tracker = tracker else {
            return
        }
        
        // Set initial text
        updateStatusBarText()
        
        // Set action
        button.action = #selector(togglePopover)
        button.target = self
        
        // Create popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        
        let menuView = MenuBarView(
            tracker: tracker,
            openSettings: { [weak self] in
                self?.popover?.close()
                self?.openSettings()
            },
            openDetailedStats: { [weak self] in
                self?.popover?.close()
                self?.openDetailedStats()
            },
            refreshNow: { [weak self] in
                Task { @MainActor in
                    await self?.tracker?.fetchUsage(reason: .manualRefresh)
                    self?.updateStatusBarText()
                }
            },
            quitApp: {
                NSApplication.shared.terminate(nil)
            }
        )
        
        popover.contentViewController = NSHostingController(rootView: menuView)
        self.popover = popover
        
        // Set up event monitor to close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.close()
            }
        }
        
        // Observe tracker changes to update menu bar
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: UsageTracker.usageUpdatedNotification) {
                self.updateStatusBarText()
            }
        }
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.close()
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func showPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @MainActor
    private func updateStatusBarText() {
        guard let button = statusItem?.button,
              let tracker = tracker,
              let usage = tracker.currentUsage else {
            statusItem?.button?.title = "☁️ --"
            return
        }
        
        let used = usage.totalRequests
        _ = tracker.config.monthlyBudget
        let percentage = tracker.config.usagePercentage(used: used)
        
        // Update text with emoji indicator
        let emoji: String
        switch tracker.config.statusColor(used: used) {
        case .green:
            emoji = "🟢"
        case .yellow:
            emoji = "🟡"
        case .orange:
            emoji = "🟠"
        case .red:
            emoji = "🔴"
        }
        
        button.title = String(format: "%@ %.1f%%", emoji, percentage)
    }
    
    private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(tracker: tracker!)
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = EscapeClosableWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(SettingsViewConfiguration.windowSize)
            window.center()
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func openDetailedStats() {
        if #available(macOS 14.0, *) {
            if detailedStatsWindow == nil {
                let detailedView = DetailedStatsView(tracker: tracker!)
                let hostingController = NSHostingController(rootView: detailedView)
                
                let window = EscapeClosableWindow(contentViewController: hostingController)
                window.title = "Copilot Usage Statistics"
                window.styleMask = DetailedStatsWindowConfiguration.styleMask
                window.setContentSize(DetailedStatsWindowConfiguration.initialSize)
                window.minSize = DetailedStatsWindowConfiguration.minSize
                window.center()
                
                detailedStatsWindow = window
            }
            
            detailedStatsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Fallback for macOS < 14.0
            let alert = NSAlert()
            alert.messageText = "macOS 14.0 Required"
            alert.informativeText = "The detailed statistics window requires macOS 14.0 (Sonoma) or later for chart support."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - Singleton Protection
    
    /// Check if another instance of the app is already running
    private func isAnotherInstanceRunning() -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.copilot-accountant.app"
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Count instances of this app (excluding self)
        let instances = runningApps.filter { app in
            app.bundleIdentifier == bundleIdentifier
        }
        
        // If we found more than one instance (this one), another is running
        return instances.count > 1
    }
    
    /// Activate the existing instance
    private func activateExistingInstance() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.copilot-accountant.app"
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Find and activate the existing instance
        if let existingApp = runningApps.first(where: { 
            $0.bundleIdentifier == bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) {
            if #available(macOS 14.0, *) {
                existingApp.activate()
            } else {
                existingApp.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }
}

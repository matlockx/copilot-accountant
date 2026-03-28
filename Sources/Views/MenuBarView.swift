import SwiftUI
import AppKit

/// Main menu bar item and dropdown menu
struct MenuBarView: View {
    @ObservedObject var tracker: UsageTracker
    let openSettings: () -> Void
    let openDetailedStats: () -> Void
    let refreshNow: () -> Void
    let quitApp: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with current status
            headerSection
                .padding()
            
            Divider()
            
            // Quick stats
            if let usage = tracker.currentUsage {
                quickStatsSection(usage: usage)
                    .padding()
            } else if tracker.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            Divider()
            
            // Actions
            actionsSection
        }
        .frame(width: 300)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let usage = tracker.currentUsage {
                let used = usage.totalRequests
                let budget = tracker.config.monthlyBudget
                let percentage = tracker.config.usagePercentage(used: used)
                
                HStack {
                    Circle()
                        .fill(statusColor(percentage: percentage))
                        .frame(width: 12, height: 12)
                    
                    Text("GitHub Copilot Usage")
                        .font(.headline)
                }
                
                Text("\(used) / \(budget) requests")
                    .font(.title2)
                    .bold()
                
                Text(String(format: "%.1f%% used", percentage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: Double(used), total: Double(budget))
                    .tint(statusColor(percentage: percentage))
            } else {
                HStack {
                    Circle()
                        .fill(.gray)
                        .frame(width: 12, height: 12)
                    
                    Text("GitHub Copilot Usage")
                        .font(.headline)
                }
                
                Text("Not configured")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func quickStatsSection(usage: UsageResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text("Resets in \(tracker.daysUntilReset()) days")
                    .font(.caption)
            }
            
            if let lastUpdate = tracker.lastUpdateTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("Updated \(timeAgo(lastUpdate))")
                        .font(.caption)
                }
            }
            
            if !tracker.getModelUsage().isEmpty {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("Top: \(topModel())")
                        .font(.caption)
                }
            }
            
            if let error = tracker.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 0) {
            MenuButton("Detailed Statistics", icon: "chart.bar.fill") {
                openDetailedStats()
            }
            
            MenuButton("Refresh Now", icon: "arrow.clockwise") {
                refreshNow()
            }
            .disabled(tracker.isLoading)
            
            Divider()
            
            MenuButton("Settings", icon: "gear") {
                openSettings()
            }
            
            Divider()
            
            MenuButton("Quit", icon: "xmark.circle") {
                quitApp()
            }
        }
    }
    
    private func statusColor(percentage: Double) -> Color {
        if percentage >= 90 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else if percentage >= 60 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
    
    private func topModel() -> String {
        let models = tracker.getModelUsage()
        return models.first?.modelName ?? "N/A"
    }
}

/// Reusable menu button component
struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDisabled: Bool = false
    
    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .onHover { hovering in
            if hovering && !isDisabled {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    func disabled(_ disabled: Bool) -> MenuButton {
        var copy = self
        copy.isDisabled = disabled
        return copy
    }
}

import SwiftUI
import AppKit

// MARK: - Colored progress bar
// SwiftUI's ProgressView.tint() is unreliable inside NSPopover on macOS.
// This custom view draws the bar explicitly with the given color.
private struct ColoredBar: View {
    let fraction: Double   // 0.0 – 1.0 (clamped)
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: .separatorColor).opacity(0.4))
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(fraction, 1.0)))
            }
        }
        .frame(height: 5)
    }
}

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
            
            // Spending budget section (F019) — only shown when dollar budget is configured
            if let budget = tracker.spendingBudget {
                Divider()
                spendingBudgetSection(budget: budget)
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
                
                ColoredBar(
                    fraction: Double(used) / max(Double(budget), 1),
                    color: statusColor(percentage: percentage)
                )
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
    
    // F019: Spending budget summary section
    private func spendingBudgetSection(budget: SpendingBudgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section label
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text("Spending Budget")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            // Dollar amount line
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(String(format: "$%.2f / $%.2f budget", budget.amountSpent, budget.budgetAmount))
                    .font(.caption)
            }

            // Progress bar
            ColoredBar(
                fraction: min(budget.percentUsed, 100) / 100,
                color: spendingStatusColor(budget.percentUsed)
            )
            .padding(.leading, 20)

            // Remaining amount
            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(String(format: "$%.2f remaining", budget.remaining))
                    .font(.caption)
                    .foregroundColor(budget.isCapReached ? .red : .secondary)
            }

            // Billing context: billed vs included requests
            if let usage = tracker.currentUsage {
                let billedTotal = Int((usage.totalNetCost / max(usage.pricePerRequest, 0.0001)).rounded())
                HStack(alignment: .top) {
                    Image(systemName: billedTotal > 0 ? "exclamationmark.circle" : "checkmark.circle")
                        .foregroundColor(billedTotal > 0 ? .orange : .green)
                        .frame(width: 20)
                    if billedTotal > 0 {
                        Text("\(billedTotal) billed requests beyond included limit")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("All usage within included requests")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private func spendingStatusColor(_ percentUsed: Double) -> Color {
        if percentUsed >= 90 {
            return .red
        } else if percentUsed >= 80 {
            return .orange
        } else if percentUsed >= 60 {
            return .yellow
        } else {
            return .green
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

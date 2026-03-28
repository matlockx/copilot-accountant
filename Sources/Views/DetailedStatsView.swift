import SwiftUI
import Charts

/// Detailed statistics window with charts
@available(macOS 14.0, *)
struct DetailedStatsView: View {
    @ObservedObject var tracker: UsageTracker
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                Divider()
                
                // Daily usage chart
                if !tracker.dailyUsage.isEmpty {
                    dailyUsageChart
                    Divider()
                }
                
                // Model breakdown
                if !tracker.getModelUsage().isEmpty {
                    modelBreakdownSection()
                    Divider()
                }
                
                // Product breakdown
                if let usage = tracker.currentUsage {
                    productBreakdownSection(usage: usage)
                }
            }
            .padding()
        }
        .frame(width: 700, height: 600)
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Copilot Premium Requests")
                .font(.title)
                .bold()
            
            if let usage = tracker.currentUsage {
                let used = usage.totalRequests
                let budget = tracker.config.monthlyBudget
                let percentage = tracker.config.usagePercentage(used: used)
                
                HStack(spacing: 30) {
                    VStack {
                        Text("\(used)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(statusColor(percentage: percentage))
                        Text("Requests Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("\(budget)")
                            .font(.system(size: 48, weight: .bold))
                        Text("Monthly Budget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(String(format: "%.1f%%", percentage))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(statusColor(percentage: percentage))
                        Text("Used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                ProgressView(value: Double(used), total: Double(budget))
                    .tint(statusColor(percentage: percentage))
                    .frame(width: 400)
                
                Text("Resets in \(tracker.daysUntilReset()) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastUpdate = tracker.lastUpdateTime {
                    Text("Last updated: \(formatDate(lastUpdate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dailyUsageChart: some View {
        VStack(alignment: .leading) {
            Text("Daily Usage This Month")
                .font(.headline)
                .padding(.bottom, 5)
            
            Chart(tracker.dailyUsage) { item in
                BarMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Requests", item.requests)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
        }
    }
    
    private func modelBreakdownSection() -> some View {
        VStack(alignment: .leading) {
            Text("Usage by Model")
                .font(.headline)
                .padding(.bottom, 5)
            
            let modelUsage = tracker.getModelUsage()
            
            Chart(modelUsage) { item in
                SectorMark(
                    angle: .value("Count", item.requestCount),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Model", item.modelName))
                .annotation(position: .overlay) {
                    if item.percentage > 5 {
                        Text(String(format: "%.0f%%", item.percentage))
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 250)
            
            // Legend
            VStack(alignment: .leading, spacing: 5) {
                ForEach(modelUsage) { item in
                    HStack {
                        Circle()
                            .frame(width: 10, height: 10)
                        Text(item.modelName)
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.1f requests", item.requestCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "(%.1f%%)", item.percentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 10)
        }
    }
    
    private func productBreakdownSection(usage: UsageResponse) -> some View {
        VStack(alignment: .leading) {
            Text("Usage by Product")
                .font(.headline)
                .padding(.bottom, 5)
            
            let byProduct = usage.usageByProduct.sorted { 
                if $0.value != $1.value {
                    return $0.value > $1.value
                }
                return $0.key < $1.key
            }
            
            ForEach(byProduct, id: \.key) { product, count in
                HStack {
                    Text(product)
                        .font(.body)
                    Spacer()
                    Text(String(format: "%.1f requests", count))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

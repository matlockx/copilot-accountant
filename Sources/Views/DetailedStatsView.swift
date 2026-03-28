import SwiftUI
import Charts

/// Detailed statistics window with charts
@available(macOS 14.0, *)
struct DetailedStatsView: View {
    @ObservedObject var tracker: UsageTracker
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("Premium request analytics")
                    .font(.title)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Billing cards (like GitHub's UI)
                if let usage = tracker.currentUsage {
                    billingCardsSection(usage: usage)
                }
                
                Divider()
                
                // Usage breakdown section
                if let usage = tracker.currentUsage {
                    usageBreakdownSection(usage: usage)
                }
                
                Divider()
                
                // Daily usage chart
                if !tracker.dailyUsage.isEmpty {
                    dailyUsageChart
                }
                
                Divider()
                
                // Model pricing info
                if let usage = tracker.currentUsage {
                    modelPricingSection(usage: usage)
                }
                
                Divider()
                 
                // Product breakdown
                if let usage = tracker.currentUsage {
                    productBreakdownSection(usage: usage)
                }
                
                // Last update info
                if let lastUpdate = tracker.lastUpdateTime {
                    Text("Last updated: \(formatDate(lastUpdate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(
            minWidth: DetailedStatsWindowConfiguration.minSize.width,
            idealWidth: DetailedStatsWindowConfiguration.initialSize.width,
            maxWidth: .infinity,
            minHeight: DetailedStatsWindowConfiguration.minSize.height,
            idealHeight: DetailedStatsWindowConfiguration.initialSize.height,
            maxHeight: .infinity,
            alignment: .top
        )
    }
    
    // MARK: - Billing Cards Section (like GitHub)
    
    private func billingCardsSection(usage: UsageResponse) -> some View {
        let summary = usage.billingSummary(includedRequests: tracker.config.monthlyBudget)
        let percentage = tracker.config.usagePercentage(used: summary.usedRequests)
        
        return HStack(spacing: 16) {
            // Billed premium requests card
            billingCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Billed premium requests")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(currency(summary.netCost))
                        .font(.system(size: 36, weight: .bold))
                    
                    if summary.netCost == 0 {
                        Text("All usage covered by included requests")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(summary.overageRequests) requests beyond included limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Included premium requests card
            billingCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Included premium requests consumed")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(format: "%.2f", summary.includedUsed))
                            .font(.system(size: 36, weight: .bold))
                        Text("of \(summary.includedRequests) included")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress bar
                    ProgressView(value: min(summary.includedPercentage, 100), total: 100)
                        .tint(statusColor(percentage: percentage))
                    
                    Text("Monthly limit resets in \(usage.daysUntilReset) days on \(usage.resetDateDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func billingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
    
    // MARK: - Usage Breakdown Section
    
    private func usageBreakdownSection(usage: UsageResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage breakdown")
                .font(.headline)
            
            Text("Usage for \(usage.billingPeriodDescription). Price per premium request is \(currency(usage.pricePerRequest)).")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .top, spacing: 24) {
                // Pie chart
                modelPieChart()
                    .frame(width: 250, height: 250)
                
                // Model billing table
                modelBillingTable(usage: usage)
            }
        }
    }
    
    private func modelPieChart() -> some View {
        let modelUsage = tracker.getModelUsage()
        
        return Chart(modelUsage) { item in
            SectorMark(
                angle: .value("Count", item.requestCount),
                innerRadius: .ratio(0.5),
                angularInset: 1
            )
            .foregroundStyle(by: .value("Model", item.modelName))
            .annotation(position: .overlay) {
                if item.percentage > 8 {
                    Text(String(format: "%.0f%%", item.percentage))
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .chartLegend(.hidden)
    }
    
    private func modelBillingTable(usage: UsageResponse) -> some View {
        let details = usage.modelBillingDetails()
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("Model")
                    .frame(width: 150, alignment: .leading)
                Text("Included")
                    .frame(width: 80, alignment: .trailing)
                Text("Billed")
                    .frame(width: 70, alignment: .trailing)
                Text("Gross")
                    .frame(width: 70, alignment: .trailing)
                Text("Billed")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Second header row (sub-labels)
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 150, alignment: .leading)
                Text("requests")
                    .frame(width: 80, alignment: .trailing)
                Text("requests")
                    .frame(width: 70, alignment: .trailing)
                Text("amount")
                    .frame(width: 70, alignment: .trailing)
                Text("amount")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.bottom, 4)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Data rows
            ForEach(details) { detail in
                HStack(spacing: 0) {
                    Text(detail.model)
                        .frame(width: 150, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(formatQuantity(detail.includedRequests))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(formatQuantity(detail.billedRequests))
                        .frame(width: 70, alignment: .trailing)
                    
                    Text(currency(detail.grossAmount))
                        .frame(width: 70, alignment: .trailing)
                    
                    Text(currency(detail.billedAmount))
                        .frame(width: 70, alignment: .trailing)
                        .fontWeight(detail.billedAmount > 0 ? .semibold : .regular)
                }
                .font(.body.monospacedDigit())
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                
                Divider()
            }
            
            // Totals row
            if !details.isEmpty {
                HStack(spacing: 0) {
                    Text("Total")
                        .fontWeight(.semibold)
                        .frame(width: 150, alignment: .leading)
                    
                    Text(formatQuantity(details.reduce(0) { $0 + $1.includedRequests }))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(formatQuantity(details.reduce(0) { $0 + $1.billedRequests }))
                        .frame(width: 70, alignment: .trailing)
                    
                    Text(currency(details.reduce(0) { $0 + $1.grossAmount }))
                        .frame(width: 70, alignment: .trailing)
                    
                    Text(currency(details.reduce(0) { $0 + $1.billedAmount }))
                        .frame(width: 70, alignment: .trailing)
                        .fontWeight(.semibold)
                }
                .font(.body.monospacedDigit())
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    // MARK: - Daily Usage Chart
    
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
                AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
        }
    }
    
    // MARK: - Model Pricing Section
    
    private func modelPricingSection(usage: UsageResponse) -> some View {
        let modelPrices = Dictionary(grouping: usage.usageItems, by: \.model)
            .compactMapValues { $0.first?.pricePerUnit }
        
        let cheapestPrice = modelPrices.values.min() ?? 1.0
        let sortedPrices = modelPrices.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Model Pricing")
                .font(.headline)
            
            if usage.allModelsSamePrice {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("All models billed at \(currency(usage.pricePerRequest)) per premium request.")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            } else {
                Text("Models have different pricing. Cost factor is relative to the cheapest model.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(sortedPrices, id: \.key) { model, unitPrice in
                let factor = cheapestPrice > 0 ? unitPrice / cheapestPrice : 1.0
                HStack {
                    Text(model)
                    Spacer()
                    if !usage.allModelsSamePrice {
                        Text(String(format: "%.1fx", factor))
                            .font(.body.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(factor > 1 ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(currency(unitPrice))
                        .foregroundColor(.secondary)
                        .font(.body.monospacedDigit())
                    Text("/ request")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Product Breakdown Section
    
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
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Helpers
    
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

    private func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
    
    private func formatQuantity(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value < 1 {
            return String(format: "%.2f", value)
        } else if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

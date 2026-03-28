import SwiftUI
import Charts

/// Detailed statistics window with charts
@available(macOS 14.0, *)
struct DetailedStatsView: View {
    @ObservedObject var tracker: UsageTracker
    @StateObject private var multiplierService = ModelMultiplierService.shared
    @State private var isUpdatingMultipliers = false
    @State private var multiplierUpdateError: String? = nil
    @State private var multiplierUpdateSuccess = false
    @State private var hoveredDay: DailyUsage? = nil
    @State private var tooltipPosition: CGPoint = .zero
    @State private var multipliersURL: String = ModelMultiplierService.shared.multipliersURL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("Premium request analytics")
                    .font(.title)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Billing cards
                if let usage = tracker.currentUsage {
                    billingCardsSection(usage: usage)
                } else {
                    emptyStateCard(DetailedStatsEmptyState.noUsage)
                }
                
                Divider()
                
                // Usage breakdown section
                if let usage = tracker.currentUsage {
                    usageBreakdownSection(usage: usage)
                }
                
                Divider()
                
                // Daily usage chart with tooltip
                if !tracker.dailyUsage.isEmpty {
                    dailyUsageChart
                } else {
                    emptyStateCard(DetailedStatsEmptyState.noDailyData)
                }
                
                Divider()
                
                // All Models catalog
                allModelsCatalogSection
                
                Divider()
                
                // Model multiplier update section
                multiplierUpdateSection
                
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
    
    // MARK: - Empty State
    
    private func emptyStateCard(_ message: String) -> some View {
        Text(message)
            .font(.body)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Billing Cards Section
    
    private func billingCardsSection(usage: UsageResponse) -> some View {
        let summary = usage.billingSummary(includedRequests: tracker.config.monthlyBudget)
        let totalUsed = usage.usageItems.reduce(0.0) { $0 + $1.grossQuantity }
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
                        Text(String(format: "%.2f", totalUsed))
                            .font(.system(size: 36, weight: .bold))
                        Text("of \(tracker.config.monthlyBudget) included")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: min(percentage, 100), total: 100)
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
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
                modelPieChart()
                    .frame(width: 250, height: 250)
                
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
                    .frame(width: 140, alignment: .leading)
                Text("Multiplier")
                    .frame(width: 72, alignment: .trailing)
                Text("Included")
                    .frame(width: 72, alignment: .trailing)
                Text("Billed")
                    .frame(width: 60, alignment: .trailing)
                Text("Gross")
                    .frame(width: 80, alignment: .trailing)
                Text("Billed")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Sub-labels
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 140, alignment: .leading)
                Text("")
                    .frame(width: 72, alignment: .trailing)
                Text("requests")
                    .frame(width: 72, alignment: .trailing)
                Text("requests")
                    .frame(width: 60, alignment: .trailing)
                Text("amount")
                    .frame(width: 80, alignment: .trailing)
                Text("amount")
                    .frame(width: 80, alignment: .trailing)
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
                        .frame(width: 140, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(CopilotModelMultipliers.formatMultiplier(detail.multiplier))
                        .frame(width: 72, alignment: .trailing)
                        .foregroundColor(multiplierColor(detail.multiplier))
                    
                    Text(formatQuantity(detail.includedRequests))
                        .frame(width: 72, alignment: .trailing)
                    
                    Text(formatQuantity(detail.billedRequests))
                        .frame(width: 60, alignment: .trailing)
                    
                    Text(currency(detail.grossAmount))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(currency(detail.billedAmount))
                        .frame(width: 80, alignment: .trailing)
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
                        .frame(width: 140, alignment: .leading)
                    
                    Text("")
                        .frame(width: 72, alignment: .trailing)
                    
                    Text(formatQuantity(details.reduce(0) { $0 + $1.includedRequests }))
                        .frame(width: 72, alignment: .trailing)
                    
                    Text(formatQuantity(details.reduce(0) { $0 + $1.billedRequests }))
                        .frame(width: 60, alignment: .trailing)
                    
                    Text(currency(details.reduce(0) { $0 + $1.grossAmount }))
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(currency(details.reduce(0) { $0 + $1.billedAmount }))
                        .frame(width: 80, alignment: .trailing)
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
    
    private func multiplierColor(_ multiplier: Double) -> Color {
        if multiplier == 0 {
            return .green
        } else if multiplier < 1 {
            return .blue
        } else if multiplier == 1 {
            return .primary
        } else if multiplier <= 3 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Daily Usage Chart with Tooltip
    
    private var dailyUsageChart: some View {
        VStack(alignment: .leading) {
            Text("Daily Usage This Month")
                .font(.headline)
                .padding(.bottom, 5)
            
            ZStack(alignment: .topLeading) {
                Chart(tracker.dailyUsage) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Requests", item.requests)
                    )
                    .foregroundStyle(
                        hoveredDay?.date == item.date
                            ? Color.blue
                            : (hoveredDay != nil
                                ? Color.blue.opacity(ChartTooltipConfiguration.dimmedOpacity)
                                : Color.blue.opacity(0.8))
                    )
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let xPosition = location.x - geometry[plotFrame].origin.x
                                    let yPosition = location.y - geometry[plotFrame].origin.y
                                    
                                    if let date: Date = proxy.value(atX: xPosition) {
                                        let calendar = Calendar.current
                                        let matchedDay = tracker.dailyUsage.first { day in
                                            calendar.isDate(day.date, inSameDayAs: date)
                                        }
                                        hoveredDay = matchedDay
                                        tooltipPosition = CGPoint(
                                            x: location.x,
                                            y: yPosition
                                        )
                                    }
                                case .ended:
                                    hoveredDay = nil
                                }
                            }
                    }
                }
                
                // Tooltip overlay
                if let day = hoveredDay {
                    chartTooltip(day: day)
                        .offset(x: tooltipPosition.x - 60, y: max(0, tooltipPosition.y - 70))
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private func chartTooltip(day: DailyUsage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatTooltipDate(day.date))
                .font(.caption.weight(.semibold))
            
            HStack(spacing: 4) {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                Text("\(day.requests) requests")
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(ChartTooltipConfiguration.padding)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: ChartTooltipConfiguration.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: ChartTooltipConfiguration.shadowRadius, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ChartTooltipConfiguration.cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - All Models Catalog Section
    
    private var allModelsCatalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Models")
                .font(.headline)
            
            Text("Complete catalog of Copilot models with multipliers and usage status.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            let multipliers = multiplierService.effectiveMultipliers()
            let usageByModel = tracker.currentUsage?.usageByModel ?? [:]
            let catalog = ModelMultiplierService.buildCatalog(
                knownMultipliers: multipliers,
                usageByModel: usageByModel
            )
            
            if catalog.isEmpty {
                emptyStateCard(DetailedStatsEmptyState.noModels)
            } else {
                modelCatalogGrid(entries: catalog)
            }
        }
    }
    
    private func modelCatalogGrid(entries: [ModelCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Model")
                    .frame(width: 180, alignment: .leading)
                Text("Multiplier")
                    .frame(width: 80, alignment: .trailing)
                Text("Usage")
                    .frame(width: 80, alignment: .trailing)
                Text("Status")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ForEach(entries) { entry in
                HStack(spacing: 0) {
                    Text(entry.name)
                        .frame(width: 180, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Multiplier badge
                    Text(CopilotModelMultipliers.formatMultiplier(entry.multiplier))
                        .font(.body.monospacedDigit().weight(.medium))
                        .foregroundColor(multiplierColor(entry.multiplier))
                        .frame(width: 80, alignment: .trailing)
                    
                    // Usage
                    if entry.usage > 0 {
                        Text(formatQuantity(entry.usage))
                            .font(.body.monospacedDigit())
                            .frame(width: 80, alignment: .trailing)
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    
                    // Status badge
                    statusBadge(entry.status)
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.body)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .opacity(entry.usage > 0 ? 1.0 : 0.6)
                
                Divider()
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    private func statusBadge(_ status: ModelStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .used:
                return ("Used", .green)
            case .available:
                return ("Available", .secondary)
            case .free:
                return ("Free", .blue)
            }
        }()
        
        return Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
    
    // MARK: - Multiplier Update Section
    
    private var multiplierUpdateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Model Multipliers")
                .font(.headline)
            
            Text("Each model has a multiplier that determines how many premium requests it consumes. For example, Claude Opus (3x) uses 3 premium requests per interaction.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Legend
            HStack(spacing: 16) {
                multiplierLegendItem(label: "Included", color: .green, description: "Free on paid plans")
                multiplierLegendItem(label: "< 1x", color: .blue, description: "Discounted")
                multiplierLegendItem(label: "1x", color: .primary, description: "Standard")
                multiplierLegendItem(label: "> 1x", color: .orange, description: "Premium")
            }
            .font(.caption)
            .padding(.vertical, 4)
            
            // Source URL field
            HStack(spacing: 8) {
                Text("Source URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Multiplier data URL", text: $multipliersURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                    .onSubmit {
                        multiplierService.multipliersURL = multipliersURL
                    }
                Button {
                    multipliersURL = ModelMultiplierConfiguration.defaultMultipliersURL
                    multiplierService.multipliersURL = multipliersURL
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reset to default URL")
            }
            
            // Update button + status
            HStack(spacing: 12) {
                Button {
                    multiplierService.multipliersURL = multipliersURL
                    Task { await updateMultipliers() }
                } label: {
                    HStack(spacing: 6) {
                        if isUpdatingMultipliers {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        Text("Update Model Multipliers")
                    }
                }
                .disabled(isUpdatingMultipliers)
                
                if multiplierUpdateSuccess {
                    Label("Updated", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if let error = multiplierUpdateError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text("Last updated: \(multiplierService.lastUpdateDescription)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func updateMultipliers() async {
        isUpdatingMultipliers = true
        multiplierUpdateError = nil
        multiplierUpdateSuccess = false
        
        do {
            _ = try await multiplierService.fetchMultipliers()
            multiplierUpdateSuccess = true
            
            // Clear success after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                multiplierUpdateSuccess = false
            }
        } catch {
            multiplierUpdateError = error.localizedDescription
            
            // Clear error after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                multiplierUpdateError = nil
            }
        }
        
        isUpdatingMultipliers = false
    }
    
    private func multiplierLegendItem(label: String, color: Color, description: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .fontWeight(.medium)
            Text("- \(description)")
                .foregroundColor(.secondary)
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
    
    private func formatTooltipDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = ChartTooltipConfiguration.dateFormat
        return formatter.string(from: date)
    }
}

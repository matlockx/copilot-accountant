import SwiftUI
import Charts

// AIDEV-NOTE: Reworked DetailedStatsView — complete rewrite for clarity, robustness, and
// visual polish. Key fixes: stable IDs on ModelUsage/DailyUsage for hover, adaptive
// table layout, collapsible multiplier config, better card design.

/// Detailed statistics window with charts and billing breakdown
@available(macOS 14.0, *)
struct DetailedStatsView: View {
    @ObservedObject var tracker: UsageTracker
    @StateObject private var multiplierService = ModelMultiplierService.shared
    
    // MARK: - Hover / tooltip state
    @State private var hoveredDay: DailyUsage? = nil
    @State private var tooltipPosition: CGPoint = .zero
    @State private var hoveredModel: ModelUsage? = nil
    @State private var pieTooltipPosition: CGPoint = .zero
    
    // MARK: - Multiplier update state
    @State private var isUpdatingMultipliers = false
    @State private var multiplierUpdateError: String? = nil
    @State private var multiplierUpdateSuccess = false
    @State private var multipliersURL: String = ModelMultiplierService.shared.multipliersURL
    @State private var showMultiplierConfig = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                if let usage = tracker.currentUsage {
                    // Top billing summary cards
                    billingCardsSection(usage: usage)
                    
                    // Spending budget card (F018)
                    if let budget = tracker.spendingBudget {
                        spendingBudgetCard(budget: budget)
                    }
                    
                    // Model usage breakdown: pie chart + billing table
                    usageBreakdownSection(usage: usage)
                    
                    // Daily usage bar chart
                    if !tracker.dailyUsage.isEmpty {
                        dailyUsageChartSection
                    } else {
                        emptyCard(DetailedStatsEmptyState.noDailyData)
                    }
                    
                    // All models catalog
                    allModelsCatalogSection
                    
                    // Model multiplier management
                    multiplierSection
                    
                    // Product breakdown
                    productBreakdownSection(usage: usage)
                    
                    // Footer
                    footerSection
                } else {
                    emptyCard(DetailedStatsEmptyState.noUsage)
                }
            }
            .padding(24)
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
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Credit Analytics")
                    .font(.title.bold())
                if let usage = tracker.currentUsage {
                    Text("Usage for \(usage.billingPeriodDescription)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if tracker.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }
    
    // MARK: - Empty State
    
    private func emptyCard(_ message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .background(cardBackground)
    }
    
    // MARK: - Billing Summary Cards
    
    private func billingCardsSection(usage: UsageResponse) -> some View {
        let summary = usage.billingSummary(includedRequests: tracker.config.monthlyBudget)
        let totalUsed = usage.usageItems.reduce(0.0) { $0 + $1.grossQuantity }
        let percentage = tracker.config.usagePercentage(used: summary.usedRequests)
        
        return HStack(spacing: 16) {
            // Billed AI credits card
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Billed AI Credits", systemImage: "dollarsign.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Text(currency(summary.netCost))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    if summary.netCost == 0 {
                        Text("All usage covered by included credits")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("\(summary.overageRequests) credits beyond included limit")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Included AI credits card
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Included Credits Consumed", systemImage: "gauge.with.dots.needle.33percent")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", totalUsed))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("of \(tracker.config.monthlyBudget)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: min(percentage, 100), total: 100)
                        .tint(statusColor(percentage: percentage))
                    
                    Text("Resets in \(usage.daysUntilReset) days · \(usage.resetDateDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Spending Budget Card (F018)
    
    private func spendingBudgetCard(budget: SpendingBudgetSummary) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Spending Budget", systemImage: "creditcard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if budget.preventFurtherUsage {
                        capsuleBadge("Hard cap", color: .orange)
                    } else {
                        capsuleBadge("Soft cap", color: .secondary)
                    }
                }
                
                HStack(spacing: 32) {
                    metricColumn(label: "Budget", value: currency(budget.budgetAmount))
                    metricColumn(label: "Spent", value: currency(budget.amountSpent),
                                 color: budget.isCapReached ? .red : .primary)
                    metricColumn(label: "Remaining", value: currency(budget.remaining),
                                 color: budget.remaining > 0 ? .green : .red)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: min(budget.percentUsed, 100), total: 100)
                        .tint(spendingBudgetColor(percent: budget.percentUsed))
                    
                    HStack {
                        Text(String(format: "%.1f%% of budget used", budget.percentUsed))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if budget.maxAdditionalRequests > 0 {
                            Text("\(budget.maxAdditionalRequests) more credits possible")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if budget.isCapReached {
                            Text("Budget exhausted")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                if budget.isCapReached && budget.preventFurtherUsage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Spending cap reached. AI credits paused until next cycle.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Usage Breakdown Section (Pie Chart + Table)
    
    private func usageBreakdownSection(usage: UsageResponse) -> some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Usage Breakdown", systemImage: "chart.pie")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Price per request: \(currency(usage.pricePerRequest))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 20) {
                    modelPieChart()
                        .frame(width: 220, height: 220)
                    
                    modelBillingTable(usage: usage)
                }
            }
        }
    }
    
    private func modelPieChart() -> some View {
        let modelUsage = tracker.getModelUsage()
        
        return ZStack(alignment: .topLeading) {
            Chart(modelUsage) { item in
                SectorMark(
                    angle: .value("Count", item.requestCount),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Model", item.modelName))
                // AIDEV-NOTE: Uses modelName-based stable ID so comparison
                // survives re-renders (old UUID approach always mismatched).
                .opacity(hoveredModel == nil || hoveredModel?.id == item.id ? 1.0 : 0.4)
                .annotation(position: .overlay) {
                    if item.percentage > 8 && hoveredModel?.id != item.id {
                        Text(String(format: "%.0f%%", item.percentage))
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                pieTooltipPosition = location
                                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                let dx = location.x - center.x
                                let dy = location.y - center.y
                                let dist = sqrt(dx * dx + dy * dy)
                                let outerR = min(geo.size.width, geo.size.height) / 2
                                let innerR = outerR * 0.5
                                guard dist > innerR && dist < outerR else {
                                    hoveredModel = nil
                                    return
                                }
                                var angle = atan2(dy, dx) + .pi / 2
                                if angle < 0 { angle += 2 * .pi }
                                let total = modelUsage.reduce(0.0) { $0 + $1.requestCount }
                                guard total > 0 else { return }
                                var cumulative = 0.0
                                for model in modelUsage {
                                    cumulative += (model.requestCount / total) * 2 * .pi
                                    if angle <= cumulative {
                                        hoveredModel = model
                                        return
                                    }
                                }
                                hoveredModel = nil
                            case .ended:
                                hoveredModel = nil
                            }
                        }
                }
            }
            
            // Tooltip
            if let hovered = hoveredModel {
                pieTooltipView(for: hovered)
                    .position(
                        x: clamp(pieTooltipPosition.x + 14, min: 50, max: 190),
                        y: pieTooltipPosition.y - 12
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeInOut(duration: 0.1)))
            }
        }
    }
    
    private func pieTooltipView(for model: ModelUsage) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.modelName)
                .font(.caption.bold())
                .lineLimit(2)
            Text(String(format: "%.0f credits", model.requestCount))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%.1f%%", model.percentage))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .fixedSize()
    }
    
    private func modelBillingTable(usage: UsageResponse) -> some View {
        let details = usage.modelBillingDetails()
        let totalRequests = details.reduce(0.0) { $0 + $1.totalRequests }
        
        return VStack(alignment: .leading, spacing: 0) {
            // Header
            tableRow(isHeader: true) {
                Text("Model").frame(minWidth: 100, alignment: .leading)
                Text("Share").frame(width: 48, alignment: .trailing)
                Text("Multi.").frame(width: 56, alignment: .trailing)
                Text("Included").frame(width: 60, alignment: .trailing)
                Text("Billed").frame(width: 56, alignment: .trailing)
                Text("Gross $").frame(width: 60, alignment: .trailing)
                Text("Billed $").frame(width: 60, alignment: .trailing)
            }
            
            Divider()
            
            // Data rows
            ForEach(details) { detail in
                let share = totalRequests > 0
                    ? (detail.totalRequests / totalRequests) * 100 : 0
                
                tableRow(isHeader: false) {
                    Text(detail.model)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 100, alignment: .leading)
                    Text(String(format: "%.0f%%", share))
                        .foregroundColor(.secondary)
                        .frame(width: 48, alignment: .trailing)
                    Text(CopilotModelMultipliers.formatMultiplier(detail.multiplier))
                        .foregroundColor(multiplierColor(detail.multiplier))
                        .frame(width: 56, alignment: .trailing)
                    Text(formatQty(detail.includedRequests))
                        .frame(width: 60, alignment: .trailing)
                    Text(formatQty(detail.billedRequests))
                        .frame(width: 56, alignment: .trailing)
                    Text(currency(detail.grossAmount))
                        .frame(width: 60, alignment: .trailing)
                    Text(currency(detail.billedAmount))
                        .fontWeight(detail.billedAmount > 0 ? .semibold : .regular)
                        .frame(width: 60, alignment: .trailing)
                }
                Divider()
            }
            
            // Totals
            if !details.isEmpty {
                tableRow(isHeader: false, isTotal: true) {
                    Text("Total").fontWeight(.semibold)
                        .frame(minWidth: 100, alignment: .leading)
                    Text("100%")
                        .foregroundColor(.secondary)
                        .frame(width: 48, alignment: .trailing)
                    Text("").frame(width: 56, alignment: .trailing)
                    Text(formatQty(details.reduce(0) { $0 + $1.includedRequests }))
                        .frame(width: 60, alignment: .trailing)
                    Text(formatQty(details.reduce(0) { $0 + $1.billedRequests }))
                        .frame(width: 56, alignment: .trailing)
                    Text(currency(details.reduce(0) { $0 + $1.grossAmount }))
                        .frame(width: 60, alignment: .trailing)
                    Text(currency(details.reduce(0) { $0 + $1.billedAmount }))
                        .fontWeight(.semibold)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
        .font(.body.monospacedDigit())
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func tableRow<Content: View>(
        isHeader: Bool = false,
        isTotal: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .font(isHeader ? .caption.bold() : .body.monospacedDigit())
        .foregroundColor(isHeader ? .secondary : .primary)
        .padding(.vertical, isHeader ? 6 : 5)
        .padding(.horizontal, 8)
        .background(
            (isHeader || isTotal)
                ? Color(nsColor: .controlBackgroundColor)
                : Color.clear
        )
    }
    
    // MARK: - Daily Usage Chart
    
    private var dailyUsageChartSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Daily Usage This Month", systemImage: "chart.bar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .topLeading) {
                    Chart(tracker.dailyUsage) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Requests", item.requests)
                        )
                        .foregroundStyle(barColor(for: item))
                        .cornerRadius(2)
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
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
                                        let xPos = location.x - geometry[plotFrame].origin.x
                                        let yPos = location.y - geometry[plotFrame].origin.y
                                        if let date: Date = proxy.value(atX: xPos) {
                                            let cal = Calendar.current
                                            hoveredDay = tracker.dailyUsage.first {
                                                cal.isDate($0.date, inSameDayAs: date)
                                            }
                                            tooltipPosition = CGPoint(x: location.x, y: yPos)
                                        }
                                    case .ended:
                                        hoveredDay = nil
                                    }
                                }
                        }
                    }
                    
                    // Tooltip
                    if let day = hoveredDay {
                        dailyTooltipView(day: day)
                            .offset(
                                x: tooltipPosition.x - 60,
                                y: max(0, tooltipPosition.y - 65)
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                    }
                }
            }
        }
    }
    
    private func barColor(for item: DailyUsage) -> Color {
        if hoveredDay?.id == item.id {
            return .blue
        } else if hoveredDay != nil {
            return .blue.opacity(ChartTooltipConfiguration.dimmedOpacity)
        } else {
            return .blue.opacity(0.8)
        }
    }
    
    private func dailyTooltipView(day: DailyUsage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatTooltipDate(day.date))
                .font(.caption.weight(.semibold))
            HStack(spacing: 4) {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                Text("\(day.requests) credits")
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
    
    // MARK: - All Models Catalog
    
    private var allModelsCatalogSection: some View {
        let multipliers = multiplierService.effectiveMultipliers()
        let usageByModel = tracker.currentUsage?.usageByModel ?? [:]
        let catalog = ModelMultiplierService.buildCatalog(
            knownMultipliers: multipliers,
            usageByModel: usageByModel
        )
        
        return card {
            VStack(alignment: .leading, spacing: 12) {
                Label("All Models", systemImage: "cpu")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                
                if catalog.isEmpty {
                    Text(DetailedStatsEmptyState.noModels)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    modelCatalogGrid(entries: catalog)
                }
            }
        }
    }
    
    private func modelCatalogGrid(entries: [ModelCatalogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Model").frame(minWidth: 160, alignment: .leading)
                Text("Multiplier").frame(width: 80, alignment: .trailing)
                Text("Usage").frame(width: 70, alignment: .trailing)
                Text("Status").frame(width: 80, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ForEach(entries) { entry in
                HStack(spacing: 0) {
                    Text(entry.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 160, alignment: .leading)
                    
                    Text(CopilotModelMultipliers.formatMultiplier(entry.multiplier))
                        .font(.body.monospacedDigit().weight(.medium))
                        .foregroundColor(multiplierColor(entry.multiplier))
                        .frame(width: 80, alignment: .trailing)
                    
                    Group {
                        if entry.usage > 0 {
                            Text(formatQty(entry.usage))
                        } else {
                            Text("—").foregroundColor(.secondary)
                        }
                    }
                    .font(.body.monospacedDigit())
                    .frame(width: 70, alignment: .trailing)
                    
                    statusBadge(entry.status)
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.body)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
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
            case .used:      return ("Used", .green)
            case .available: return ("Available", .secondary)
            case .free:      return ("Free", .blue)
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
    
    // MARK: - Multiplier Section
    
    private var multiplierSection: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Model Multipliers", systemImage: "function")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Updated: \(multiplierService.lastUpdateDescription)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Legend row
                HStack(spacing: 14) {
                    multiplierLegendItem(label: "< 1x", color: .blue)
                    multiplierLegendItem(label: "1x", color: .primary)
                    multiplierLegendItem(label: "2–10x", color: .orange)
                    multiplierLegendItem(label: "> 10x", color: .red)
                }
                .font(.caption)
                
                // Action row
                HStack(spacing: 12) {
                    Button {
                        multiplierService.multipliersURL = multipliersURL
                        Task { await updateMultipliers() }
                    } label: {
                        HStack(spacing: 4) {
                            if isUpdatingMultipliers {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            Text("Update Multipliers")
                                .font(.caption)
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
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMultiplierConfig.toggle()
                        }
                    } label: {
                        Label(
                            showMultiplierConfig ? "Hide Config" : "Config",
                            systemImage: showMultiplierConfig ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                // Collapsible config
                if showMultiplierConfig {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
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
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
    
    // MARK: - Product Breakdown
    
    private func productBreakdownSection(usage: UsageResponse) -> some View {
        let byProduct = usage.usageByProduct.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }
        
        guard !byProduct.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Usage by Product", systemImage: "shippingbox")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(byProduct, id: \.key) { product, count in
                        HStack {
                            Text(product)
                                .font(.body)
                            Spacer()
                            Text(String(format: "%.0f credits", count))
                                .font(.body.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        )
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        Group {
            if let lastUpdate = tracker.lastUpdateTime {
                Text("Last updated: \(formatDate(lastUpdate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Reusable Components
    
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
    
    private func capsuleBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
    
    private func metricColumn(label: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
        }
    }
    
    private func multiplierLegendItem(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundColor(.secondary)
        }
    }
    
    // MARK: - Multiplier Update Logic
    
    private func updateMultipliers() async {
        isUpdatingMultipliers = true
        multiplierUpdateError = nil
        multiplierUpdateSuccess = false
        
        do {
            _ = try await multiplierService.fetchMultipliers()
            multiplierUpdateSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                multiplierUpdateSuccess = false
            }
        } catch {
            multiplierUpdateError = error.localizedDescription
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                multiplierUpdateError = nil
            }
        }
        
        isUpdatingMultipliers = false
    }
    
    // MARK: - Helpers
    
    // AIDEV-NOTE: Color thresholds updated June 2026 — multipliers now reach 57x (GPT-5.5).
    private func multiplierColor(_ multiplier: Double) -> Color {
        if multiplier == 0     { return .green  }  // legacy "Included" (0.0)
        if multiplier < 1      { return .blue   }  // 0.33x cheap models
        if multiplier == 1     { return .primary }  // 1x standard
        if multiplier <= 10    { return .orange }  // 2x–10x premium
        return .red                                 // 11x+ expensive (Opus, GPT-5.5…)
    }
    
    private func statusColor(percentage: Double) -> Color {
        if percentage >= 90    { return .red }
        if percentage >= 80    { return .orange }
        if percentage >= 60    { return .yellow }
        return .green
    }
    
    private func spendingBudgetColor(percent: Double) -> Color {
        if percent >= 100      { return .red }
        if percent >= 80       { return .orange }
        if percent >= 60       { return .yellow }
        return .green
    }
    
    private func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
    
    private func formatQty(_ value: Double) -> String {
        if value == 0 { return "0" }
        if value < 1 { return String(format: "%.2f", value) }
        if value == floor(value) { return String(format: "%.0f", value) }
        return String(format: "%.2f", value)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private func formatTooltipDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = ChartTooltipConfiguration.dateFormat
        return f.string(from: date)
    }
    
    private func clamp(_ value: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lo), hi)
    }
}

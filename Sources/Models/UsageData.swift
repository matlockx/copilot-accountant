import Foundation

/// Represents usage data for a specific product/model
struct UsageItem: Codable, Identifiable {
    let id = UUID()
    let product: String
    let sku: String
    let model: String
    let unitType: String
    let pricePerUnit: Double
    let grossQuantity: Double
    let grossAmount: Double
    let discountQuantity: Double
    let discountAmount: Double
    let netQuantity: Double
    let netAmount: Double
    
    enum CodingKeys: String, CodingKey {
        case product, sku, model, unitType, pricePerUnit
        case grossQuantity, grossAmount, discountQuantity, discountAmount
        case netQuantity, netAmount
    }
}

/// Time period for usage data
struct TimePeriod: Codable {
    let year: Int
    let month: Int?
    let day: Int?
}

/// Complete usage response from GitHub API
struct UsageResponse: Codable {
    let timePeriod: TimePeriod
    let user: String
    let product: String?
    let model: String?
    let usageItems: [UsageItem]
    
    /// Total premium requests used (grossQuantity = actual usage, netQuantity = billed after discounts)
    var totalRequests: Int {
        Int(usageItems.reduce(0) { $0 + $1.grossQuantity }.rounded())
    }
    
    /// Usage breakdown by model (sorted by count descending)
    var usageByModel: [String: Double] {
        var result: [String: Double] = [:]
        for item in usageItems {
            result[item.model, default: 0] += item.grossQuantity
        }
        return result
    }
    
    /// Usage breakdown by product
    var usageByProduct: [String: Double] {
        var result: [String: Double] = [:]
        for item in usageItems {
            result[item.product, default: 0] += item.grossQuantity
        }
        return result
    }
}

/// Daily usage data for charting
struct DailyUsage: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let requests: Int
    
    enum CodingKeys: String, CodingKey {
        case date, requests
    }
}

/// Model usage breakdown for visualization
struct ModelUsage: Identifiable {
    let id = UUID()
    let modelName: String
    let requestCount: Double
    let percentage: Double
}

struct BillingSummary: Equatable {
    let includedRequests: Int
    let usedRequests: Int
    let overageRequests: Int
    let grossCost: Double
    let netCost: Double
    let discountAmount: Double
    
    /// Requests that count against included quota
    var includedUsed: Double {
        Double(min(usedRequests, includedRequests))
    }
    
    /// Percentage of included quota used
    var includedPercentage: Double {
        guard includedRequests > 0 else { return 0 }
        return (includedUsed / Double(includedRequests)) * 100
    }
}

/// Per-model billing breakdown showing included vs billed requests
struct ModelBillingDetail: Identifiable {
    let id = UUID()
    let model: String
    let totalRequests: Double       // Total requests (grossQuantity, already multiplier-adjusted by API)
    let includedRequests: Double    // Requests covered by plan
    let billedRequests: Double      // Overage requests
    let grossAmount: Double         // What it would cost at full price
    let billedAmount: Double        // Actually charged (netAmount)
    let pricePerUnit: Double        // Price per request for this model
    let multiplier: Double          // Informational: Copilot premium request multiplier for this model
}

/// GitHub Copilot model multipliers for premium request billing
/// Reference: https://docs.github.com/en/copilot/concepts/billing/copilot-requests#model-multipliers
enum CopilotModelMultipliers {
    /// Known model multipliers from GitHub docs (for paid plans)
    static let multipliers: [String: Double] = [
        // Claude models
        "Claude Haiku 4.5": 0.33,
        "Claude Opus 4.5": 3.0,
        "Claude Opus 4.6": 3.0,
        "Claude Opus 4.6 (fast mode)": 30.0,
        "Claude Sonnet 4": 1.0,
        "Claude Sonnet 4.5": 1.0,
        "Claude Sonnet 4.6": 1.0,
        
        // Gemini models
        "Gemini 2.5 Pro": 1.0,
        "Gemini 3 Flash": 0.33,
        "Gemini 3 Pro": 1.0,
        "Gemini 3.1 Pro": 1.0,
        
        // GPT models (included/free on paid plans)
        "GPT-4.1": 0.0,
        "GPT-4o": 0.0,
        "GPT-5 mini": 0.0,
        "GPT-5.1": 1.0,
        "GPT-5.1-Codex": 1.0,
        "GPT-5.1-Codex-Mini": 0.33,
        "GPT-5.1-Codex-Max": 1.0,
        "GPT-5.2": 1.0,
        "GPT-5.2-Codex": 1.0,
        "GPT-5.3-Codex": 1.0,
        "GPT-5.4": 1.0,
        "GPT-5.4 mini": 0.33,
        
        // Other models
        "Grok Code Fast 1": 0.25,
        "Raptor mini": 0.0,
    ]
    
    /// Get multiplier for a model name (supports partial matching)
    static func multiplier(for modelName: String) -> Double {
        // Direct match
        if let mult = multipliers[modelName] {
            return mult
        }
        
        // Partial match (case-insensitive)
        let lowercased = modelName.lowercased()
        
        // Claude models
        if lowercased.contains("opus") {
            if lowercased.contains("fast") {
                return 30.0
            }
            return 3.0
        }
        if lowercased.contains("sonnet") {
            return 1.0
        }
        if lowercased.contains("haiku") {
            return 0.33
        }
        
        // GPT models - check for included models
        if lowercased.contains("gpt-4o") || lowercased.contains("gpt-4.1") || lowercased.contains("gpt-5 mini") {
            return 0.0
        }
        if lowercased.contains("gpt-5") {
            if lowercased.contains("mini") {
                return 0.33
            }
            return 1.0
        }
        
        // Gemini models
        if lowercased.contains("gemini") {
            if lowercased.contains("flash") {
                return 0.33
            }
            return 1.0
        }
        
        // Default to 1.0 for unknown models
        return 1.0
    }
    
    /// Format multiplier for display
    static func formatMultiplier(_ multiplier: Double) -> String {
        if multiplier == 0 {
            return "Included"
        } else if multiplier < 1 {
            return String(format: "%.2fx", multiplier)
        } else if multiplier == floor(multiplier) {
            return String(format: "%.0fx", multiplier)
        } else {
            return String(format: "%.1fx", multiplier)
        }
    }
}

extension UsageResponse {
    var totalGrossCost: Double {
        usageItems.reduce(0) { $0 + $1.grossAmount }
    }

    var totalNetCost: Double {
        usageItems.reduce(0) { $0 + $1.netAmount }
    }

    var totalDiscountAmount: Double {
        usageItems.reduce(0) { $0 + $1.discountAmount }
    }

    var modelCostFactors: [String: Double] {
        let unitPrices = Dictionary(grouping: usageItems, by: \ .model)
            .compactMapValues { items in items.first?.pricePerUnit }

        guard let cheapest = unitPrices.values.min(), cheapest > 0 else { return [:] }

        return unitPrices.mapValues { $0 / cheapest }
    }

    var hasMeaningfulModelFactors: Bool {
        Set(usageItems.map { $0.pricePerUnit }).count > 1
    }

    func billingSummary(includedRequests: Int) -> BillingSummary {
        let used = totalRequests
        return BillingSummary(
            includedRequests: includedRequests,
            usedRequests: used,
            overageRequests: max(0, used - includedRequests),
            grossCost: totalGrossCost,
            netCost: totalNetCost,
            discountAmount: totalDiscountAmount
        )
    }
    
    /// Standard price per premium request (from first usage item, typically $0.04)
    var pricePerRequest: Double {
        usageItems.first?.pricePerUnit ?? 0.04
    }
    
    /// Check if all models have the same price
    var allModelsSamePrice: Bool {
        let prices = Set(usageItems.map { $0.pricePerUnit })
        return prices.count <= 1
    }
    
    /// Billing period description (e.g., "Mar 1 - Mar 31, 2026")
    var billingPeriodDescription: String {
        let year = timePeriod.year
        guard let month = timePeriod.month else {
            return "Year \(year)"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: components),
              let endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) else {
            return "Month \(month), \(year)"
        }
        
        let monthName = dateFormatter.string(from: startDate)
        let lastDay = calendar.component(.day, from: endDate)
        
        return "\(monthName) 1 - \(monthName) \(lastDay), \(year)"
    }
    
    /// Reset date (first day of next month)
    var resetDate: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = timePeriod.year
        components.month = (timePeriod.month ?? 1) + 1
        components.day = 1
        
        // Handle year rollover
        if components.month! > 12 {
            components.month = 1
            components.year = components.year! + 1
        }
        
        return calendar.date(from: components) ?? Date()
    }
    
    /// Days until usage resets
    var daysUntilReset: Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: resetDate)
        return max(0, components.day ?? 0)
    }
    
    /// Formatted reset date string (e.g., "April 1, 2026")
    var resetDateDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: resetDate)
    }
    
    /// Per-model billing breakdown with included vs billed split
    /// GitHub reports netQuantity as billed (overage) requests and grossQuantity as total requests
    /// The includedRequests for each model is grossQuantity - netQuantity (what was covered by plan)
    func modelBillingDetails() -> [ModelBillingDetail] {
        // Group usage items by model and aggregate
        let byModel = Dictionary(grouping: usageItems, by: \.model)
        
        var details: [ModelBillingDetail] = []
        
        for (model, items) in byModel {
            let totalRequests = items.reduce(0.0) { $0 + $1.grossQuantity }
            let billedRequests = items.reduce(0.0) { $0 + $1.netQuantity }
            let includedRequests = totalRequests - billedRequests
            let grossAmount = items.reduce(0.0) { $0 + $1.grossAmount }
            let billedAmount = items.reduce(0.0) { $0 + $1.netAmount }
            let pricePerUnit = items.first?.pricePerUnit ?? 0.04
            let multiplier = CopilotModelMultipliers.multiplier(for: model)
            
            details.append(ModelBillingDetail(
                model: model,
                totalRequests: totalRequests,
                includedRequests: includedRequests,
                billedRequests: billedRequests,
                grossAmount: grossAmount,
                billedAmount: billedAmount,
                pricePerUnit: pricePerUnit,
                multiplier: multiplier
            ))
        }
        
        // Sort by total requests descending, then by model name
        return details.sorted { lhs, rhs in
            if lhs.totalRequests != rhs.totalRequests {
                return lhs.totalRequests > rhs.totalRequests
            }
            return lhs.model < rhs.model
        }
    }
}

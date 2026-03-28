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
            netCost: totalNetCost
        )
    }
}

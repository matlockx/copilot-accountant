import Foundation

/// Configuration for the model multiplier update feature
struct ModelMultiplierConfiguration {
    /// Default URL to fetch Copilot model multipliers from
    static let defaultMultipliersURL = "https://docs.github.com/en/copilot/concepts/billing/copilot-requests"
    
    /// UserDefaults key for the user-configured multiplier URL
    static let urlKey = "modelMultipliersURL"
    
    /// UserDefaults key for cached multipliers
    static let cacheKey = "cachedModelMultipliers"
    
    /// UserDefaults key for cache timestamp
    static let cacheTimestampKey = "cachedModelMultipliersTimestamp"
    
    /// Maximum cache age before suggesting refresh (in seconds) - 24 hours
    static let maxCacheAgeSeconds: TimeInterval = 86400
    
    /// Minimum number of models expected in a valid parse result
    static let minimumExpectedModels = 5
}

/// Status of a model in the catalog
enum ModelStatus: String, Codable {
    case used       // Model was used by this account
    case available  // Model is available but not used
    case free       // Model is included/free on paid plans
}

/// A model entry in the full catalog
struct ModelCatalogEntry: Identifiable {
    let id = UUID()
    let name: String
    let multiplier: Double
    let usage: Double       // 0 if not used
    let status: ModelStatus
}

/// Service for dynamically fetching and caching GitHub Copilot model multipliers
class ModelMultiplierService: ObservableObject {
    static let shared = ModelMultiplierService()
    
    private let log = LogService.shared
    private let userDefaults = UserDefaults.standard
    
    /// The URL to fetch multipliers from (user-configurable, persisted)
    var multipliersURL: String {
        get {
            let stored = userDefaults.string(forKey: ModelMultiplierConfiguration.urlKey)
            return (stored?.isEmpty ?? true) ? ModelMultiplierConfiguration.defaultMultipliersURL : stored!
        }
        set {
            userDefaults.set(newValue, forKey: ModelMultiplierConfiguration.urlKey)
        }
    }
    
    /// Last update timestamp (nil if never updated)
    var lastUpdateTime: Date? {
        let timestamp = userDefaults.double(forKey: ModelMultiplierConfiguration.cacheTimestampKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    /// Whether cached data is stale (older than maxCacheAge)
    var isCacheStale: Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) > ModelMultiplierConfiguration.maxCacheAgeSeconds
    }
    
    /// Formatted "last updated" string
    var lastUpdateDescription: String {
        guard let lastUpdate = lastUpdateTime else { return "Never" }
        let elapsed = Date().timeIntervalSince(lastUpdate)
        if elapsed < 60 {
            return "Just now"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(elapsed / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    /// Load cached multipliers from UserDefaults, or return nil if no cache
    func loadCachedMultipliers() -> [String: Double]? {
        guard let data = userDefaults.data(forKey: ModelMultiplierConfiguration.cacheKey),
              let cached = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return nil
        }
        return cached
    }
    
    /// Save multipliers to cache
    func saveToCache(_ multipliers: [String: Double]) {
        if let data = try? JSONEncoder().encode(multipliers) {
            userDefaults.set(data, forKey: ModelMultiplierConfiguration.cacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: ModelMultiplierConfiguration.cacheTimestampKey)
        }
    }
    
    /// Get the effective multipliers (cached > hardcoded fallback)
    func effectiveMultipliers() -> [String: Double] {
        if let cached = loadCachedMultipliers() {
            return cached
        }
        return CopilotModelMultipliers.multipliers
    }
    
    /// Fetch latest multipliers from GitHub docs
    /// Returns the parsed multipliers dictionary, or throws on failure
    func fetchMultipliers() async throws -> [String: Double] {
        let url = multipliersURL
        log.info("Fetching model multipliers from: \(url)")
        
        guard let requestURL = URL(string: url) else {
            throw MultiplierFetchError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            log.error("Failed to fetch multipliers: HTTP \(statusCode)")
            throw MultiplierFetchError.httpError(statusCode)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw MultiplierFetchError.invalidData
        }
        
        log.info("Received \(data.count) bytes from multipliers page")
        
        let parsed = parseMultipliers(html: html)
        
        guard parsed.count >= ModelMultiplierConfiguration.minimumExpectedModels else {
            log.warning("Parsed only \(parsed.count) models, expected at least \(ModelMultiplierConfiguration.minimumExpectedModels)")
            throw MultiplierFetchError.insufficientData(parsed.count)
        }
        
        log.info("Successfully parsed \(parsed.count) model multipliers")
        
        // Merge with existing hardcoded values (parsed values take priority)
        var merged = CopilotModelMultipliers.multipliers
        for (model, multiplier) in parsed {
            merged[model] = multiplier
        }
        
        // Save to cache
        saveToCache(merged)
        
        return merged
    }
    
    /// Parse model multipliers from the GitHub docs HTML
    /// Handles HTML tables with <table>, <tr>, <th>, <td> elements
    /// Also supports markdown pipe tables as fallback
    func parseMultipliers(html: String) -> [String: Double] {
        // Try HTML table parsing first
        let htmlResult = parseHTMLTable(html: html)
        if !htmlResult.isEmpty {
            return htmlResult
        }
        
        // Fallback: try markdown pipe table parsing
        return parseMarkdownTable(html: html)
    }
    
    /// Parse HTML <table> elements for model multiplier data
    /// Looks for a table containing "Model" and "Multiplier for" (or "paid plans") in headers
    private func parseHTMLTable(html: String) -> [String: Double] {
        var result: [String: Double] = [:]
        
        // Extract all <table>...</table> blocks
        var searchRange = html.startIndex..<html.endIndex
        while let tableStart = html.range(of: "<table", options: .caseInsensitive, range: searchRange),
              let tableEnd = html.range(of: "</table>", options: .caseInsensitive, range: tableStart.lowerBound..<html.endIndex) {
            
            let tableHTML = String(html[tableStart.lowerBound..<tableEnd.upperBound])
            
            // Check if this table has the right headers (Model + Multiplier)
            if tableHTML.contains("Model") && (tableHTML.contains("Multiplier for") || tableHTML.contains("paid plans")) {
                result = parseHTMLTableContent(tableHTML)
                if !result.isEmpty {
                    return result
                }
            }
            
            searchRange = tableEnd.upperBound..<html.endIndex
        }
        
        return result
    }
    
    /// Parse the content of an HTML table that contains model multiplier data
    private func parseHTMLTableContent(_ tableHTML: String) -> [String: Double] {
        var result: [String: Double] = [:]
        
        // Find which column index has the "paid plans" multiplier
        // Parse header row to determine column positions
        var paidPlansColumnIndex = 1 // default: second column (0-indexed from data cells)
        
        // Extract header cells from <thead> or first <tr>
        if let theadContent = extractBetween(tableHTML, start: "<thead", end: "</thead>") {
            let headerCells = extractAllCellContents(theadContent)
            for (index, cell) in headerCells.enumerated() {
                if cell.contains("paid plans") || (cell.contains("Multiplier") && !cell.contains("Free")) {
                    // This is the paid plans column; but we need the index relative to data columns
                    // The model name is in the first column (index 0)
                    paidPlansColumnIndex = index
                }
            }
        }
        
        // Extract body rows from <tbody> or all <tr> after the header
        let rowsHTML: String
        if let tbodyContent = extractBetween(tableHTML, start: "<tbody", end: "</tbody>") {
            rowsHTML = tbodyContent
        } else {
            rowsHTML = tableHTML
        }
        
        // Find all <tr> elements in the body
        var rowSearch = rowsHTML.startIndex..<rowsHTML.endIndex
        while let trStart = rowsHTML.range(of: "<tr", options: .caseInsensitive, range: rowSearch),
              let trEnd = rowsHTML.range(of: "</tr>", options: .caseInsensitive, range: trStart.lowerBound..<rowsHTML.endIndex) {
            
            let rowHTML = String(rowsHTML[trStart.lowerBound..<trEnd.upperBound])
            let cells = extractAllCellContents(rowHTML)
            
            // Skip header rows (contain "Model" text or fewer than 2 cells)
            guard cells.count >= 2 else {
                rowSearch = trEnd.upperBound..<rowsHTML.endIndex
                continue
            }
            
            let modelName = cells[0].trimmingCharacters(in: .whitespaces)
            
            // Skip actual header rows
            guard !modelName.isEmpty, modelName != "Model" else {
                rowSearch = trEnd.upperBound..<rowsHTML.endIndex
                continue
            }
            
            // Get the multiplier value from the right column
            let multiplierIndex = min(paidPlansColumnIndex, cells.count - 1)
            let multiplierText = cells[multiplierIndex]
            
            if let value = parseMultiplierValue(multiplierText) {
                result[modelName] = value
            }
            
            rowSearch = trEnd.upperBound..<rowsHTML.endIndex
        }
        
        return result
    }
    
    /// Extract text content from all <th> and <td> cells in an HTML fragment, stripping HTML tags
    private func extractAllCellContents(_ html: String) -> [String] {
        var cells: [String] = []
        var search = html.startIndex..<html.endIndex
        
        while search.lowerBound < html.endIndex {
            // Find next <th or <td
            var nextCell: Range<String.Index>? = nil
            var endTag: String = ""
            
            let thRange = html.range(of: "<th", options: .caseInsensitive, range: search)
            let tdRange = html.range(of: "<td", options: .caseInsensitive, range: search)
            
            if let th = thRange, let td = tdRange {
                if th.lowerBound < td.lowerBound {
                    nextCell = th; endTag = "</th>"
                } else {
                    nextCell = td; endTag = "</td>"
                }
            } else if let th = thRange {
                nextCell = th; endTag = "</th>"
            } else if let td = tdRange {
                nextCell = td; endTag = "</td>"
            }
            
            guard let cellStart = nextCell else { break }
            
            // Find the > that closes the opening tag
            guard let openTagEnd = html.range(of: ">", range: cellStart.lowerBound..<html.endIndex) else { break }
            
            // Find the closing tag
            guard let closeTag = html.range(of: endTag, options: .caseInsensitive, range: openTagEnd.upperBound..<html.endIndex) else { break }
            
            let content = String(html[openTagEnd.upperBound..<closeTag.lowerBound])
            cells.append(stripHTMLTags(content))
            
            search = closeTag.upperBound..<html.endIndex
        }
        
        return cells
    }
    
    /// Strip HTML tags from a string, returning plain text
    private func stripHTMLTags(_ html: String) -> String {
        var result = html
        // Remove all <...> tags
        while let tagStart = result.range(of: "<"),
              let tagEnd = result.range(of: ">", range: tagStart.lowerBound..<result.endIndex) {
            result.removeSubrange(tagStart.lowerBound..<tagEnd.upperBound)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract content between a start tag and end tag in HTML
    private func extractBetween(_ html: String, start: String, end: String) -> String? {
        guard let startRange = html.range(of: start, options: .caseInsensitive) else { return nil }
        // Find the > that closes the start tag
        guard let openEnd = html.range(of: ">", range: startRange.lowerBound..<html.endIndex) else { return nil }
        guard let endRange = html.range(of: end, options: .caseInsensitive, range: openEnd.upperBound..<html.endIndex) else { return nil }
        return String(html[openEnd.upperBound..<endRange.lowerBound])
    }
    
    /// Fallback: Parse markdown pipe tables
    private func parseMarkdownTable(html: String) -> [String: Double] {
        var result: [String: Double] = [:]
        let lines = html.components(separatedBy: "\n")
        
        var inMultiplierTable = false
        var headerFound = false
        var modelColumnIndex = -1
        var multiplierColumnIndex = -1
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("Model") && trimmed.contains("Multiplier for") && trimmed.contains("|") {
                inMultiplierTable = true
                headerFound = true
                let columns = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                for (index, col) in columns.enumerated() {
                    if col == "Model" { modelColumnIndex = index }
                    else if col.contains("paid plans") { multiplierColumnIndex = index }
                }
                continue
            }
            
            if inMultiplierTable && trimmed.hasPrefix("|") && trimmed.contains("---") { continue }
            
            if inMultiplierTable && headerFound && trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                let columns = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard modelColumnIndex >= 0, multiplierColumnIndex >= 0,
                      modelColumnIndex < columns.count, multiplierColumnIndex < columns.count else { continue }
                let modelName = columns[modelColumnIndex]
                let multiplierText = columns[multiplierColumnIndex]
                guard !modelName.isEmpty, modelName != "Model", !modelName.contains("---") else { continue }
                if let value = parseMultiplierValue(multiplierText) {
                    result[modelName] = value
                }
            }
            
            if inMultiplierTable && headerFound && !trimmed.hasPrefix("|") && !trimmed.isEmpty
                && !trimmed.hasPrefix("<") && !trimmed.hasPrefix("#") {
                if !result.isEmpty { break }
            }
        }
        
        return result
    }
    
    /// Parse a multiplier value from text like "3", "0.33", "0", "Not applicable"
    func parseMultiplierValue(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        
        if cleaned.isEmpty || cleaned == "Not applicable" || cleaned == "N/A" {
            return nil
        }
        
        return Double(cleaned)
    }
    
    /// Build a full model catalog merging known models with actual usage data
    static func buildCatalog(
        knownMultipliers: [String: Double],
        usageByModel: [String: Double]
    ) -> [ModelCatalogEntry] {
        var entries: [ModelCatalogEntry] = []
        var processedModels = Set<String>()
        
        // First: add all models from usage data (these are "used")
        for (model, usage) in usageByModel {
            let multiplier = knownMultipliers[model] ?? CopilotModelMultipliers.multiplier(for: model)
            let status: ModelStatus = multiplier == 0 ? .free : .used
            entries.append(ModelCatalogEntry(
                name: model,
                multiplier: multiplier,
                usage: usage,
                status: status
            ))
            processedModels.insert(model)
        }
        
        // Second: add all known models not already in usage data
        for (model, multiplier) in knownMultipliers {
            guard !processedModels.contains(model) else { continue }
            let status: ModelStatus = multiplier == 0 ? .free : .available
            entries.append(ModelCatalogEntry(
                name: model,
                multiplier: multiplier,
                usage: 0,
                status: status
            ))
            processedModels.insert(model)
        }
        
        // Sort: used first (by usage desc), then free, then available (alphabetical)
        return entries.sorted { lhs, rhs in
            // Used models first
            if lhs.usage > 0 && rhs.usage == 0 { return true }
            if lhs.usage == 0 && rhs.usage > 0 { return false }
            
            // Among used models, sort by usage descending
            if lhs.usage > 0 && rhs.usage > 0 {
                if lhs.usage != rhs.usage { return lhs.usage > rhs.usage }
                return lhs.name < rhs.name
            }
            
            // Among unused: free before available
            if lhs.status != rhs.status {
                if lhs.status == .free { return true }
                if rhs.status == .free { return false }
            }
            
            // Alphabetical within same status
            return lhs.name < rhs.name
        }
    }
    
    enum MultiplierFetchError: LocalizedError {
        case invalidURL
        case httpError(Int)
        case invalidData
        case insufficientData(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL for multipliers page"
            case .httpError(let code):
                return "Failed to fetch multipliers (HTTP \(code))"
            case .invalidData:
                return "Could not read response data"
            case .insufficientData(let count):
                return "Only found \(count) models (expected at least \(ModelMultiplierConfiguration.minimumExpectedModels))"
            }
        }
    }
}

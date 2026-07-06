import Foundation

/// Service for interacting with GitHub API
class GitHubAPIService {
    private let baseURL = "https://api.github.com"
    // Use the latest API version as shown in GitHub docs
    private let apiVersion = "2022-11-28"
    private let log = LogService.shared
    
    // AIDEV-NOTE: Billing source tracks whether usage comes from a personal account
    // or an organization-managed Copilot license. Stored after successful fetch.
    enum BillingSource: Equatable, Codable {
        case personal
        case organization(String)
        case copilotQuota
        
        var description: String {
            switch self {
            case .personal: return "Personal"
            case .organization(let name): return "Organization: \(name)"
            case .copilotQuota: return "Copilot seat (org-managed)"
            }
        }
    }

    // AIDEV-NOTE: CopilotQuota comes from the internal /copilot_internal/user endpoint
    // (the same source the github.com Copilot settings page uses). It is the ONLY way
    // to get PER-USER premium request usage for enterprise-owned org seats — the public
    // billing REST API refuses per-user filtering for enterprise-owned orgs (403
    // "Organization admins for enterprise owned organizations cannot filter usage by
    // user"). Works with a classic token, no billing-admin permission needed.
    struct CopilotQuota: Equatable {
        let used: Int          // entitlement - remaining
        let entitlement: Int   // monthly premium-request allowance
        let remaining: Int
        let percentUsed: Double
        let unlimited: Bool
        let resetDate: String  // e.g. "2026-08-01"
        let plan: String       // copilot_plan, e.g. "business"
    }

    // AIDEV-NOTE: UsageResult carries the synthesized usage plus, for the quota source,
    // the monthly entitlement so the tracker can align its budget with GitHub's own limit.
    struct UsageResult {
        let usage: UsageResponse
        let source: BillingSource
        let monthlyEntitlement: Int?
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case noToken
        case invalidResponse
        case httpError(Int, String?)
        case decodingError(Error, String)
        case networkError(Error)
        case notFound(String)
        case unauthorized
        case forbidden(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noToken:
                return "No GitHub token found. Please configure your token in Settings."
            case .invalidResponse:
                return "Invalid response from GitHub API"
            case .httpError(let code, let body):
                if let body = body {
                    return "HTTP error \(code): \(body)"
                }
                return "HTTP error: \(code)"
            case .decodingError(let error, let body):
                return "Failed to decode response: \(error.localizedDescription). Body: \(body)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .notFound(let message):
                return "Not found: \(message). This may mean: 1) The token lacks required billing permissions, or 2) Copilot is not available on your plan."
            case .unauthorized:
                return "Unauthorized: Invalid or expired token. Please check your GitHub Personal Access Token."
            case .forbidden(let message):
                return "Forbidden: \(message). Your token may lack the required scopes (needs 'copilot' or 'read:billing' scope)."
            }
        }
    }
    
    /// First, verify the token works by checking the authenticated user
    func verifyToken(token: String) async throws -> String {
        log.info("Verifying token by fetching authenticated user")
        
        guard let url = URL(string: "\(baseURL)/user") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "<binary>"
        log.debug("User endpoint response (\(httpResponse.statusCode)): \(responseBody)")
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(httpResponse.statusCode, responseBody)
        }
        
        // Parse to get the login
        struct UserResponse: Decodable {
            let login: String
        }
        
        let user = try JSONDecoder().decode(UserResponse.self, from: data)
        log.info("Token verified for user: \(user.login)")
        return user.login
    }
    
    // AIDEV-NOTE: GitHub has three billing endpoints with the same schema:
    //   1. /settings/billing/premium_request/usage — legacy premium requests
    //   2. /settings/billing/ai_credit/usage — NEW (June 2026), preferred
    //   Both return { timePeriod, user, usageItems: [{product, sku, model, grossQuantity, ...}] }
    // We use ai_credit as the primary endpoint, falling back to org billing for
    // users with organization-managed Copilot licenses.
    
    /// Fetch AI credit usage for a personal account (current month)
    func fetchUsage(username: String, token: String) async throws -> UsageResponse {
        log.info("Fetching AI credit usage for user: \(username)")
        let endpoint = "/users/\(username)/settings/billing/ai_credit/usage?product=copilot"
        return try await makeRequest(endpoint: endpoint, token: token)
    }
    
    /// Fetch AI credit usage for a specific year and month
    func fetchUsage(username: String, token: String, year: Int, month: Int) async throws -> UsageResponse {
        log.info("Fetching AI credit usage for user: \(username), year: \(year), month: \(month)")
        let endpoint = "/users/\(username)/settings/billing/ai_credit/usage?year=\(year)&month=\(month)&product=copilot"
        return try await makeRequest(endpoint: endpoint, token: token)
    }
    
    /// Fetch AI credit usage for an org-managed Copilot license
    func fetchOrgUsage(org: String, username: String, token: String, year: Int, month: Int) async throws -> UsageResponse {
        log.info("Fetching org AI credit usage for org: \(org), user: \(username)")
        let endpoint = "/organizations/\(org)/settings/billing/ai_credit/usage?year=\(year)&month=\(month)&user=\(username)&product=copilot"
        let response: UsageResponse = try await makeRequest(endpoint: endpoint, token: token)
        log.info("Org AI credit API returned \(response.usageItems.count) items for \(username) in \(org)")
        return response
    }
    
    // AIDEV-NOTE: Fetches per-user Copilot quota from the internal endpoint used by
    // editors and the github.com Copilot settings page. Needs the Editor-Version header.
    func fetchCopilotQuota(token: String) async throws -> CopilotQuota {
        log.info("Fetching Copilot quota from /copilot_internal/user")
        struct Snapshot: Decodable {
            let remaining: Double
            let entitlement: Double
            let percentRemaining: Double
            let unlimited: Bool
            let hasQuota: Bool
        }
        struct Snapshots: Decodable { let premiumInteractions: Snapshot? }
        struct Response: Decodable {
            let copilotPlan: String?
            let quotaResetDate: String?
            let quotaSnapshots: Snapshots?
        }
        let resp: Response = try await makeRequest(
            endpoint: "/copilot_internal/user", token: token,
            extraHeaders: ["Editor-Version": "CopilotAccountant/1.0"]
        )
        guard let pi = resp.quotaSnapshots?.premiumInteractions, pi.hasQuota else {
            throw APIError.notFound("No premium request quota found for this Copilot seat.")
        }
        let entitlement = Int(pi.entitlement.rounded())
        let remaining = Int(pi.remaining.rounded())
        let used = max(0, entitlement - remaining)
        let quota = CopilotQuota(
            used: used, entitlement: entitlement, remaining: remaining,
            percentUsed: max(0, 100.0 - pi.percentRemaining), unlimited: pi.unlimited,
            resetDate: resp.quotaResetDate ?? "", plan: resp.copilotPlan ?? ""
        )
        log.info("Copilot quota: used \(used)/\(entitlement) (\(String(format: "%.1f", quota.percentUsed))%), plan \(quota.plan)")
        return quota
    }

    // AIDEV-NOTE: Pure helper (unit-testable) — maps a CopilotQuota into the app's
    // UsageResponse so all downstream UI/alerts work unchanged. A single synthetic
    // premium-request UsageItem carries the used count as grossQuantity. No cost data
    // (quota endpoint has none), so the dollar budget is unavailable for this source.
    static func synthesizeUsage(from quota: CopilotQuota, username: String, year: Int, month: Int) -> UsageResponse {
        let item = UsageItem(
            product: "copilot", sku: "Copilot Premium Request", model: "premium requests",
            unitType: "requests", pricePerUnit: 0,
            grossQuantity: Double(quota.used), grossAmount: 0,
            discountQuantity: 0, discountAmount: 0, netQuantity: 0, netAmount: 0
        )
        return UsageResponse(
            timePeriod: TimePeriod(year: year, month: month, day: nil),
            user: username, product: "copilot", model: nil, usageItems: [item]
        )
    }

    /// Fetch organizations the user belongs to
    func fetchOrganizations(token: String) async throws -> [String] {
        log.info("Fetching user organizations")
        struct OrgResponse: Decodable {
            let login: String
        }
        let orgs: [OrgResponse] = try await makeRequest(endpoint: "/user/orgs", token: token)
        let orgNames = orgs.map { $0.login }
        log.info("User belongs to \(orgNames.count) organizations: \(orgNames.joined(separator: ", "))")
        return orgNames
    }
    
    // AIDEV-NOTE: fetchUsageWithFallback tries personal ai_credit billing first.
    // Org-managed Copilot licenses return 200 with an EMPTY usageItems list on the
    // personal endpoint (not 404), so we must fall back to org billing whenever the
    // personal response is missing OR empty (see shouldFallbackToOrg). The org
    // ai_credit endpoint requires the caller to be an org admin/owner — a plain
    // member gets 403, which we surface as a distinct, actionable error (cause #2).
    // Returns the response and the billing source (personal or org name).
    func fetchUsageWithFallback(username: String, token: String, year: Int, month: Int, organization: String = "") async throws -> UsageResult {
        log.info("Fetching usage (personal billing → copilot quota → org billing)")
        
        // 1. Try personal billing first (has cost + model breakdown for personal subs).
        do {
            let response = try await fetchUsage(username: username, token: token, year: year, month: month)
            if !Self.shouldFallbackToOrg(personalResponse: response) {
                log.info("Personal AI credit usage fetched successfully")
                return UsageResult(usage: response, source: .personal, monthlyEntitlement: nil)
            }
            log.info("Personal billing returned no usage items (likely org-managed), trying copilot quota...")
        } catch let error as APIError {
            switch error {
            case .notFound:
                log.info("Personal billing returned 404, trying copilot quota...")
            default:
                throw error
            }
        }
        
        // 2. Copilot quota endpoint — per-user usage for org/enterprise-managed seats.
        //    This is the only per-user source for enterprise-owned orgs (billing REST
        //    API blocks per-user filtering there).
        do {
            let quota = try await fetchCopilotQuota(token: token)
            let usage = Self.synthesizeUsage(from: quota, username: username, year: year, month: month)
            log.info("Using Copilot quota as usage source (\(quota.used)/\(quota.entitlement))")
            return UsageResult(usage: usage, source: .copilotQuota, monthlyEntitlement: quota.entitlement)
        } catch let error as APIError {
            log.info("Copilot quota unavailable (\(error.localizedDescription)), trying org billing...")
        }
        
        // 3. Fall back to org billing (requires org admin; unavailable per-user for
        //    enterprise-owned orgs). Prefer an explicitly-configured org.
        let orgs: [String]
        if !organization.isEmpty {
            log.info("Using configured organization: \(organization)")
            orgs = [organization]
        } else {
            orgs = try await fetchOrganizations(token: token)
            guard !orgs.isEmpty else {
                log.error("No organizations found, cannot fall back to org billing")
                throw APIError.notFound("No personal or organization Copilot billing found for user '\(username)'. Set your organization name in Settings, or ensure your token has billing read permissions.")
            }
        }
        
        // AIDEV-NOTE: track whether every org rejected us with 403 so we can tell the
        // user "you need org admin / billing permission" instead of "no data found".
        var sawForbidden = false
        for org in orgs {
            do {
                let response = try await fetchOrgUsage(org: org, username: username, token: token, year: year, month: month)
                if !response.usageItems.isEmpty {
                    log.info("Found Copilot usage in organization: \(org)")
                    return UsageResult(usage: response, source: .organization(org), monthlyEntitlement: nil)
                }
                log.info("Organization \(org) has no Copilot usage for \(username)")
            } catch let error as APIError {
                switch error {
                case .forbidden:
                    sawForbidden = true
                    log.info("Organization \(org) billing forbidden (not an admin?): \(error.localizedDescription)")
                    continue
                case .notFound:
                    log.info("Organization \(org) billing not accessible: \(error.localizedDescription)")
                    continue
                default:
                    throw error
                }
            }
        }
        
        if sawForbidden {
            throw APIError.forbidden("The GitHub billing API rejected access to your organization's usage. Reading org Copilot usage requires that you are an organization owner/admin (or billing manager) AND that your token has the organization 'Plan: Read-only' permission. Grant that permission to your token and try again.")
        }
        throw APIError.notFound("No Copilot billing data found in any organization. Your Copilot license may not be active or your token may lack billing permissions.")
    }

    // AIDEV-NOTE: Pure decision helper (fix A) — a personal ai_credit response with an
    // empty usageItems list means this account's Copilot is org-managed, so the caller
    // must fall back to org billing. Extracted as static/pure so it is unit-testable
    // without network access.
    static func shouldFallbackToOrg(personalResponse: UsageResponse) -> Bool {
        personalResponse.usageItems.isEmpty
    }
    
    /// Fetch daily usage for the current month
    /// AIDEV-NOTE: Uses the ai_credit endpoint with day parameter for per-day breakdown.
    /// Only fetches days up to today to minimize API calls.
    func fetchDailyUsage(username: String, token: String, billingSource: BillingSource) async throws -> [DailyUsage] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let today = calendar.component(.day, from: now)
        
        log.info("Fetching daily usage for \(year)-\(month) (days 1...\(today))")
        
        var dailyUsage: [DailyUsage] = []
        
        for day in 1...today {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                continue
            }
            do {
                let endpoint: String
                switch billingSource {
                case .personal:
                    endpoint = "/users/\(username)/settings/billing/ai_credit/usage?year=\(year)&month=\(month)&day=\(day)&product=copilot"
                case .organization(let org):
                    endpoint = "/organizations/\(org)/settings/billing/ai_credit/usage?year=\(year)&month=\(month)&day=\(day)&user=\(username)&product=copilot"
                case .copilotQuota:
                    // Quota endpoint has no per-day breakdown; skip daily charting.
                    return []
                }
                let response: UsageResponse = try await makeRequest(endpoint: endpoint, token: token)
                dailyUsage.append(DailyUsage(date: date, requests: response.totalRequests))
            } catch {
                log.warning("Failed to fetch usage for day \(day): \(error.localizedDescription)")
                dailyUsage.append(DailyUsage(date: date, requests: 0))
            }
        }
        
        return dailyUsage
    }
    
    /// Generic request method
    private func makeRequest<T: Decodable>(endpoint: String, token: String, extraHeaders: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            log.error("Invalid URL: \(baseURL + endpoint)")
            throw APIError.invalidURL
        }
        
        log.debug("Making request to: \(url.absoluteString)")
        log.debug("Token (first 10 chars): \(String(token.prefix(10)))...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        extraHeaders?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        log.debug("Request headers: Accept=application/vnd.github+json, X-GitHub-Api-Version=\(apiVersion)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                log.error("Invalid response type (not HTTPURLResponse)")
                throw APIError.invalidResponse
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? "<binary data>"
            log.debug("Response status: \(httpResponse.statusCode)")
            log.debug("Response body: \(responseBody)")
            
            switch httpResponse.statusCode {
            case 200...299:
                break // Success, continue to decode
            case 401:
                log.error("Unauthorized (401)")
                throw APIError.unauthorized
            case 403:
                log.error("Forbidden (403): \(responseBody)")
                throw APIError.forbidden(responseBody)
            case 404:
                log.error("Not found (404): \(responseBody)")
                throw APIError.notFound(responseBody)
            default:
                log.error("HTTP error \(httpResponse.statusCode): \(responseBody)")
                throw APIError.httpError(httpResponse.statusCode, responseBody)
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let result = try decoder.decode(T.self, from: data)
                log.info("Successfully decoded response")
                return result
            } catch {
                log.error("Decoding error: \(error)")
                log.error("Failed to decode body: \(responseBody)")
                throw APIError.decodingError(error, responseBody)
            }
        } catch let error as APIError {
            throw error
        } catch {
            log.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    /// Validate token by making a test request
    /// Returns success status, optional error message, and billing source if successful
    func validateToken(username: String, token: String, organization: String = "") async -> (success: Bool, error: String?, billingSource: BillingSource?) {
        log.info("Validating token for user: \(username)")
        
        // First verify the token works at all
        do {
            let actualUsername = try await verifyToken(token: token)
            log.info("Token is valid, authenticated as: \(actualUsername)")
            
            // Check if username matches
            if actualUsername.lowercased() != username.lowercased() {
                log.warning("Username mismatch: entered '\(username)' but token belongs to '\(actualUsername)'")
                return (false, "Token belongs to user '\(actualUsername)', not '\(username)'. Please use the correct username.", nil)
            }
        } catch {
            log.error("Token verification failed: \(error.localizedDescription)")
            return (false, error.localizedDescription, nil)
        }
        
        // Now try to fetch usage with personal→org fallback
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        do {
            let result = try await fetchUsageWithFallback(username: username, token: token, year: year, month: month, organization: organization)
            log.info("Token validation successful! Total requests: \(result.usage.totalRequests), source: \(result.source.description)")
            return (true, nil, result.source)
        } catch {
            log.error("Usage fetch failed: \(error.localizedDescription)")
            return (false, error.localizedDescription, nil)
        }
    }
}

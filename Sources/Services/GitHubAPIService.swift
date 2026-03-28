import Foundation

/// Service for interacting with GitHub API
class GitHubAPIService {
    private let baseURL = "https://api.github.com"
    // Use the latest API version as shown in GitHub docs
    private let apiVersion = "2022-11-28"
    private let log = LogService.shared
    
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
                return "Not found: \(message). This may mean: 1) Your Copilot is billed through an organization (not personal), 2) The token lacks required permissions, or 3) Premium requests feature is not available on your plan."
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
    
    /// Fetch premium request usage for current month
    func fetchUsage(username: String, token: String) async throws -> UsageResponse {
        log.info("Fetching usage for user: \(username)")
        let endpoint = "/users/\(username)/settings/billing/premium_request/usage"
        return try await makeRequest(endpoint: endpoint, token: token)
    }
    
    /// Fetch usage for a specific year and month
    func fetchUsage(username: String, token: String, year: Int, month: Int) async throws -> UsageResponse {
        log.info("Fetching usage for user: \(username), year: \(year), month: \(month)")
        let endpoint = "/users/\(username)/settings/billing/premium_request/usage?year=\(year)&month=\(month)"
        return try await makeRequest(endpoint: endpoint, token: token)
    }
    
    /// Fetch daily usage for the current month
    func fetchDailyUsage(username: String, token: String) async throws -> [DailyUsage] {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        log.info("Fetching daily usage for \(year)-\(month)")
        
        var dailyUsage: [DailyUsage] = []
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 31
        
        // Fetch data for each day of the month
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
               date <= now {
                do {
                    let endpoint = "/users/\(username)/settings/billing/premium_request/usage?year=\(year)&month=\(month)&day=\(day)"
                    let response: UsageResponse = try await makeRequest(endpoint: endpoint, token: token)
                    dailyUsage.append(DailyUsage(date: date, requests: response.totalRequests))
                } catch {
                    log.warning("Failed to fetch usage for day \(day): \(error.localizedDescription)")
                    // If a specific day fails, add zero usage
                    dailyUsage.append(DailyUsage(date: date, requests: 0))
                }
            }
        }
        
        return dailyUsage
    }
    
    /// Generic request method
    private func makeRequest<T: Decodable>(endpoint: String, token: String) async throws -> T {
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
    func validateToken(username: String, token: String) async -> (success: Bool, error: String?) {
        log.info("Validating token for user: \(username)")
        
        // First verify the token works at all
        do {
            let actualUsername = try await verifyToken(token: token)
            log.info("Token is valid, authenticated as: \(actualUsername)")
            
            // Check if username matches
            if actualUsername.lowercased() != username.lowercased() {
                log.warning("Username mismatch: entered '\(username)' but token belongs to '\(actualUsername)'")
                return (false, "Token belongs to user '\(actualUsername)', not '\(username)'. Please use the correct username.")
            }
        } catch {
            log.error("Token verification failed: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
        
        // Now try to fetch usage
        do {
            let usage = try await fetchUsage(username: username, token: token)
            log.info("Token validation successful! Total requests: \(usage.totalRequests)")
            return (true, nil)
        } catch {
            log.error("Usage fetch failed: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }
}

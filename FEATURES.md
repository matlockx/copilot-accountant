# Copilot Accountant - Feature Specification

> **This file is the source of truth for all features.**  
> Every feature listed here MUST have corresponding tests.  
> Do NOT add features without updating this file and adding tests.

## Version: 1.0.2
## Last Updated: 2026-03-28

---

## Core Features

### F001: Menu Bar Integration
**Status:** Implemented  
**Tests:** `Tests/MenuBarTests.swift`

- App runs as a menu bar utility (no dock icon)
- Displays usage percentage with color-coded emoji indicator
- **Shows one decimal place** (e.g., `🟢 28.7%` not `🟢 29%`)
- Status indicators:
  - 🟢 0-59% (Green/Safe)
  - 🟡 60-79% (Yellow/Moderate)  
  - 🟠 80-89% (Orange/High)
  - 🔴 90-100% (Red/Critical)
- Clicking icon shows dropdown popover with details
- **Popover closes when clicking outside** (global event monitor)

### F002: Usage Calculation
**Status:** Implemented  
**Tests:** `Tests/UsageCalculationTests.swift`

- Uses `grossQuantity` from API (NOT `netQuantity` which is 0 after discounts)
- Correctly sums usage across all models
- Calculates percentage based on user's configured budget
- Rounds total to nearest integer for display

### F003: Model Usage Breakdown
**Status:** Implemented  
**Tests:** `Tests/ModelUsageTests.swift`

- Shows breakdown by AI model (Claude Opus, Sonnet, GPT, etc.)
- **Stable sorting**: Primary by request count (descending), secondary by model name (alphabetical)
- Displays request count with 1 decimal precision
- Shows percentage of total usage per model

### F004: GitHub API Integration
**Status:** Implemented  
**Tests:** `Tests/GitHubAPITests.swift`

- Endpoint: `GET /users/{username}/settings/billing/premium_request/usage`
- Uses Bearer token authentication
- API version header: `X-GitHub-Api-Version: 2022-11-28`
- Handles errors: 401 (unauthorized), 403 (forbidden), 404 (not found)
- Token verification via `/user` endpoint before billing API call

### F005: Secure Token Storage
**Status:** Implemented  
**Tests:** `Tests/KeychainTests.swift`

- Stores GitHub token in macOS Keychain
- Service identifier: `com.copilot-accountant.github-token`
- Trims whitespace from tokens before saving
- Shows token preview (first 12 + last 4 characters)
- Provides delete functionality
- **Token input uses plain TextField** (avoids macOS password manager popup)
- **Show/hide toggle** for token visibility in Settings

### F006: Polling & Auto-Refresh
**Status:** Implemented  
**Tests:** `Tests/PollingTests.swift`

- Configurable polling interval (default: 5 minutes)
- Fetches usage immediately on app start
- Timer-based polling continues in background
- Manual "Refresh Now" option in menu

### F007: Notifications
**Status:** Implemented  
**Tests:** `Tests/NotificationTests.swift`

- Configurable threshold alerts at 80% and 90%
- Configurable custom threshold alert percentage
- Only alerts once per threshold per billing cycle
- Resets alert state when usage drops (new month)
- API error notifications
- Reset reminder notifications
- Settings includes a button to send a test notification on demand

### F008: Settings Persistence
**Status:** Implemented  
**Tests:** `Tests/SettingsTests.swift`

- Saves configuration to UserDefaults
- Settings window keeps `Cancel` and `Save` visible in a pinned footer while the rest of the form scrolls
- Persists:
  - GitHub username
  - Monthly budget (default: 300)
  - Polling interval
  - Notification preferences
  - Alert thresholds (80%, 90%)
  - Custom alert threshold percentage
  - Launch at login preference
- Caches last usage data for offline display

### F009: Singleton Protection
**Status:** Implemented  
**Tests:** `Tests/SingletonTests.swift`

- Prevents multiple instances from running
- Detects existing instance via `NSWorkspace.shared.runningApplications`
- Activates existing instance if found
- New instance terminates gracefully

### F010: First Launch Experience
**Status:** Implemented  
**Tests:** `Tests/FirstLaunchTests.swift`

- Shows popup automatically on first launch
- Shows popup on manual launches (not at login)
- Does NOT show popup when launched at login (silent start)
- Uses UserDefaults key `hasLaunchedBefore` to track

### F011: Logging
**Status:** Implemented  
**Tests:** `Tests/LoggingTests.swift`

- Logs to `~/Library/Application Support/CopilotAccountant/copilot-accountant.log`
- Log levels: DEBUG, INFO, WARNING, ERROR
- Includes timestamp, file, function, line number
- "Open in Finder" button in Settings
- Logs API requests/responses for debugging

### F012: Token Help UI
**Status:** Implemented  
**Tests:** `Tests/TokenHelpTests.swift`

- Expandable "How to create a token" section in Settings
- Step-by-step instructions
- Required permission: "Plan → Read-only"
- "Open GitHub Tokens" button links to token creation page
- Note about personal vs organization subscriptions

### F013: Detailed Statistics View
**Status:** Implemented  
**Tests:** `Tests/DetailedStatsTests.swift`

- Separate window with charts (requires macOS 14.0+)
- Window is resizable with a sensible minimum size
- Daily usage bar chart
- Model breakdown pie chart (SectorMark)
- Product breakdown list
- Progress bar with color coding
- Days until reset display

### F014: Application Icon
**Status:** Implemented  
**Tests:** `Tests/AppIconTests.swift`

- App bundle includes a custom Finder icon instead of the default placeholder
- `Info.plist` declares the icon resource for macOS app bundles
- App bundle creation copies the icon into `Contents/Resources`

---

## Data Models

### UsageResponse
```swift
struct UsageResponse: Codable {
    let timePeriod: TimePeriod
    let user: String
    let product: String?
    let model: String?
    let usageItems: [UsageItem]
    
    var totalRequests: Int  // Sum of grossQuantity, rounded
    var usageByModel: [String: Double]  // Keyed by model name
    var usageByProduct: [String: Double]  // Keyed by product name
}
```

### UsageItem
```swift
struct UsageItem: Codable {
    let product: String
    let sku: String
    let model: String
    let unitType: String
    let pricePerUnit: Double
    let grossQuantity: Double  // ← ACTUAL USAGE (use this!)
    let grossAmount: Double
    let discountQuantity: Double
    let discountAmount: Double
    let netQuantity: Double  // ← After discounts (often 0)
    let netAmount: Double
}
```

### ModelUsage
```swift
struct ModelUsage: Identifiable {
    let modelName: String
    let requestCount: Double  // Supports fractional requests
    let percentage: Double
}
```

---

## API Endpoints

| Endpoint | Purpose | Auth Required |
|----------|---------|---------------|
| `GET /user` | Verify token, get username | Yes |
| `GET /users/{username}/settings/billing/premium_request/usage` | Get premium request usage | Yes |
| `GET /users/{username}/settings/billing/premium_request/usage?year=X&month=Y` | Get usage for specific month | Yes |
| `GET /users/{username}/settings/billing/premium_request/usage?year=X&month=Y&day=Z` | Get usage for specific day | Yes |

---

## Configuration Defaults

| Setting | Default Value |
|---------|---------------|
| Monthly Budget | 300 requests |
| Polling Interval | 5 minutes |
| Notifications Enabled | true |
| Alert at 80% | true |
| Alert at 90% | true |
| Launch at Login | false |

---

## File Locations

| File | Location |
|------|----------|
| Log file | `~/Library/Application Support/CopilotAccountant/copilot-accountant.log` |
| Settings | UserDefaults (standard) |
| Token | macOS Keychain |
| App Bundle | `/Applications/CopilotAccountant.app` |

---

## Requirements

- macOS 14.0+ (Sonoma) - Required for Charts SectorMark
- Swift 6.0+
- Personal GitHub Copilot subscription (not organization-managed)
- Fine-grained token with "Plan: Read-only" permission

---

## Changelog

### 1.0.0 (2026-03-28)
- Initial release with all features F001-F013
- Fixed usage calculation to use grossQuantity
- Fixed model sorting stability
- Added first launch popup
- Added comprehensive logging
- Added token help UI

### 1.0.1 (2026-03-28)
- F001: Menu bar now shows one decimal place (28.7% instead of 29%)
- F001: Popover closes when clicking outside the app
- F005: Token input no longer triggers macOS password manager
- F005: Added show/hide toggle for token visibility

### 1.0.2 (2026-03-28)
- F014: Added a custom app icon to the macOS bundle

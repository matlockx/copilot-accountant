# Copilot Accountant - Feature Specification

> **This file is the source of truth for all features.**  
> Every feature listed here MUST have corresponding tests.  
> Do NOT add features without updating this file and adding tests.

## Version: 1.0.7
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
- Manual refresh does not emit per-percent milestone notifications on its own

### F007: Notifications
**Status:** Implemented  
**Tests:** `Tests/NotificationTests.swift`

- Configurable threshold alerts at 80% and 90%
- Configurable custom threshold alerts with per-alert enable/disable and add/remove controls
- Optional notifications at every newly reached full usage percentage
- Per-percent milestone notifications are deduplicated against matching custom-threshold notifications for the same percentage
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
- Settings window keeps symmetric horizontal padding so section cards do not crowd the left or right edges
- Settings content uses a consistent two-column layout with right-aligned controls and equal-width utility buttons
- Notification checkboxes align in a shared vertical column, with custom alert percentages positioned before that checkbox column
- Pressing `Escape` closes the Settings window
- Saved token can be revealed or hidden from Settings without retyping it
- Settings layout has visual regression coverage for critical spacing and control-column sizing
- Persists:
  - GitHub username
  - Monthly budget (default: 300)
  - Polling interval
  - Notification preferences
  - Alert thresholds (80%, 90%)
  - Custom alert thresholds list with enabled state
  - Per-percent milestone notification preference
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
- Pressing `Escape` closes the statistics window
- **Billing summary cards** showing billed premium requests ($X.XX) and included requests consumed (X of Y with percentage)
- **Interactive chart tooltip**: hovering over daily usage bars shows full date (e.g., "March 14, 2026") and exact request count; hovered bar highlights while others dim
- Daily usage bar chart with simplified X-axis ticks (every 5 days)
- Model breakdown pie chart (SectorMark)
- **Detailed model billing table** with columns: Model, Included requests, Billed requests, Gross amount, Billed amount
- **Model multiplier column** in the breakdown table showing the Copilot premium request multiplier per model (e.g., Claude Opus 4.5 = 3x, Haiku = 0.33x, GPT-4o = Included)
- **Premium requests consumed** column showing actual quota deduction (raw requests x multiplier)
- `CopilotModelMultipliers` lookup table with direct and fuzzy matching for all known Copilot models
- **Total premium requests consumed** billing card uses multiplier-adjusted totals for accurate quota tracking
- Model pricing details reflect GitHub billing unit prices directly and only show meaningful relative factors when prices differ
- **Billing period information** showing date range and days until reset
- Price per premium request display ($0.04)
- Progress bar with color coding
- Days until reset display
- **Empty state cards** when no usage data or no daily data is available

### F014: Application Icon
**Status:** Implemented  
**Tests:** `Tests/AppIconTests.swift`

- App bundle includes a custom Finder icon instead of the default placeholder
- `Info.plist` declares the icon resource for macOS app bundles
- App bundle creation copies the icon into `Contents/Resources`

### F015: Installer Workflow
**Status:** Implemented  
**Tests:** `Tests/InstallerTests.swift`

- `install.sh` verifies the bundle, installs it into `/Applications`, and launches the app automatically at the end of a successful install

### F016: Dynamic Model Multipliers
**Status:** Implemented  
**Tests:** `Tests/ModelMultiplierServiceTests.swift`

- `ModelMultiplierService` fetches latest model multipliers from GitHub Copilot docs
- Parses HTML table from `https://docs.github.com/en/copilot/concepts/billing/copilot-requests`
- Extracts "Multiplier for paid plans" column, skips "Not applicable" entries
- Caches parsed multipliers to UserDefaults with timestamp
- Cache expires after 24 hours (configurable via `ModelMultiplierConfiguration.maxCacheAgeSeconds`)
- Merges fetched multipliers with hardcoded fallback values (fetched take priority)
- Validates parse results require minimum 5 models
- "Update Model Multipliers" button in Detailed Stats with loading spinner, success/error feedback
- "Last updated" timestamp display (e.g., "5 minutes ago", "Never")
- Multiplier legend showing Included (green), < 1x (blue), 1x (standard), > 1x (orange/red)
- Graceful fallback to hardcoded `CopilotModelMultipliers` if no cache exists

### F017: All Models Catalog
**Status:** Implemented  
**Tests:** `Tests/ModelMultiplierServiceTests.swift`

- Displays complete catalog of all known Copilot models (not just used ones)
- Merges models from: user's actual API usage + known multiplier list (hardcoded + cached)
- Each entry shows: Model name, Multiplier, Usage count, Status badge
- Status badges: "Used" (green), "Available" (gray), "Free" (blue, for 0-multiplier models)
- Sort order: Used models first (by usage descending), then free, then available (alphabetical)
- Unused models displayed at reduced opacity (0.6)
- Empty state card when no models available

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

### 1.0.7 (2026-03-28)
- F013: Interactive chart tooltip — hover over daily usage bars to see full date and exact request count
  - Hovered bar highlights (full opacity), other bars dim
  - Tooltip follows cursor with fade animation, shows card with date + count
- F013: Empty state cards for "No usage yet" and "No daily usage data"
- F016: Dynamic Model Multipliers — fetch latest multipliers from GitHub docs
  - ModelMultiplierService with HTML parser, caching, and merge logic
  - "Update Model Multipliers" button with loading/success/error states
  - Multiplier legend (Included, Discounted, Standard, Premium)
- F017: All Models Catalog — view all known Copilot models with status badges
  - Merges API usage data with known model list
  - Status badges: Used, Available, Free
  - Sorted by usage, then status, then alphabetical

### 1.0.6 (2026-03-28)
- F008: Settings UI redesign — flat, modern appearance inspired by macOS native style
  - Removed gradient backgrounds from window and section cards
  - Flat cards with subtle shadow instead of gradient + stroke overlay
  - Reduced card corner radius (18→10pt) for cleaner feel
  - Tighter window size (560×640 vs 620×620) with more vertical room
  - Reduced label/button/field widths for better density (label 160, buttons 100, fields 80)
  - Hosting controller sizing fix prevents window from auto-shrinking
  - Footer uses flat background instead of ultraThinMaterial
  - Delete button uses red text for destructive action clarity

### 1.0.5 (2026-03-28)
- F013: Added model multiplier column (informational, from GitHub Copilot docs)
- F013: Fixed billing card to match GitHub's "Included premium requests consumed" (uses raw grossQuantity, not multiplier-adjusted)
- F013: Restored Gross amount / Billed amount columns to match GitHub's web UI
- F013: Fixed window initial/minimum size to prevent left-edge clipping (700→820 initial, 600→750 min)
- F013: Fixed hosting controller sizing (preferredContentSize + sizingOptions)

### 1.0.4 (2026-03-28)
- F013: Enhanced Detailed Statistics view with comprehensive billing information
  - Added billing summary cards (billed amount + included consumption)
  - Added detailed model billing table with included/billed breakdown
  - Added billing period dates and reset countdown
  - Improved model pricing display (clearer when all prices are equal)
- F008: Fixed Settings window width to prevent layout clipping (520→620pt)
- F008: Fixed Settings window not responding on first open (LSUIElement activation)

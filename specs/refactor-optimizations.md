# Spec: Refactor & Optimizations

**Task ID:** copilot-accountant-0ez  
**Status:** approved  
**Date:** 2026-03-31

## Overview

Refactoring the Copilot Accountant macOS app across 7 areas to improve performance, maintainability, and code quality. All changes are internal — no user-facing behavior changes, no API contract changes, no migration files needed.

---

## Scope

### Area 1 — Fix N+1 Daily Usage API Calls

**File:** `Sources/Services/GitHubAPIService.swift`

**Problem:** `fetchDailyUsage()` makes one sequential HTTP request per day of the current month (up to 31 calls). This causes slowness and unnecessary load on the GitHub API.

**Solution:**
- Use Swift `TaskGroup` (via `withThrowingTaskGroup`) to fire all per-day requests concurrently instead of sequentially.
- Additionally, skip fetching future days (already done: `date <= now`) and consider caching days that are in the past (they won't change within the same month).

**Acceptance criteria:**
- All day requests are fired concurrently using `TaskGroup`.
- Results are collected and sorted by date before returning.
- Existing error handling (zero-usage fallback for failed days) is preserved.
- No change to the public function signature `fetchDailyUsage(username:token:) async throws -> [DailyUsage]`.

---

### Area 2 — Extract Sub-Views from DetailedStatsView and SettingsView

**Files:**
- `Sources/Views/DetailedStatsView.swift` (941 lines → target ≤ 200 lines for orchestrator)
- `Sources/Views/SettingsView.swift` (637 lines → target ≤ 200 lines for orchestrator)

**Problem:** Both files are too large and contain dozens of private view-builder methods, making navigation and testing difficult.

**Solution — DetailedStatsView:** Extract the following into separate files in `Sources/Views/`:
- `BillingCardsView.swift` — `billingCardsSection` + `billingCard` helper
- `SpendingBudgetCardView.swift` — `spendingBudgetCard` + `spendingBudgetColor`
- `UsageBreakdownView.swift` — `usageBreakdownSection`, `modelPieChart`, `modelBillingTable`, `multiplierColor`
- `DailyUsageChartView.swift` — `dailyUsageChart` (bar chart + tooltip overlay + `chartTooltip`)
- `ModelCatalogView.swift` — `allModelsCatalogSection`, `modelCatalogGrid`, `statusBadge`
- `MultiplierUpdateView.swift` — `multiplierUpdateSection`, `updateMultipliers()`, `multiplierLegendItem`

**Solution — SettingsView:** Extract the following into separate files in `Sources/Views/`:
- `TokenSectionView.swift` — GitHub account section (token field, save/validate/delete buttons, help disclosure)
- `BudgetSectionView.swift` — Budget settings section (monthly budget, polling interval, dollar budget, prevent cap toggle)
- `NotificationSectionView.swift` — Notifications section (all toggles, custom alerts list, test button)

**Acceptance criteria:**
- `DetailedStatsView.swift` is ≤ 200 lines (orchestrator only: `body`, section calls, shared helpers like `formatDate`, `currency`, `formatQuantity`, `statusColor`).
- `SettingsView.swift` is ≤ 250 lines (orchestrator only: state declarations, `body`, footer, `saveSettings`, `closeSettingsWindow`).
- All extracted views compile and the app behaves identically.
- Shared state (e.g. `tracker`, `hoveredDay`, `tooltipPosition`) is passed as bindings or `@ObservedObject` where needed.
- Private helpers used only in one sub-view move with that view.
- Helpers shared across sub-views stay in the orchestrator or a shared extension file.
- No new public APIs introduced; all types remain `private` or `internal`.

---

### Area 3 — Consolidate Duplicate `statusColor` Logic

**Files:** `Sources/Models/BudgetConfig.swift`, `Sources/Views/MenuBarView.swift`, `Sources/Views/DetailedStatsView.swift`

**Problem:** The threshold-to-color mapping (green <60%, yellow 60–80%, orange 80–90%, red ≥90%) is duplicated in 5 places across 3 files, returning either `NSColor` (AppKit) or `Color` (SwiftUI).

**Solution:**
- Extend `StatusColor` (already in `BudgetConfig.swift`) with a `color: Color` property that returns the SwiftUI `Color`.
- Add a static factory `StatusColor.from(percentage:) -> StatusColor` that encapsulates the threshold logic once.
- Replace all 5 duplicate implementations with calls to `StatusColor.from(percentage:).color` (SwiftUI) or `.nsColor` (AppKit).

**Acceptance criteria:**
- Only one place in the codebase defines the green/yellow/orange/red percentage thresholds.
- `StatusColor` gains a `color: Color` computed property (in an extension importing SwiftUI).
- `StatusColor.from(percentage:)` or a similar static factory exists and is used everywhere.
- All 5 previous duplicate functions are removed.
- Existing `BudgetConfig.statusColor(used:)` can delegate to the new factory.

---

### Area 4 — Cache DateFormatter and NumberFormatter Instances

**Files:** `Sources/Views/DetailedStatsView.swift`, `Sources/Models/UsageData.swift`

**Problem:** `DateFormatter` and `NumberFormatter` are allocated inside methods that may be called on every render pass. These are expensive to initialize.

**Affected locations:**
- `DetailedStatsView.currency(_:)` — creates `NumberFormatter` inline
- `DetailedStatsView.formatDate(_:)` — creates `DateFormatter` inline
- `DetailedStatsView.formatTooltipDate(_:)` — creates `DateFormatter` inline
- `UsageResponse.billingPeriodDescription` — creates `DateFormatter` inline
- `UsageResponse.resetDateDescription` — creates `DateFormatter` inline

**Solution:**
- Create a `Sources/Utilities/Formatters.swift` file with a `Formatters` enum containing `static let` cached instances for each formatter used in the app.
- Replace all inline formatter creation with references to these cached instances.

**Acceptance criteria:**
- A new `Sources/Utilities/Formatters.swift` file exists with at least:
  - `Formatters.currency: NumberFormatter` — USD currency formatter
  - `Formatters.shortDateTime: DateFormatter` — short date + short time (for "last updated")
  - `Formatters.tooltipDate: DateFormatter` — "MMMM d, yyyy" format
  - `Formatters.monthName: DateFormatter` — "MMM" format (for billing period)
- All inline formatter allocations in the above locations are replaced with the cached instances.
- No functional change to formatted output.

---

### Area 5 — Split `UsageData.swift` into Focused Model Files

**File:** `Sources/Models/UsageData.swift` (398 lines, 8+ types)

**Problem:** This single file conflates API response models, computed billing models, hardcoded multiplier data, and domain logic extensions — making it hard to navigate and modify.

**Solution:** Split into three files:

1. **`Sources/Models/UsageModels.swift`** — Core API types:
   - `UsageItem`, `TimePeriod`, `UsageResponse` (with all its extensions/computed properties)
   - `DailyUsage`, `ModelUsage`

2. **`Sources/Models/BillingModels.swift`** — Billing/computation types:
   - `SpendingBudgetSummary`
   - `BillingSummary`
   - `ModelBillingDetail`

3. **`Sources/Models/CopilotModelMultipliers.swift`** — Multiplier data:
   - `CopilotModelMultipliers` enum (hardcoded data + `multiplier(for:)` + `formatMultiplier`)

- Delete `UsageData.swift` once all content is distributed.

**Acceptance criteria:**
- `UsageData.swift` no longer exists.
- Three new files exist containing the types listed above.
- All existing references compile without changes (types keep their names).
- No logic is altered — pure file reorganization.

---

### Area 6 — Remove Force Unwraps in AppDelegate

**File:** `Sources/App/AppDelegate.swift`

**Problem:** Two force-unwraps on `tracker!` exist in `openSettings()` and `openDetailedStats()`. If `tracker` is ever `nil` at these call sites (e.g. due to an initialization order issue), the app will crash.

**Solution:**
- Change `tracker` from `var tracker: UsageTracker?` to be initialized directly or use `guard let`.
- Alternatively, guard at the call sites and show an appropriate fallback (e.g. log + return early).

**Preferred approach:** Use `guard let tracker` at the top of `openSettings()` and `openDetailedStats()` with a `log.error` + `return` on failure.

**Acceptance criteria:**
- No `!` force-unwraps on `tracker` anywhere in `AppDelegate.swift`.
- The app compiles and behaves identically.
- If `tracker` is somehow nil, a log error is emitted and the function returns gracefully.

---

### Area 7 — Reduce Token Prefix in Debug Log

**File:** `Sources/Services/GitHubAPIService.swift`

**Problem:** The debug log line:
```swift
log.debug("Token (first 10 chars): \(String(token.prefix(10)))...")
```
logs 10 characters of the GitHub personal access token to a plaintext file on disk. A `ghp_` token prefix plus 6 more characters narrows down the token space non-trivially.

**Solution:** Reduce from 10 to 4 characters (just enough to confirm the token format prefix `ghp_`):
```swift
log.debug("Token prefix: \(String(token.prefix(4)))...")
```

**Acceptance criteria:**
- The debug log line logs at most 4 characters of the token.
- Log message remains meaningful (confirms a token is present and what type it starts with).

---

## Non-Goals

- No user-facing UI changes.
- No API contract changes.
- No migration files.
- No new features.
- No changes to test files (per AGENTS.md golden rules).
- Area 8 (HTML parsing robustness), Area 9 (Sendable conformances), Area 10 (struct/actor services) are deferred.

---

## File Impact Summary

| File | Change Type |
|------|-------------|
| `Sources/Services/GitHubAPIService.swift` | Modify (concurrent fetching + token log) |
| `Sources/Views/DetailedStatsView.swift` | Reduce (extract sub-views) |
| `Sources/Views/SettingsView.swift` | Reduce (extract sub-views) |
| `Sources/Views/BillingCardsView.swift` | New |
| `Sources/Views/SpendingBudgetCardView.swift` | New |
| `Sources/Views/UsageBreakdownView.swift` | New |
| `Sources/Views/DailyUsageChartView.swift` | New |
| `Sources/Views/ModelCatalogView.swift` | New |
| `Sources/Views/MultiplierUpdateView.swift` | New |
| `Sources/Views/TokenSectionView.swift` | New |
| `Sources/Views/BudgetSectionView.swift` | New |
| `Sources/Views/NotificationSectionView.swift` | New |
| `Sources/Models/UsageData.swift` | Delete |
| `Sources/Models/UsageModels.swift` | New |
| `Sources/Models/BillingModels.swift` | New |
| `Sources/Models/CopilotModelMultipliers.swift` | New |
| `Sources/Models/BudgetConfig.swift` | Modify (StatusColor extension) |
| `Sources/Utilities/Formatters.swift` | New |
| `Sources/App/AppDelegate.swift` | Modify (remove force unwraps) |

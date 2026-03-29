---
issueId: copilot-accountant-w0z
specId: copilot-accountant-4bk
createdAt: "2026-03-29T19:02:58Z"
work_state: approved
approvedAt: "2026-03-29T19:02:58Z"
---

# Copilot Accountant 1.0.9 — Release Specification

## Requirements

This spec covers all features in the 1.0.9 release of Copilot Accountant, a macOS menu bar utility that monitors GitHub Copilot usage.

**Source of truth:** `FEATURES.md` (same directory) — all feature IDs (F001–F021), data models, API endpoints, and configuration defaults are documented there. This spec provides the workflow-level structure; the markdown file is the implementation reference.

### Core Features (F001–F021)

| ID | Feature | Status | Test File |
|----|---------|--------|-----------|
| F001 | Menu Bar Integration | Implemented | `Tests/MenuBarTests.swift` |
| F002 | Usage Calculation | Implemented | `Tests/UsageCalculationTests.swift` |
| F003 | Model Usage Breakdown | Implemented | `Tests/ModelUsageTests.swift` |
| F004 | GitHub API Integration | Implemented | `Tests/GitHubAPITests.swift` |
| F005 | Secure Token Storage | Implemented | `Tests/KeychainTests.swift` |
| F006 | Polling & Auto-Refresh | Implemented | `Tests/PollingTests.swift` |
| F007 | Notifications | Implemented | `Tests/NotificationTests.swift` |
| F008 | Settings Persistence | Implemented | `Tests/SettingsTests.swift` |
| F009 | Singleton Protection | Implemented | `Tests/SingletonTests.swift` |
| F010 | First Launch Experience | Implemented | `Tests/FirstLaunchTests.swift` |
| F011 | Logging | Implemented | `Tests/LoggingTests.swift` |
| F012 | Token Help UI | Implemented | `Tests/TokenHelpTests.swift` |
| F013 | Detailed Statistics View | Implemented | `Tests/DetailedStatsTests.swift` |
| F014 | Application Icon | Implemented | `Tests/AppIconTests.swift` |
| F015 | Installer Workflow | Implemented | `Tests/InstallerTests.swift` |
| F016 | Dynamic Model Multipliers | Implemented | `Tests/ModelMultiplierServiceTests.swift` |
| F017 | All Models Catalog | Implemented | `Tests/ModelMultiplierServiceTests.swift` |
| F018 | Spending Budget Integration | Implemented | `Tests/SpendingBudgetTests.swift` |
| F019 | Enhanced Menu Bar Popup | Implemented | `Tests/MenuBarTests.swift` |
| F020 | Pie Chart Hover Tooltips | Implemented | `Tests/DetailedStatsTests.swift` |
| F021 | Copilot Menu Bar Icon | Implemented | `Tests/MenuBarTests.swift` |

### Key Requirements Summary

- **Menu bar app** — runs as `LSUIElement` (no dock icon), shows usage % in status bar
- **Usage calculation** — uses `grossQuantity` (NOT `netQuantity`) from API
- **GitHub API** — `GET /users/{username}/settings/billing/premium_request/usage` with Bearer token
- **Token storage** — macOS Keychain, service `com.copilot-accountant.github-token`
- **Notifications** — configurable at 80%, 90%, and custom thresholds; deduplicated against per-percent milestones
- **Settings** — UserDefaults-persisted, pinned footer with Cancel/Save, symmetric padding
- **Model multipliers** — fetched from GitHub docs, cached 24h, merged with hardcoded fallbacks
- **Spending budget** — dollar budget computed from `totalNetCost` in usage response
- **Charts** — requires macOS 14.0+ (SectorMark for pie charts)
- **Screenshots** — macOS 14.0+, Swift 6.0+, personal GitHub Copilot subscription

## Design

### Architecture

```
Sources/
├── CopilotAccountant/
│   ├── App/
│   │   ├── CopilotAccountant.swift      # @main entry point
│   │   └── AppDelegate.swift
│   ├── MenuBar/
│   │   ├── MenuBarController.swift      # NSStatusItem, popover
│   │   ├── CopilotMenuBarIcon.swift     # Programmatic icon drawing (F021)
│   │   └── StatusColor.swift            # nsColor mapping
│   ├── Views/
│   │   ├── MenuBarPopoverView.swift     # Spending summary (F019)
│   │   └── DetailedStatsView.swift      # Charts, hover tooltips (F013, F020)
│   ├── Services/
│   │   ├── GitHubAPIService.swift        # F004
│   │   ├── UsageService.swift           # F002, F003
│   │   ├── KeychainService.swift        # F005
│   │   ├── NotificationService.swift    # F007
│   │   └── ModelMultiplierService.swift # F016, F017
│   ├── Models/
│   │   ├── UsageResponse.swift
│   │   ├── SpendingBudgetSummary.swift  # F018
│   │   └── CopilotModelMultipliers.swift
│   └── Utilities/
│       └── LoggingService.swift         # F011
Tests/
├── MenuBarTests.swift                   # F001, F019, F021
├── UsageCalculationTests.swift          # F002
├── ModelUsageTests.swift                # F003
├── GitHubAPITests.swift                 # F004
├── KeychainTests.swift                  # F005
├── PollingTests.swift                   # F006
├── NotificationTests.swift              # F007
├── SettingsTests.swift                  # F008
├── SingletonTests.swift                  # F009
├── FirstLaunchTests.swift              # F010
├── LoggingTests.swift                   # F011
├── TokenHelpTests.swift                 # F012
├── DetailedStatsTests.swift            # F013, F020
├── AppIconTests.swift                   # F014
├── InstallerTests.swift                 # F015
├── ModelMultiplierServiceTests.swift    # F016, F017
└── SpendingBudgetTests.swift           # F018
```

### Critical Implementation Notes

1. **grossQuantity vs netQuantity** — Always use `grossQuantity` from `UsageItem`. The `netQuantity` field is 0 after discounts and must not be used in calculations.
2. **Model sorting** — Sort by request count descending, then model name alphabetically. Unstable sort causes layout flicker on refresh.
3. **Token storage** — Always `trim()` tokens before saving to Keychain. Use plain `TextField` (not `SecureField`) to avoid macOS password manager popup.
4. **Async/UI** — All UI mutations must run on `@MainActor`. Use `Task { @MainActor in }` for background-to-UI transitions.
5. **Retain cycles** — All closures capturing `self` must use `[weak self]` unless lifetime is guaranteed.
6. **Charts** — `SectorMark` requires macOS 14.0+. Guard with `#available(macOS 14.0, *)`.

### File Locations

| File | Location |
|------|----------|
| Log file | `~/Library/Application Support/CopilotAccountant/copilot-accountant.log` |
| Settings | UserDefaults (standard) |
| Token | macOS Keychain |
| App Bundle | `/Applications/CopilotAccountant.app` |

### Dependencies

- **SPM packages:** None (pure Apple frameworks)
- **Frameworks:** AppKit, SwiftUI, Charts (macOS 14+), Foundation
- **External:** GitHub Copilot API (no third-party libs needed)

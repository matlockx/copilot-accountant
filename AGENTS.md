# Agent Development Rules

> **MANDATORY RULES FOR ALL AI AGENTS WORKING ON THIS PROJECT**  
> These rules are non-negotiable. Violation causes regressions.

---

## Golden Rules

### 1. NO CHANGES WITHOUT TESTS
```
❌ FORBIDDEN: Adding/modifying features without tests
✅ REQUIRED: Every feature change must include test updates
```

Before ANY code change:
1. Read `FEATURES.md` to understand existing features
2. Write/update tests FIRST
3. Implement the change
4. Verify tests pass
5. Update `FEATURES.md` if adding new features

### 2. FEATURES.md IS THE SOURCE OF TRUTH
```
❌ FORBIDDEN: Adding features not documented in FEATURES.md
✅ REQUIRED: Update FEATURES.md BEFORE implementing new features
```

The feature specification in `FEATURES.md`:
- Lists ALL implemented features with IDs (F001, F002, etc.)
- Documents expected behavior
- References corresponding test files
- Must be kept in sync with implementation

### 3. RUN TESTS BEFORE COMMITS
```
❌ FORBIDDEN: Committing code without running tests
✅ REQUIRED: ./run-tests.sh must pass before any commit
```

---

## Development Workflow

### Adding a New Feature

1. **Document First**
   ```bash
   # Add feature to FEATURES.md with new ID (F014, F015, etc.)
   # Document expected behavior
   # Specify test file name
   ```

2. **Write Tests First**
   ```bash
   # Create/update test file in Tests/
   # Test the expected behavior
   # Tests should FAIL initially (TDD)
   ```

3. **Implement Feature**
   ```bash
   # Write the actual implementation
   # Keep changes minimal and focused
   ```

4. **Verify Tests Pass**
   ```bash
   ./run-tests.sh
   ```

5. **Update Documentation**
   ```bash
   # Update FEATURES.md with any changes
   # Update README.md if user-facing
   ```

### Modifying Existing Features

1. **Find Feature in FEATURES.md**
   - Locate the feature ID (F001-F013)
   - Read the specification

2. **Update Tests First**
   - Modify existing tests to reflect new behavior
   - Add new test cases if needed

3. **Implement Changes**
   - Make minimal changes
   - Don't break other features

4. **Run Full Test Suite**
   ```bash
   ./run-tests.sh
   ```

### Fixing Bugs

1. **Write Regression Test**
   - Create test that reproduces the bug
   - Test should FAIL before fix

2. **Fix the Bug**
   - Make minimal fix
   - Don't change unrelated code

3. **Verify Test Passes**
   - The regression test should now pass
   - All other tests should still pass

---

## Critical Implementation Details

### Usage Calculation (F002)
```swift
// ✅ CORRECT - Use grossQuantity
var totalRequests: Int {
    Int(usageItems.reduce(0) { $0 + $1.grossQuantity }.rounded())
}

// ❌ WRONG - netQuantity is 0 after discounts
var totalRequests: Int {
    Int(usageItems.reduce(0) { $0 + $1.netQuantity })
}
```

### Model Sorting (F003)
```swift
// ✅ CORRECT - Stable sort
.sorted { 
    if $0.requestCount != $1.requestCount {
        return $0.requestCount > $1.requestCount
    }
    return $0.modelName < $1.modelName
}

// ❌ WRONG - Unstable sort (order changes on refresh)
.sorted { $0.requestCount > $1.requestCount }
```

### Token Storage (F005)
```swift
// ✅ CORRECT - Trim whitespace
let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
try keychainService.saveToken(cleanToken)

// ❌ WRONG - Raw token may have whitespace
try keychainService.saveToken(token)
```

---

## Test Requirements

### Test File Structure
```
Tests/
├── UsageCalculationTests.swift   # F002
├── ModelUsageTests.swift         # F003
├── GitHubAPITests.swift          # F004
├── KeychainTests.swift           # F005
├── PollingTests.swift            # F006
├── NotificationTests.swift       # F007
├── SettingsTests.swift           # F008
├── SingletonTests.swift          # F009
├── FirstLaunchTests.swift        # F010
├── LoggingTests.swift            # F011
├── TokenHelpTests.swift          # F012
├── DetailedStatsTests.swift      # F013, F020
├── ModelMultiplierServiceTests.swift  # F016, F017
├── SpendingBudgetTests.swift     # F018
└── MenuBarTests.swift            # F001, F019, F021
```

### Test Naming Convention
```swift
func test_FeatureName_Scenario_ExpectedBehavior() {
    // Given
    // When
    // Then
}

// Example:
func test_UsageCalculation_WithDiscounts_UsesGrossQuantity() {
    // Given
    let item = UsageItem(grossQuantity: 33.0, netQuantity: 0.0, ...)
    
    // When
    let total = usage.totalRequests
    
    // Then
    XCTAssertEqual(total, 33)
}
```

### Minimum Test Coverage
- Every public function must have at least one test
- Every feature must have happy path + error path tests
- Edge cases must be tested (empty data, nil values, etc.)

---

## Forbidden Actions

### Never Do These:
1. ❌ Change `grossQuantity` to `netQuantity` in usage calculation
2. ❌ Remove secondary sort key from model sorting
3. ❌ Store tokens without trimming whitespace
4. ❌ Skip singleton check in AppDelegate
5. ❌ Remove logging from API calls
6. ❌ Change API version header without testing
7. ❌ Modify features without updating FEATURES.md
8. ❌ Commit without running tests

---

## Quick Reference

### Build & Test
```bash
./build-direct.sh          # Build the app
./run-tests.sh             # Run all tests
./install.sh               # Install to /Applications
```

### Key Files
```
FEATURES.md                # Feature specification (source of truth)
AGENTS.md                  # This file (development rules)
Tests/                     # Test suite
Sources/                   # Implementation
```

### Feature IDs
| ID | Feature | Test File |
|----|---------|-----------|
| F001 | Menu Bar Integration | MenuBarTests.swift |
| F002 | Usage Calculation | UsageCalculationTests.swift |
| F003 | Model Usage Breakdown | ModelUsageTests.swift |
| F004 | GitHub API Integration | GitHubAPITests.swift |
| F005 | Secure Token Storage | KeychainTests.swift |
| F006 | Polling & Auto-Refresh | PollingTests.swift |
| F007 | Notifications | NotificationTests.swift |
| F008 | Settings Persistence | SettingsTests.swift |
| F009 | Singleton Protection | SingletonTests.swift |
| F010 | First Launch Experience | FirstLaunchTests.swift |
| F011 | Logging | LoggingTests.swift |
| F012 | Token Help UI | TokenHelpTests.swift |
| F013 | Detailed Statistics View | DetailedStatsTests.swift |
| F016 | Dynamic Model Multipliers | ModelMultiplierServiceTests.swift |
| F017 | All Models Catalog | ModelMultiplierServiceTests.swift |
| F018 | Spending Budget Integration | SpendingBudgetTests.swift |
| F019 | Enhanced Menu Bar Popup | MenuBarTests.swift |
| F020 | Pie Chart Hover Tooltips | DetailedStatsTests.swift |
| F021 | Copilot Menu Bar Icon | MenuBarTests.swift |

---

## Enforcement

AI agents must:
1. Read this file at the start of every session
2. Confirm understanding of rules before making changes
3. Follow TDD (Test-Driven Development)
4. Never skip tests "to save time"
5. Report any rule violations they observe

**Remember: Tests are not optional. They prevent regressions.**

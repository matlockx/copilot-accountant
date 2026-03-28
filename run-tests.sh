#!/bin/bash
# Test runner for Copilot Accountant
# Compiles and runs all test files

set -e

echo "========================================="
echo "Copilot Accountant Test Suite"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Build directory
BUILD_DIR=".build/tests"
mkdir -p "$BUILD_DIR"

# Source files needed for tests (excluding main app entry point)
SOURCE_FILES=(
    "Sources/Services/LogService.swift"
    "Sources/Models/AppIconConfiguration.swift"
    "Sources/Models/NotificationSettingsConfiguration.swift"
    "Sources/Models/UsageData.swift"
    "Sources/Models/BudgetConfig.swift"
    "Sources/Models/WindowConfiguration.swift"
    "Sources/Services/KeychainService.swift"
    "Sources/Services/NotificationService.swift"
    "Sources/Services/GitHubAPIService.swift"
    "Sources/Services/UsageTracker.swift"
)

# Check if source files exist
for file in "${SOURCE_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: Source file not found: $file${NC}"
        exit 1
    fi
done

# Compile and run each test file
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .swift)
    local output_binary="$BUILD_DIR/$test_name"
    
    echo -n "Running $test_name... "
    
    # Compile the test - use -parse-as-library and link with @main in test file
    if swiftc -o "$output_binary" \
        -target arm64-apple-macosx14.0 \
        -framework Foundation \
        -framework Security \
        -framework UserNotifications \
        -framework AppKit \
        -parse-as-library \
        "${SOURCE_FILES[@]}" \
        "$test_file" 2>"$BUILD_DIR/${test_name}_compile.log"; then
        
        # Run the test
        if "$output_binary" 2>&1 | tee "$BUILD_DIR/${test_name}_output.log" | grep -q "FAILED"; then
            echo -e "${RED}FAILED${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            cat "$BUILD_DIR/${test_name}_output.log"
        else
            # Check for test success
            local test_count=$(grep -c "PASSED" "$BUILD_DIR/${test_name}_output.log" 2>/dev/null || echo "0")
            if [ "$test_count" -gt 0 ]; then
                echo -e "${GREEN}PASSED${NC} ($test_count tests)"
                PASSED_TESTS=$((PASSED_TESTS + test_count))
            else
                echo -e "${YELLOW}NO TESTS${NC}"
            fi
        fi
    else
        echo -e "${RED}COMPILE ERROR${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        cat "$BUILD_DIR/${test_name}_compile.log"
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Find and run all test files
echo "Discovering tests..."
TEST_FILES=$(find Tests -name "*Tests.swift" -type f | sort)

if [ -z "$TEST_FILES" ]; then
    echo -e "${YELLOW}No test files found in Tests/ directory${NC}"
    exit 1
fi

echo "Found $(echo "$TEST_FILES" | wc -l | tr -d ' ') test files"
echo ""
echo "-----------------------------------------"

for test_file in $TEST_FILES; do
    run_test "$test_file"
done

echo "-----------------------------------------"
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Test files:  $TOTAL_TESTS"
echo -e "Passed:      ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:      ${RED}$FAILED_TESTS${NC}"
echo ""

if [ "$FAILED_TESTS" -gt 0 ]; then
    echo -e "${RED}TESTS FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    exit 0
fi

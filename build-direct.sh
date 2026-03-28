#!/bin/bash

# Direct Swift Compiler Build Script (No SPM)
# Bypasses sandbox restrictions by compiling directly

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Direct Swift Compiler Build          ║${NC}"
echo -e "${BLUE}║  (Bypasses SPM Sandbox)                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check Swift
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}❌ Swift not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Swift: $(swift --version | head -n 1)${NC}"
echo ""

# Build configuration
BUILD_TYPE="${1:-release}"
OUTPUT_DIR=".build/${BUILD_TYPE}"
OUTPUT_BIN="${OUTPUT_DIR}/CopilotAccountant"

echo -e "${BLUE}🔨 Building (${BUILD_TYPE})...${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Collect all Swift files
SWIFT_FILES=(
    Sources/Models/AppIconConfiguration.swift
    Sources/Models/CustomAlertThreshold.swift
    Sources/Models/LaunchAtLoginConfiguration.swift
    Sources/Models/NotificationSettingsConfiguration.swift
    Sources/Models/UsageData.swift
    Sources/Models/BudgetConfig.swift
    Sources/Models/WindowConfiguration.swift
    Sources/Services/LogService.swift
    Sources/Services/KeychainService.swift
    Sources/Services/NotificationService.swift
    Sources/Services/GitHubAPIService.swift
    Sources/Services/UsageTracker.swift
    Sources/Views/MenuBarView.swift
    Sources/Views/SettingsView.swift
    Sources/Views/DetailedStatsView.swift
    Sources/App/AppDelegate.swift
    Sources/App/CopilotAccountantApp.swift
)

# Compile
echo "Compiling ${#SWIFT_FILES[@]} Swift files..."

SWIFT_FLAGS="-target arm64-apple-macosx14.0"

if [ "$BUILD_TYPE" = "release" ]; then
    SWIFT_FLAGS="$SWIFT_FLAGS -O"
else
    SWIFT_FLAGS="$SWIFT_FLAGS -g"
fi

swiftc \
    $SWIFT_FLAGS \
    -framework AppKit \
    -framework SwiftUI \
    -framework Charts \
    -framework UserNotifications \
    -framework Security \
    -framework Foundation \
    -module-name CopilotAccountant \
    -o "$OUTPUT_BIN" \
    "${SWIFT_FILES[@]}" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful!${NC}"
    echo ""
    
    # Show binary info
    SIZE=$(du -h "$OUTPUT_BIN" | cut -f1)
    echo -e "${GREEN}📱 Binary: ${OUTPUT_BIN}${NC}"
    echo -e "${GREEN}📦 Size: ${SIZE}${NC}"
    echo ""
    
    # Option to run
    if [ "$2" = "--run" ]; then
        echo -e "${BLUE}🚀 Launching app...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        "$OUTPUT_BIN"
    else
        echo -e "${GREEN}✓ Done!${NC}"
        echo ""
        echo "To run the app:"
        echo -e "  ${BLUE}$OUTPUT_BIN${NC}"
        echo ""
        echo "Or rebuild and run:"
        echo -e "  ${BLUE}./build-direct.sh release --run${NC}"
    fi
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

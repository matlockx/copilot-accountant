#!/bin/bash

# Copilot Accountant Build Script
# This script helps you build and run the Copilot Accountant app

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Copilot Accountant Build Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if Xcode command line tools are installed
if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Swift not found!${NC}"
    echo "Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

echo -e "${GREEN}✓ Swift found: $(swift --version | head -n 1)${NC}"
echo ""

# Parse command line arguments
BUILD_TYPE="debug"
RUN_AFTER_BUILD=false
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --run)
            RUN_AFTER_BUILD=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--release] [--run] [--clean]"
            exit 1
            ;;
    esac
done

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build directory...${NC}"
    swift package clean
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
fi

# Resolve dependencies
echo -e "${BLUE}📦 Resolving dependencies...${NC}"
swift package resolve
echo -e "${GREEN}✓ Dependencies resolved${NC}"
echo ""

# Build
echo -e "${BLUE}🔨 Building ($BUILD_TYPE)...${NC}"
if [ "$BUILD_TYPE" = "release" ]; then
    swift build -c release
    BUILD_PATH=".build/release/CopilotAccountant"
else
    swift build
    BUILD_PATH=".build/debug/CopilotAccountant"
fi

echo -e "${GREEN}✓ Build complete!${NC}"
echo ""

# Show binary info
if [ -f "$BUILD_PATH" ]; then
    SIZE=$(du -h "$BUILD_PATH" | cut -f1)
    echo -e "${GREEN}📱 Binary size: ${SIZE}${NC}"
    echo -e "${GREEN}📍 Location: ${BUILD_PATH}${NC}"
else
    echo -e "${RED}❌ Binary not found at: ${BUILD_PATH}${NC}"
    exit 1
fi

# Run if requested
if [ "$RUN_AFTER_BUILD" = true ]; then
    echo ""
    echo -e "${BLUE}🚀 Launching app...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    "$BUILD_PATH"
else
    echo ""
    echo -e "${GREEN}✓ All done!${NC}"
    echo ""
    echo "To run the app:"
    echo -e "  ${BLUE}$BUILD_PATH${NC}"
    echo ""
    echo "Or rebuild and run:"
    echo -e "  ${BLUE}./build.sh --run${NC}"
    echo ""
    echo "To build for release:"
    echo -e "  ${BLUE}./build.sh --release${NC}"
fi

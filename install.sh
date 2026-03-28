#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

APP_NAME="CopilotAccountant"
APP_BUNDLE="${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_BUNDLE}"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Copilot Accountant Installer         ║${NC}"
echo -e "${BLUE}║  Build → Verify → Install              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if app is currently running
echo -e "${BLUE}🔍 Checking for running instances...${NC}"
if pgrep -x "${APP_NAME}" > /dev/null; then
    echo -e "${YELLOW}⚠️  App is currently running. Stopping it...${NC}"
    killall "${APP_NAME}" 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✓ App stopped${NC}"
else
    echo -e "${GREEN}✓ No running instances found${NC}"
fi
echo ""

# Step 2: Build the app
echo -e "${BLUE}🔨 Building application...${NC}"
./build-direct.sh release
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Step 3: Create app bundle
echo -e "${BLUE}📦 Creating app bundle...${NC}"
./create-app-bundle.sh
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to create app bundle!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ App bundle created${NC}"
echo ""

# Step 4: Code sign the bundle
echo -e "${BLUE}✍️  Signing app bundle...${NC}"
codesign --force --deep --sign - --entitlements Resources/Entitlements.plist "${APP_BUNDLE}" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Code signing failed (continuing anyway)${NC}"
else
    echo -e "${GREEN}✓ App signed${NC}"
fi
echo ""

# Step 5: Verify code signature
echo -e "${BLUE}🔐 Verifying signature...${NC}"
if codesign --verify --verbose "${APP_BUNDLE}" 2>/dev/null; then
    echo -e "${GREEN}✓ Signature valid${NC}"
else
    echo -e "${YELLOW}⚠️  Signature verification failed (continuing anyway)${NC}"
fi
echo ""

# Step 6: Validate bundle structure
echo -e "${BLUE}🔍 Validating bundle structure...${NC}"
ERRORS=0

# Check executable exists
if [ ! -f "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" ]; then
    echo -e "${RED}✗ Executable not found${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Executable exists${NC}"
fi

# Check Info.plist exists
if [ ! -f "${APP_BUNDLE}/Contents/Info.plist" ]; then
    echo -e "${RED}✗ Info.plist not found${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ Info.plist exists${NC}"
fi

# Validate Info.plist syntax
if plutil -lint "${APP_BUNDLE}/Contents/Info.plist" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Info.plist valid${NC}"
else
    echo -e "${RED}✗ Info.plist invalid${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check executable is executable
if [ -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" ]; then
    echo -e "${GREEN}✓ Executable has correct permissions${NC}"
else
    echo -e "${RED}✗ Executable is not executable${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Validation failed with ${ERRORS} error(s)${NC}"
    exit 1
fi
echo ""

# Step 7: Check if old version exists in /Applications
if [ -d "${INSTALL_PATH}" ]; then
    echo -e "${YELLOW}📂 Existing installation found at ${INSTALL_PATH}${NC}"
    echo -e "${YELLOW}   Removing old version...${NC}"
    rm -rf "${INSTALL_PATH}" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Cannot remove old version (permission denied)${NC}"
        echo -e "${YELLOW}💡 Please run with sudo: sudo ./install.sh${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Old version removed${NC}"
    echo ""
fi

# Step 8: Install to /Applications
echo -e "${BLUE}📲 Installing to /Applications...${NC}"
if cp -R "${APP_BUNDLE}" /Applications/ 2>/dev/null; then
    echo -e "${GREEN}✓ Installed to ${INSTALL_PATH}${NC}"
else
    echo -e "${YELLOW}⚠️  Cannot write to /Applications (permission denied)${NC}"
    echo -e "${YELLOW}💡 Please run with sudo: sudo ./install.sh${NC}"
    echo ""
    echo -e "${GREEN}✓ App bundle ready at: ${PWD}/${APP_BUNDLE}${NC}"
    echo -e "${BLUE}   You can manually copy it:${NC}"
    echo -e "   sudo cp -R ${APP_BUNDLE} /Applications/"
    exit 0
fi
echo ""

# Step 9: Remove quarantine attribute (if present)
echo -e "${BLUE}🔓 Removing quarantine attribute...${NC}"
xattr -d com.apple.quarantine "${INSTALL_PATH}" 2>/dev/null || true
echo -e "${GREEN}✓ Quarantine removed${NC}"
echo ""

# Step 10: Final verification
echo -e "${BLUE}✅ Final verification...${NC}"
if [ -d "${INSTALL_PATH}" ] && [ -x "${INSTALL_PATH}/Contents/MacOS/${APP_NAME}" ]; then
    echo -e "${GREEN}✓ Installation verified${NC}"
    
    # Get app size
    APP_SIZE=$(du -sh "${INSTALL_PATH}" | cut -f1)
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ Installation Complete!             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📍 Location:${NC} ${INSTALL_PATH}"
    echo -e "${BLUE}📦 Size:${NC} ${APP_SIZE}"
    echo ""
    echo -e "${GREEN}🚀 To launch the app:${NC}"
    echo -e "   1. Look for the ${APP_NAME} icon in your Applications folder"
    echo -e "   2. Double-click to launch"
    echo -e "   3. Look for the ☁️ icon in your menu bar (top-right)"
    echo ""
    echo -e "${BLUE}Or launch from terminal:${NC}"
    echo -e "   open /Applications/${APP_BUNDLE}"
    echo ""
    echo -e "${BLUE}🚀 Launching app now...${NC}"
    open "/Applications/${APP_BUNDLE}"
    echo -e "${GREEN}✓ App launched${NC}"
    echo ""
    echo -e "${YELLOW}💡 First time setup:${NC}"
    echo -e "   1. Click the ☁️ icon in the menu bar"
    echo -e "   2. Select 'Settings'"
    echo -e "   3. Enter your GitHub username and token"
    echo -e "   4. Click 'Save' and then 'Validate'"
    echo ""
else
    echo -e "${RED}✗ Installation verification failed!${NC}"
    exit 1
fi

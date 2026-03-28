#!/bin/bash

set -e

echo "🎁 Creating App Bundle..."

APP_NAME="CopilotAccountant"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Clean old bundle
rm -rf "${APP_DIR}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
echo "📦 Copying binary..."
cp .build/release/CopilotAccountant "${MACOS_DIR}/"
chmod +x "${MACOS_DIR}/CopilotAccountant"

# Copy Info.plist
echo "📝 Copying Info.plist..."
cp Resources/Info.plist "${CONTENTS_DIR}/"

# Create PkgInfo
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "✅ App bundle created: ${APP_DIR}"
echo ""
echo "To run:"
echo "  open ${APP_DIR}"
echo ""
echo "To install:"
echo "  mv ${APP_DIR} /Applications/"


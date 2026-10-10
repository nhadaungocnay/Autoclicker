#!/bin/bash
set -e

echo "========================================="
echo " Installing Auto Clicker into /Applications"
echo "========================================="

# 1. Build the app
chmod +x build.sh
./build.sh

# 2. Copy to /Applications
TARGET_DIR="/Applications"
APP_NAME="Auto Clicker.app"

echo " Installing to ${TARGET_DIR}/${APP_NAME}..."
rm -rf "${TARGET_DIR}/${APP_NAME}"
cp -R "build/${APP_NAME}" "${TARGET_DIR}/"

# Clear quarantine attribute if any
xattr -rd com.apple.quarantine "${TARGET_DIR}/${APP_NAME}" 2>/dev/null || true

echo "========================================="
echo " Installation Complete!"
echo " You can now launch Auto Clicker from Launchpad, Spotlight, or /Applications"
echo "========================================="

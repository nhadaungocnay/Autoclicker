#!/bin/bash
set -e

APP_NAME="AutoClicker"
BUNDLE_NAME="Auto Clicker.app"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "================================================="
echo " Building ${APP_NAME} for Apple Silicon (M1/M2/M3/M4)"
echo "================================================="

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 1. Generate App Icon
echo "🎨 Generating App Icon..."
clang -framework Cocoa Resources/generate_icon.m -o build/gen_icon
./build/gen_icon
rm -f build/gen_icon

if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns Resources/AppIcon.iconset -o "${RESOURCES_DIR}/AppIcon.icns"
    echo "✓ AppIcon.icns created."
fi

# 2. Copy Info.plist
echo "📄 Copying Info.plist..."
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"

# 3. Compile Native Objective-C / Cocoa sources
echo "⚙️ Compiling Native App with Apple Silicon optimizations..."

SOURCES=(
    src/SettingsManager.m
    src/ClickEngine.m
    src/HotkeyManager.m
    src/MainWindowController.m
    src/AppDelegate.m
    src/main.m
)

clang -O3 \
    -arch arm64 \
    -mmacosx-version-min=12.0 \
    -fobjc-arc \
    -framework Cocoa \
    -framework Carbon \
    -framework ApplicationServices \
    -framework CoreGraphics \
    -framework QuartzCore \
    "${SOURCES[@]}" \
    -o "${MACOS_DIR}/${APP_NAME}"

# 4. Set permissions
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 5. Ad-hoc Codesign for macOS gatekeeper
echo "🔏 Signing application bundle..."
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "================================================="
echo "✅ Build Successful!"
echo "📦 App Location: ${APP_DIR}"
echo "================================================="

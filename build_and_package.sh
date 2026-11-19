#!/bin/bash
# Builds the direct-download iActivity.dmg (outside the Mac App Store).
# The Mac App Store build is archived and uploaded from Xcode: Product ▸ Archive ▸ Distribute App.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="iActivity"
DMG_NAME="iActivity.dmg"
STAGING_DIR="dmg_temp"
DERIVED=".build/xcode-dmg"
APP="$DERIVED/Build/Products/Release/$APP_NAME.app"

echo "------------------------------------------"
echo "  iActivity Build & Packaging Utility     "
echo "------------------------------------------"

# 1. Universal Release build from the Xcode project. Not sandboxed: the direct-download build
#    keeps the process lists and Move-to-Applications that the sandbox rules out.
echo "🏗️  Building $APP_NAME (Release, universal)..."
xcodebuild -project iActivity.xcodeproj -scheme "$APP_NAME" -configuration Release \
    -derivedDataPath "$DERIVED" -destination "generic/platform=macOS" -quiet \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= \
    build

# 2. Symbol tables are ~60% of the binary and nothing reads them at runtime. Stripping drops the
#    signature, and Apple Silicon won't run unsigned code, so re-sign ad hoc.
strip -rSTx "$APP/Contents/MacOS/$APP_NAME"
codesign --force --sign - "$APP"

# 3. Stage and create the DMG.
echo "💾 Generating Disk Image (DMG)..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"
ditto "$APP" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME Installer" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
rm -rf "$STAGING_DIR"

echo "------------------------------------------"
echo "✅ SUCCESS: $DMG_NAME is ready!"
echo "------------------------------------------"

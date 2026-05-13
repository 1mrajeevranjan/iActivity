#!/bin/bash

# iActivity Build & Package Script
# Following BatterySense "Premium" standards

APP_NAME="iActivity"
DMG_NAME="iActivity.dmg"
STAGING_DIR="dmg_temp"

echo "------------------------------------------"
echo "  iActivity Build & Packaging Utility     "
echo "------------------------------------------"

# 1. Build the binary
echo "🏗️  Building $APP_NAME in Release mode..."
swift build -c release --arch arm64 --arch x86_64

if [ $? -ne 0 ]; then
    echo "❌ Error: Swift build failed."
    exit 1
fi

# 2. Update App Bundle
echo "📦 Updating $APP_NAME.app bundle..."
mkdir -p "$APP_NAME.app/Contents/MacOS"
cp ".build/apple/Products/Release/$APP_NAME" "$APP_NAME.app/Contents/MacOS/"

# 3. Prepare DMG Staging
echo "📂 Preparing staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_NAME.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 4. Create DMG
echo "💾 Generating Disk Image (DMG)..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME Installer" \
               -srcfolder "$STAGING_DIR" \
               -ov -format UDZO \
               "$DMG_NAME"

# 5. Cleanup
rm -rf "$STAGING_DIR"

echo "------------------------------------------"
echo "✅ SUCCESS: $DMG_NAME is ready!"
echo "------------------------------------------"

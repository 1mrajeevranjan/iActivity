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

# Notarization needs a "Developer ID Application" certificate (Xcode ▸ Settings ▸ Accounts ▸
# Manage Certificates ▸ +) and a stored notarytool profile, created once with:
#   xcrun notarytool store-credentials iActivity-notary --apple-id <id> --team-id SG8NYPLMNY
# Without the certificate the DMG is signed ad hoc: it runs here, but Gatekeeper blocks it elsewhere.
IDENTITY="${DEVELOPER_ID:-$(security find-identity -v -p codesigning \
    | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-iActivity-notary}"

echo "------------------------------------------"
echo "  iActivity Build & Packaging Utility     "
echo "------------------------------------------"

# 1. Universal Release build from the Xcode project. Not sandboxed: the direct-download build
#    keeps the process lists and Move-to-Applications that the sandbox rules out.
#    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO keeps out get-task-allow, which notarization rejects.
echo "🏗️  Building $APP_NAME (Release, universal)..."
xcodebuild -project iActivity.xcodeproj -scheme "$APP_NAME" -configuration Release \
    -derivedDataPath "$DERIVED" -destination "generic/platform=macOS" -quiet \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    build

# 2. Symbol tables are ~60% of the binary and nothing reads them at runtime. Stripping drops the
#    signature, so re-sign — with the hardened runtime and a secure timestamp, both of which
#    notarization requires.
strip -rSTx "$APP/Contents/MacOS/$APP_NAME"
if [[ -n "$IDENTITY" ]]; then
    echo "🔏 Signing with $IDENTITY"
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
    echo "⚠️  No Developer ID Application certificate — signing ad hoc (cannot be notarized)."
    codesign --force --options runtime --sign - "$APP"
fi
codesign --verify --strict --verbose=2 "$APP"

# 3. Stage and create the DMG.
echo "💾 Generating Disk Image (DMG)..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"
ditto "$APP" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME Installer" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"
rm -rf "$STAGING_DIR"

# 4. Notarize and staple, so Gatekeeper accepts the DMG offline on any Mac.
if [[ -n "$IDENTITY" ]]; then
    codesign --force --timestamp --sign "$IDENTITY" "$DMG_NAME"
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "📨 Notarizing (usually a few minutes)..."
        xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
        xcrun stapler staple "$DMG_NAME"
        spctl --assess --type open --context context:primary-signature --verbose "$DMG_NAME"
    else
        echo "⚠️  No notarytool profile '$NOTARY_PROFILE' — signed but not notarized."
    fi
fi

echo "------------------------------------------"
echo "✅ SUCCESS: $DMG_NAME is ready!"
echo "------------------------------------------"

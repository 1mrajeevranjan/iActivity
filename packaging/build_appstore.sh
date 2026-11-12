#!/bin/bash
# Builds a sandboxed, signed iActivity.pkg ready for upload to App Store Connect (Transporter).
#
# Needs, from developer.apple.com → Certificates, IDs & Profiles:
#   - "Apple Distribution" (or "3rd Party Mac Developer Application") certificate in the keychain
#   - "Mac Installer Distribution" (3rd Party Mac Developer Installer) certificate in the keychain
#   - A "Mac App Store Connect" provisioning profile for com.rajeev.iActivity
#
# Usage: packaging/build_appstore.sh path/to/iActivity.provisionprofile
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="iActivity"
PROFILE="${1:?usage: $0 path/to/profile.provisionprofile}"
OUT="build/appstore"
APP="$OUT/$APP_NAME.app"

APP_IDENTITY="$(security find-identity -v -p codesigning | grep -Eo '"(Apple Distribution|3rd Party Mac Developer Application): [^"]+"' | head -1 | tr -d '"')"
PKG_IDENTITY="$(security find-identity -v | grep -Eo '"(3rd Party Mac Developer Installer|Mac Installer Distribution): [^"]+"' | head -1 | tr -d '"')"
[ -n "$APP_IDENTITY" ] || { echo "❌ No Apple Distribution certificate in keychain."; exit 1; }
[ -n "$PKG_IDENTITY" ] || { echo "❌ No Mac Installer Distribution certificate in keychain."; exit 1; }

PROFILE_PLIST="$(mktemp)"
security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
TEAM_ID="$(plutil -extract TeamIdentifier.0 raw "$PROFILE_PLIST")"
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw Info.plist)"

echo "🏗️  Building universal release binary..."
swift build -c release --arch arm64 --arch x86_64
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

echo "📦 Assembling $APP..."
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/"
strip -rSTx "$APP/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP/Contents/Info.plist"
cp iActivity.app/Contents/Resources/AppIcon.icns "$APP/Contents/Resources/"
cp packaging/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

# The profile authorises the app ID; the signature must claim the same one.
ENTITLEMENTS="$OUT/entitlements.plist"
cp packaging/iActivity.entitlements "$ENTITLEMENTS"
plutil -insert com.apple.application-identifier -string "$TEAM_ID.$BUNDLE_ID" "$ENTITLEMENTS"
plutil -insert com.apple.developer.team-identifier -string "$TEAM_ID" "$ENTITLEMENTS"

echo "🔏 Signing with $APP_IDENTITY..."
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$APP_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "📮 Building installer package..."
productbuild --component "$APP" /Applications --sign "$PKG_IDENTITY" "$OUT/$APP_NAME.pkg"
rm -f "$PROFILE_PLIST"

echo "✅ $OUT/$APP_NAME.pkg — upload with Transporter, or:"
echo "   xcrun altool --upload-app -f $OUT/$APP_NAME.pkg -t macos --apiKey KEY_ID --apiIssuer ISSUER_ID"

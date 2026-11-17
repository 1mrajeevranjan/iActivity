#!/usr/bin/env bash
# Builds with the Xcode project's settings and runs the app from ./iActivity.app.
# Ad-hoc signed without the App Store entitlements, so it runs unsandboxed with the same
# preferences and login item as always. Xcode's Run (⌘R) gives the sandboxed App Store build.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-run}"
case "$MODE" in
    run|--verify|--debug|--logs|--telemetry) ;;
    *) echo "usage: $0 [--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac

CONFIG=Release
if [[ "$MODE" == --debug ]]; then CONFIG=Debug; fi
xcodebuild -project iActivity.xcodeproj -scheme iActivity -configuration "$CONFIG" \
    -derivedDataPath .build/xcode -destination "generic/platform=macOS" -quiet \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= \
    build

APP_BUNDLE="$PWD/iActivity.app"
pkill -x iActivity >/dev/null 2>&1 || true
rm -rf "$APP_BUNDLE"
ditto ".build/xcode/Build/Products/$CONFIG/iActivity.app" "$APP_BUNDLE"

if [[ "$MODE" == --debug ]]; then
    exec lldb -- "$APP_BUNDLE/Contents/MacOS/iActivity"
fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
    --verify) sleep 1; pgrep -x iActivity >/dev/null ;;
    --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "iActivity"' ;;
    --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.rajeev.iActivity"' ;;
esac

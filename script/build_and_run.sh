#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-run}"
case "$MODE" in
    run|--verify|--debug|--logs|--telemetry) ;;
    *) echo "usage: $0 [--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac

swift build -c release
APP_BINARY="$(swift build -c release --show-bin-path)/iActivity"
APP_BUNDLE="$PWD/iActivity.app"
pkill -x iActivity >/dev/null 2>&1 || true
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$APP_BINARY" "$APP_BUNDLE/Contents/MacOS/iActivity"
if [[ "$MODE" != --debug ]]; then strip -rSTx "$APP_BUNDLE/Contents/MacOS/iActivity"; fi
codesign --force --sign - "$APP_BUNDLE"

if [[ "$MODE" == --debug ]]; then
    exec lldb -- "$APP_BUNDLE/Contents/MacOS/iActivity"
fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
    --verify) sleep 1; pgrep -x iActivity >/dev/null ;;
    --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "iActivity"' ;;
    --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.rajeev.iActivity"' ;;
esac

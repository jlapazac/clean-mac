#!/usr/bin/env bash
# Builds a release binary and wraps it in dist/CleanMac.app with an ad hoc signature,
# so macOS can grant it Full Disk Access.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product CleanMac
BIN="$(swift build -c release --show-bin-path)/CleanMac"

APP="dist/CleanMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CleanMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP"
echo "Built $APP"

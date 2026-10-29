#!/bin/bash
# Builds Klck and assembles a runnable Klck.app bundle (no Xcode required).
#
# Usage: ./build_app.sh [release|debug]
#
# Output is quiet on purpose: compiler errors and warnings, then the bundle
# path. That keeps build logs short enough for agents and CI to read.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="Klck.app"

swift build -c "$CONFIG" --quiet

BIN=".build/$CONFIG/Klck"
if [[ ! -f "$BIN" ]]; then
    echo "Build product not found at $BIN" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Klck"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# macOS remembers microphone permission per code signature. An ad-hoc
# signature changes on every build, so the mic prompt comes back every time.
# Signing with an Apple Development certificate keeps the identity stable and
# the permission sticks. Override with SIGN_IDENTITY="-" to force ad-hoc, or
# set it to any identity name/hash from `security find-identity -p codesigning`.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | awk '/"Apple Development/ && !found { print $2; found = 1 }')
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
codesign --force --sign "$SIGN_IDENTITY" "$APP" 2>/dev/null

SIGNER=$(codesign -dvv "$APP" 2>&1 | awk -F= '/^Authority=/ && !found { print $2; found = 1 }')
echo "built $(pwd)/$APP ($CONFIG, signed: ${SIGNER:-ad-hoc})"

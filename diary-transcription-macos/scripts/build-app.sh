#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PACKAGE_DIRECTORY=${SCRIPT_DIRECTORY:h}
APP_DIRECTORY="$PACKAGE_DIRECTORY/.build/DiaryTranscription.app"

cd "$PACKAGE_DIRECTORY"
swift build -c release --product DiaryTranscription
PRODUCT_DIRECTORY=$(swift build -c release --show-bin-path)

rm -rf "$APP_DIRECTORY"
mkdir -p "$APP_DIRECTORY/Contents/MacOS"
mkdir -p "$APP_DIRECTORY/Contents/Resources"
cp "$PACKAGE_DIRECTORY/Resources/Info.plist" "$APP_DIRECTORY/Contents/Info.plist"
cp "$PRODUCT_DIRECTORY/DiaryTranscription" "$APP_DIRECTORY/Contents/MacOS/DiaryTranscription"

codesign \
    --force \
    --sign - \
    --entitlements "$PACKAGE_DIRECTORY/Resources/DiaryTranscription.entitlements" \
    "$APP_DIRECTORY"

echo "$APP_DIRECTORY"

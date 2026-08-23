#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PACKAGE_DIRECTORY=${SCRIPT_DIRECTORY:h}
APP_DIRECTORY="$PACKAGE_DIRECTORY/.build/DiaryTranscription.app"
STAGING_DIRECTORY="$PACKAGE_DIRECTORY/.build/dmg-staging"
DIST_DIRECTORY="$PACKAGE_DIRECTORY/dist"
DMG_PATH="$DIST_DIRECTORY/DiaryTranscription-1.0.0.dmg"

"$SCRIPT_DIRECTORY/build-app.sh" >/dev/null

rm -rf "$STAGING_DIRECTORY"
mkdir -p "$STAGING_DIRECTORY" "$DIST_DIRECTORY"
cp -R "$APP_DIRECTORY" "$STAGING_DIRECTORY/Diary Transcription.app"
ln -s /Applications "$STAGING_DIRECTORY/Applications"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "Diary Transcription 1.0.0" \
    -srcfolder "$STAGING_DIRECTORY" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
shasum -a 256 "$DMG_PATH"

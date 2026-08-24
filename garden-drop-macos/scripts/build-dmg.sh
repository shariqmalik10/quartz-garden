#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="GardenDrop"
DISPLAY_NAME="Garden Drop"
VERSION="${GARDEN_DROP_VERSION:-0.4.5}"
BUILD_NUMBER="${GARDEN_DROP_BUILD:-$(date +%Y%m%d%H%M)}"
BUILD_CONFIGURATION="release"
BUILD_ROOT="$PROJECT_ROOT/.build"
DIST_DIR="$PROJECT_ROOT/dist"
APP_PATH="$BUILD_ROOT/$APP_NAME.app"
STAGING_DIR="$BUILD_ROOT/dmg-staging"
DMG_PATH="$DIST_DIR/GardenDrop-$VERSION.dmg"
ICON_SOURCE="$PROJECT_ROOT/Resources/GardenDrop-AppIcon-1024.png"
ICONSET_DIR="$BUILD_ROOT/GardenDrop.iconset"

echo "Building $DISPLAY_NAME $VERSION ($BUILD_NUMBER)…"
swift build --configuration "$BUILD_CONFIGURATION" --product "$APP_NAME"
BIN_PATH="$(swift build --configuration "$BUILD_CONFIGURATION" --show-bin-path)"

rm -rf "$APP_PATH" "$STAGING_DIR"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$DIST_DIR"

cp "$BIN_PATH/$APP_NAME" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/GardenDrop.icns"

codesign --force --deep --sign - "$APP_PATH" >/dev/null

mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/$DISPLAY_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$DISPLAY_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "DMG: $DMG_PATH"
echo "SHA256: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

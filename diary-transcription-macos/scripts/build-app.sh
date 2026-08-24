#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PACKAGE_DIRECTORY=${SCRIPT_DIRECTORY:h}
APP_DIRECTORY="$PACKAGE_DIRECTORY/.build/Yap.app"
DERIVED_DATA_DIRECTORY="$PACKAGE_DIRECTORY/.build/xcode-derived"
PRODUCT_DIRECTORY="$DERIVED_DATA_DIRECTORY/Build/Products/Release"
ICON_SOURCE="$PACKAGE_DIRECTORY/Resources/Yap-AppIcon-1024.png"
ICONSET_DIRECTORY="$PACKAGE_DIRECTORY/.build/Yap.iconset"

cd "$PACKAGE_DIRECTORY"
xcodebuild \
    -scheme Yap \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA_DIRECTORY" \
    build \
    CODE_SIGNING_ALLOWED=NO

if [[ ! -x "$PRODUCT_DIRECTORY/Yap" ]]; then
    echo "Release executable not found at $PRODUCT_DIRECTORY/Yap" >&2
    exit 1
fi

rm -rf "$APP_DIRECTORY"
mkdir -p "$APP_DIRECTORY/Contents/MacOS"
mkdir -p "$APP_DIRECTORY/Contents/Resources"
cp "$PACKAGE_DIRECTORY/Resources/Info.plist" "$APP_DIRECTORY/Contents/Info.plist"
cp "$PRODUCT_DIRECTORY/Yap" "$APP_DIRECTORY/Contents/MacOS/Yap"
cp "$PACKAGE_DIRECTORY/THIRD_PARTY_NOTICES.md" "$APP_DIRECTORY/Contents/Resources/THIRD_PARTY_NOTICES.md"

rm -rf "$ICONSET_DIRECTORY"
mkdir -p "$ICONSET_DIRECTORY"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIRECTORY/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET_DIRECTORY/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIRECTORY" -o "$APP_DIRECTORY/Contents/Resources/Yap.icns"

LICENSE_DIRECTORY="$APP_DIRECTORY/Contents/Resources/Licenses"
CHECKOUT_DIRECTORY="$DERIVED_DATA_DIRECTORY/SourcePackages/checkouts"
mkdir -p "$LICENSE_DIRECTORY"
LICENSE_MAPPINGS=(
    "mlx-swift/LICENSE:MLX_SWIFT.txt"
    "mlx-swift-lm/LICENSE:MLX_SWIFT_LM.txt"
    "mlx-audio-swift/LICENSE:MLX_AUDIO_SWIFT.txt"
    "swift-huggingface/LICENSE:SWIFT_HUGGINGFACE.txt"
    "swift-transformers/LICENSE:SWIFT_TRANSFORMERS.txt"
    "EventSource/LICENSE.md:EVENTSOURCE.txt"
    "swift-jinja/LICENSE:SWIFT_JINJA.txt"
    "swift-collections/LICENSE.txt:SWIFT_COLLECTIONS.txt"
    "swift-crypto/LICENSE.txt:SWIFT_CRYPTO.txt"
    "swift-asn1/LICENSE.txt:SWIFT_ASN1.txt"
    "swift-numerics/LICENSE.txt:SWIFT_NUMERICS.txt"
    "swift-syntax/LICENSE.txt:SWIFT_SYNTAX.txt"
    "yyjson/LICENSE:YYJSON.txt"
)
for LICENSE_MAPPING in "${LICENSE_MAPPINGS[@]}"; do
    SOURCE_PATH=${LICENSE_MAPPING%%:*}
    DESTINATION_NAME=${LICENSE_MAPPING#*:}
    if [[ ! -f "$CHECKOUT_DIRECTORY/$SOURCE_PATH" ]]; then
        echo "Missing dependency license: $SOURCE_PATH" >&2
        exit 1
    fi
    cp "$CHECKOUT_DIRECTORY/$SOURCE_PATH" "$LICENSE_DIRECTORY/$DESTINATION_NAME"
done
cp "$CHECKOUT_DIRECTORY/swift-huggingface/LICENSE" "$LICENSE_DIRECTORY/COHERE_MODEL_APACHE-2.0.txt"

# SwiftPM resource bundles include MLX's compiled Metal library. They must sit
# in the app's Resources directory for Bundle.module lookup in a packaged app.
for RESOURCE_BUNDLE in "$PRODUCT_DIRECTORY"/*.bundle(N); do
    cp -R "$RESOURCE_BUNDLE" "$APP_DIRECTORY/Contents/Resources/"
done

if [[ ! -f "$APP_DIRECTORY/Contents/Resources/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib" ]]; then
    echo "MLX Metal shader bundle was not produced by Xcode." >&2
    exit 1
fi

# MLX first looks beside the executable for `mlx.metallib`. Keeping a colocated
# copy makes the packaged app independent of SwiftPM bundle discovery, which is
# not reliable when the package executable is assembled into an app manually.
cp \
    "$APP_DIRECTORY/Contents/Resources/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib" \
    "$APP_DIRECTORY/Contents/MacOS/mlx.metallib"

codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "$PACKAGE_DIRECTORY/Resources/Yap.entitlements" \
    "$APP_DIRECTORY"

echo "$APP_DIRECTORY"

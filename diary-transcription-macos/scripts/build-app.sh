#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY=${0:A:h}
PACKAGE_DIRECTORY=${SCRIPT_DIRECTORY:h}
APP_DIRECTORY="$PACKAGE_DIRECTORY/.build/DiaryTranscription.app"
DERIVED_DATA_DIRECTORY="$PACKAGE_DIRECTORY/.build/xcode-derived"
PRODUCT_DIRECTORY="$DERIVED_DATA_DIRECTORY/Build/Products/Release"

cd "$PACKAGE_DIRECTORY"
xcodebuild \
    -scheme DiaryTranscription \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA_DIRECTORY" \
    build \
    CODE_SIGNING_ALLOWED=NO

if [[ ! -x "$PRODUCT_DIRECTORY/DiaryTranscription" ]]; then
    echo "Release executable not found at $PRODUCT_DIRECTORY/DiaryTranscription" >&2
    exit 1
fi

rm -rf "$APP_DIRECTORY"
mkdir -p "$APP_DIRECTORY/Contents/MacOS"
mkdir -p "$APP_DIRECTORY/Contents/Resources"
cp "$PACKAGE_DIRECTORY/Resources/Info.plist" "$APP_DIRECTORY/Contents/Info.plist"
cp "$PRODUCT_DIRECTORY/DiaryTranscription" "$APP_DIRECTORY/Contents/MacOS/DiaryTranscription"
cp "$PACKAGE_DIRECTORY/THIRD_PARTY_NOTICES.md" "$APP_DIRECTORY/Contents/Resources/THIRD_PARTY_NOTICES.md"

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
    --entitlements "$PACKAGE_DIRECTORY/Resources/DiaryTranscription.entitlements" \
    "$APP_DIRECTORY"

echo "$APP_DIRECTORY"

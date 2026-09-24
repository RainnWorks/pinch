#!/bin/sh
# Usage: ./build.sh                 ad-hoc signed, for local use
#        IDENTITY="Developer ID Application: …" ./build.sh   signed for release
set -e
cd "$(dirname "$0")"
VERSION="$(cat VERSION)"
IDENTITY="${IDENTITY:--}"
APP="Pinch.app"
BUILD="$(mktemp -d)"
SPARKLE_VERSION="2.10.0"
SPARKLE_SHA256="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"
SPARKLE=".build/sparkle-$SPARKLE_VERSION"

if [ ! -d "$SPARKLE/Sparkle.framework" ]; then
  mkdir -p "$SPARKLE"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$BUILD/sparkle.tar.xz"
  echo "$SPARKLE_SHA256  $BUILD/sparkle.tar.xz" | shasum -a 256 -c - >/dev/null
  tar -xf "$BUILD/sparkle.tar.xz" -C "$SPARKLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# Pinch is not sandboxed, so Sparkle's XPC services are not needed.
rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14.0" -F "$SPARKLE" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    Sources/*.swift -o "$BUILD/Pinch-$arch"
done
lipo -create "$BUILD/Pinch-arm64" "$BUILD/Pinch-x86_64" -output "$APP/Contents/MacOS/Pinch"

ICONSET="$BUILD/Pinch.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Pinch.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>works.rainn.pinch</string>
  <key>CFBundleName</key><string>Pinch</string>
  <key>CFBundleExecutable</key><string>Pinch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleIconFile</key><string>Pinch</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSAppleEventsUsageDescription</key><string>Pinch passes AirPods presses on to Spotify or Music.</string>
  <key>SUFeedURL</key><string>https://github.com/RainnWorks/pinch/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key><string>u3ZheIeb81NurueqlFoFV2mfOMqXaHVVTC0iLdDt75Y=</string>
  <key>SUEnableAutomaticChecks</key><true/>
</dict></plist>
PLIST

SIGN="codesign --force --sign $IDENTITY"
[ "$IDENTITY" = "-" ] || SIGN="$SIGN --options runtime --timestamp"
# Sparkle's helpers must be signed before the framework, and the framework before the app.
SPARKLE_B="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
$SIGN "$SPARKLE_B/Autoupdate"
$SIGN "$SPARKLE_B/Updater.app"
$SIGN "$APP/Contents/Frameworks/Sparkle.framework"
$SIGN --entitlements Pinch.entitlements "$APP"
echo "Built $APP $VERSION"

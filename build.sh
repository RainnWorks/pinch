#!/bin/sh
# Usage: ./build.sh                 ad-hoc signed, for local use
#        IDENTITY="Developer ID Application: …" ./build.sh   signed for release
set -e
cd "$(dirname "$0")"
VERSION="$(cat VERSION)"
IDENTITY="${IDENTITY:--}"
APP="Pinch.app"
BUILD="$(mktemp -d)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14.0" Sources/*.swift -o "$BUILD/Pinch-$arch"
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
</dict></plist>
PLIST

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --entitlements Pinch.entitlements --sign "$IDENTITY" "$APP"
fi
echo "Built $APP $VERSION"

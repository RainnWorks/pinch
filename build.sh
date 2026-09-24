#!/bin/sh
set -e
cd "$(dirname "$0")"
APP="Pinch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ICONSET="$(mktemp -d)/Pinch.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) assets/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Pinch.icns"
swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/Pinch"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.thenairn.pinch</string>
  <key>CFBundleName</key><string>Pinch</string>
  <key>CFBundleExecutable</key><string>Pinch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>Pinch</string>
  <key>NSAppleEventsUsageDescription</key><string>Pinch passes AirPods presses on to Spotify or Music.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"

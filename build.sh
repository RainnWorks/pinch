#!/bin/sh
set -e
cd "$(dirname "$0")"
APP="Pinch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/Pinch"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.thenairn.pinch</string>
  <key>CFBundleName</key><string>Pinch</string>
  <key>CFBundleExecutable</key><string>Pinch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Pinch passes AirPods presses on to Spotify or Music.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"

#!/bin/sh
# Builds, signs, notarizes and zips Pinch for a GitHub release.
# Needs a Developer ID Application certificate in the keychain and a notarytool
# profile: xcrun notarytool store-credentials pinch-notary
set -e
cd "$(dirname "$0")"
: "${IDENTITY:?Set IDENTITY to the Developer ID Application certificate name}"
PROFILE="${NOTARY_PROFILE:-pinch-notary}"
VERSION="$(cat VERSION)"
ZIP="dist/Pinch-$VERSION.zip"

IDENTITY="$IDENTITY" ./build.sh
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent Pinch.app "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple Pinch.app
rm -f "$ZIP"
ditto -c -k --keepParent Pinch.app "$ZIP"
spctl --assess --type execute --verbose Pinch.app
echo "Release ready: $ZIP"

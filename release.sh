#!/bin/sh
# Builds, signs, notarizes and zips Pinch for a GitHub release.
# Signing and notarization go through rw-apple: see RainnWorks/apple-signing.
set -e
cd "$(dirname "$0")"
VERSION="$(cat VERSION)"
ZIP="dist/Pinch-$VERSION.zip"

rw-apple sync pinch
IDENTITY="Developer ID Application: RainnWorks (53W966FBFP)" ./build.sh
rw-apple notarize Pinch.app
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent Pinch.app "$ZIP"
spctl --assess --type execute --verbose Pinch.app
echo "Release ready: $ZIP"

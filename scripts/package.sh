#!/usr/bin/env bash
# Builds a Release MdViewer.app signed with the local development identity (not notarized)
# and zips it into build/MdViewer-<version>.zip for GitHub Releases.
# Usage: ./scripts/package.sh [--install]   (--install also copies the app to /Applications)
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"

xcodegen generate --quiet
xcodebuild -scheme MdViewer -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" build -quiet

APP="$DERIVED_DATA/Build/Products/Release/MdViewer.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="$BUILD_DIR/MdViewer-$VERSION.zip"

codesign --verify --deep --strict "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Packaged $ZIP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x MdViewer || true
  rm -rf /Applications/MdViewer.app
  ditto "$APP" /Applications/MdViewer.app
  # Launching once registers the Quick Look extension; then reset Quick Look's cache.
  open -g /Applications/MdViewer.app
  qlmanage -r >/dev/null 2>&1 || true
  echo "Installed /Applications/MdViewer.app"
fi

# Remove the intermediate build so Spotlight and Launchpad only list one MdViewer.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP"
rm -rf "$APP"

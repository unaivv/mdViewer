#!/usr/bin/env bash
#
# Builds a signed, notarized and stapled MdViewer release into build/.
#
# Requirements (see README "Distribution"):
#   - A "Developer ID Application" signing identity in the login keychain
#     (paid Apple Developer Program membership).
#   - A notarytool keychain profile, created once with:
#       xcrun notarytool store-credentials <profile-name> --apple-id <id> --team-id <team>
#   - NOTARY_PROFILE=<profile-name> in the environment.
#
# Optional environment:
#   TEAM_ID   Team to sign for (default: taken from the Developer ID identity).
#
# Output: build/MdViewer-<version>.zip and build/MdViewer-<version>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

readonly SCHEME="MdViewer"
readonly APP_NAME="MdViewer"
readonly BUILD_DIR="build"
readonly ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
readonly EXPORT_DIR="$BUILD_DIR/export"
readonly EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

fail() {
  echo "error: $*" >&2
  exit 1
}

step() {
  echo "==> $*"
}

# --- Preconditions (fail fast, before any build work) -------------------------------

identity="$(security find-identity -v -p codesigning | grep -m1 '"Developer ID Application' || true)"
if [[ -z "$identity" ]]; then
  fail 'no "Developer ID Application" signing identity found in the keychain.
       Distribution outside the App Store requires a Developer ID certificate
       (paid Apple Developer Program). Create it in Xcode > Settings > Accounts >
       Manage Certificates, or at https://developer.apple.com/account/resources/certificates.'
fi

: "${NOTARY_PROFILE:?error: set NOTARY_PROFILE to a notarytool keychain profile (create one with: xcrun notarytool store-credentials <name>)}"

if [[ -z "${TEAM_ID:-}" ]]; then
  # Identity looks like: 1) HASH "Developer ID Application: Name (TEAMID)"
  TEAM_ID="$(sed -E 's/.*\(([A-Z0-9]{10})\)".*/\1/' <<<"$identity")"
fi
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "could not determine TEAM_ID; set it explicitly."

command -v xcodegen >/dev/null || fail "xcodegen is not installed (brew install xcodegen)."

# --- Build ---------------------------------------------------------------------------

step "Generating Xcode project"
xcodegen generate --quiet

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

step "Archiving Release (team $TEAM_ID)"
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

step "Exporting with Developer ID"
cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

readonly APP_PATH="$EXPORT_DIR/$APP_NAME.app"
[[ -d "$APP_PATH" ]] || fail "export did not produce $APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
readonly ZIP_PATH="$BUILD_DIR/$APP_NAME-$version.zip"
readonly DMG_PATH="$BUILD_DIR/$APP_NAME-$version.dmg"

# --- Notarize the app ------------------------------------------------------------------

step "Notarizing app (profile $NOTARY_PROFILE)"
submission_zip="$BUILD_DIR/$APP_NAME-notarization.zip"
ditto -c -k --keepParent "$APP_PATH" "$submission_zip"
xcrun notarytool submit "$submission_zip" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$submission_zip"

step "Stapling app"
xcrun stapler staple "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"

# --- Packages --------------------------------------------------------------------------

step "Creating $ZIP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

step "Creating $DMG_PATH"
rm -f "$DMG_PATH"
dmg_root="$(mktemp -d)"
trap 'rm -rf "$dmg_root"' EXIT
cp -R "$APP_PATH" "$dmg_root/"
ln -s /Applications "$dmg_root/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$dmg_root" -fs HFS+ -format UDZO "$DMG_PATH" >/dev/null
codesign --sign "Developer ID Application" --timestamp "$DMG_PATH"

step "Notarizing and stapling dmg"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

step "Done"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"

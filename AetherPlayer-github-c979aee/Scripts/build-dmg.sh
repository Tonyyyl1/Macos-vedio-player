#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
APP_NAME="${APP_NAME:-AetherPlayer}"
SCHEME="AetherPlayer"
DEVELOPER_ID="${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application: ...' identity}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

# Extract team ID from the Developer ID string: "Developer ID Application: Name (TEAMID)"
TEAM_ID="${DEVELOPER_ID##*(}"
TEAM_ID="${TEAM_ID%)}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 1. Universal archive (arm64 + x86_64 via ARCHS_STANDARD / ONLY_ACTIVE_ARCH=NO).
xcodebuild -project AetherPlayer.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" archive ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID"

# 2. Export with Developer ID signing.
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

APP="$EXPORT_DIR/$APP_NAME.app"
VOL_ICON="docs/images/AppIcon.icns"

# 2b. Notarize + staple the .app BEFORE it is packaged into the DMG.
# Sparkle extracts the .app out of the DMG and discards the DMG, so the
# notarization ticket must live on the .app itself. Stapling only the .dmg
# (as this script used to) leaves the installed copy unstapled, and Sparkle's
# offline Gatekeeper check then fails the update with the generic error
# "An error occurred while running the updater. Please try again later."
if [ -n "$NOTARY_PROFILE" ]; then
  APP_ZIP="$BUILD_DIR/$APP_NAME-app.zip"
  ditto -c -k --keepParent "$APP" "$APP_ZIP"
  xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$APP_ZIP"
fi

# 3. Package into a branded .dmg: the app, a drag-to-/Applications shortcut, and a volume icon.
STAGE="$BUILD_DIR/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
[ -f "$VOL_ICON" ] && cp "$VOL_ICON" "$STAGE/.VolumeIcon.icns"

# Build a writable image first so we can flag the volume icon, then convert to compressed read-only.
RW_DMG="$BUILD_DIR/$APP_NAME-rw.dmg"
rm -f "$RW_DMG" "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDRW "$RW_DMG"

if [ -f "$VOL_ICON" ]; then
  MOUNT_DIR="$(mktemp -d)"
  hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -noverify
  # SetFile (from the Xcode command line tools) flags the volume to use its .VolumeIcon.icns.
  # Best-effort: if SetFile is unavailable the DMG still ships, just without the custom icon.
  command -v SetFile >/dev/null 2>&1 && SetFile -a C "$MOUNT_DIR" || true
  hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR"
fi

hdiutil convert "$RW_DMG" -format UDZO -o "$DMG"
rm -f "$RW_DMG"

# 4. Notarize + staple the .dmg (skipped if NOTARY_PROFILE unset; local smoke
#    test only). The .app inside was already notarized + stapled in step 2b.
if [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"

  # Guard against the stapling-gap regression: the .app Sparkle extracts from
  # the DMG MUST carry its own stapled ticket, or in-app updates fail. Verify
  # against the real DMG contents, not the export copy.
  VERIFY_MNT="$(mktemp -d)"
  hdiutil attach "$DMG" -mountpoint "$VERIFY_MNT" -nobrowse -noverify -quiet
  if xcrun stapler validate "$VERIFY_MNT/$APP_NAME.app" >/dev/null 2>&1; then
    hdiutil detach "$VERIFY_MNT" -quiet || hdiutil detach "$VERIFY_MNT"
  else
    hdiutil detach "$VERIFY_MNT" -quiet || true
    echo "ERROR: $APP_NAME.app inside the DMG has no stapled notarization ticket." >&2
    echo "       Sparkle updates would fail. Aborting." >&2
    exit 1
  fi
else
  echo "NOTARY_PROFILE unset: built + signed but NOT notarized (won't pass Gatekeeper elsewhere)."
fi

echo "Output: $DMG"

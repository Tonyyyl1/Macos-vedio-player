#!/usr/bin/env bash
# Generate the AppIcon PNG set and AppIcon.icns from a 1024x1024 RGBA master.
# Usage: Scripts/generate-icons.sh [master.png]
set -euo pipefail

MASTER="${1:-docs/images/aetherplayer-icon.png}"
ICONSET_DIR="Sources/AetherPlayer/Resources/Assets.xcassets/AppIcon.appiconset"
ICNS_OUT="docs/images/AppIcon.icns"

if [[ "$(sips -g hasAlpha "$MASTER" | awk '/hasAlpha/{print $2}')" != "yes" ]]; then
  echo "error: $MASTER has no alpha channel (background would stay opaque)." >&2
  exit 1
fi

# Asset-catalog PNGs (names match the existing Contents.json).
for size in 16 32 64 128 256 512 1024; do
  sips -s format png -z "$size" "$size" "$MASTER" \
       --out "$ICONSET_DIR/icon_${size}.png" >/dev/null
done

# .icns for the DMG volume icon.
TMP="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$TMP"
sips -z 16 16     "$MASTER" --out "$TMP/icon_16x16.png"      >/dev/null
sips -z 32 32     "$MASTER" --out "$TMP/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$MASTER" --out "$TMP/icon_32x32.png"      >/dev/null
sips -z 64 64     "$MASTER" --out "$TMP/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$MASTER" --out "$TMP/icon_128x128.png"    >/dev/null
sips -z 256 256   "$MASTER" --out "$TMP/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$MASTER" --out "$TMP/icon_256x256.png"    >/dev/null
sips -z 512 512   "$MASTER" --out "$TMP/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$MASTER" --out "$TMP/icon_512x512.png"    >/dev/null
cp "$MASTER" "$TMP/icon_512x512@2x.png"
iconutil -c icns "$TMP" -o "$ICNS_OUT"

echo "Generated icon set in $ICONSET_DIR and $ICNS_OUT"

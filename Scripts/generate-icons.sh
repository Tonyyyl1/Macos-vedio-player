#!/usr/bin/env bash
# Generate validated AppIcon PNG sets and, for macOS/all, AppIcon.icns.
# Usage: Scripts/generate-icons.sh [master.png] [macos-assets|macos|ios|all] [output-root]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="${1:-$ROOT/docs/images/aetherplayer-icon.png}"
TARGET="${2:-all}"
OUTPUT_ROOT="${3:-$ROOT}"
MAC_ICONSET_DIR="$OUTPUT_ROOT/Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset"
IOS_ICONSET_DIR="$OUTPUT_ROOT/Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset"
ICNS_OUT="$OUTPUT_ROOT/docs/images/AppIcon.icns"
STAGING_ROOT=""

MAC_FILES=(icon_16.png icon_32.png icon_64.png icon_128.png icon_256.png icon_512.png icon_1024.png)
MAC_SIZES=(16 32 64 128 256 512 1024)
ICNS_FILES=(
  icon_16x16.png icon_16x16@2x.png
  icon_32x32.png icon_32x32@2x.png
  icon_128x128.png icon_128x128@2x.png
  icon_256x256.png icon_256x256@2x.png
  icon_512x512.png icon_512x512@2x.png
)
ICNS_SIZES=(16 32 32 64 128 256 256 512 512 1024)

fail() {
  echo "error: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$STAGING_ROOT" && -d "$STAGING_ROOT" ]]; then
    rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

metadata_value() {
  local key="$1"
  awk -v key="$key" '$1 == key ":" { print $2; exit }'
}

validate_png() {
  local png="$1"
  local expected_width="$2"
  local expected_height="$3"
  local metadata width height format alpha

  [[ -s "$png" ]] || fail "expected non-empty PNG: $png"
  metadata="$(sips -g pixelWidth -g pixelHeight -g format -g hasAlpha "$png" 2>/dev/null)" \
    || fail "cannot inspect PNG: $png"
  width="$(printf '%s\n' "$metadata" | metadata_value pixelWidth)"
  height="$(printf '%s\n' "$metadata" | metadata_value pixelHeight)"
  format="$(printf '%s\n' "$metadata" | metadata_value format)"
  alpha="$(printf '%s\n' "$metadata" | metadata_value hasAlpha)"

  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] \
    || fail "unexpected dimensions for $png: got ${width:-unknown}x${height:-unknown}, expected ${expected_width}x${expected_height}"
  [[ "$(printf '%s' "$format" | tr '[:upper:]' '[:lower:]')" == "png" ]] || fail "expected PNG format: $png"
  [[ "$alpha" == "yes" ]] || fail "expected alpha channel: $png"
}

create_png() {
  local size="$1"
  local destination="$2"
  sips -s format png -z "$size" "$size" "$MASTER" --out "$destination" >/dev/null \
    || fail "could not create PNG: $destination"
  validate_png "$destination" "$size" "$size"
}

create_macos_catalog() {
  local destination="$1"
  local i
  mkdir -p "$destination"
  for i in "${!MAC_FILES[@]}"; do
    create_png "${MAC_SIZES[$i]}" "$destination/${MAC_FILES[$i]}"
  done
}

create_iconset() {
  local destination="$1"
  local i
  mkdir -p "$destination"
  for i in "${!ICNS_FILES[@]}"; do
    create_png "${ICNS_SIZES[$i]}" "$destination/${ICNS_FILES[$i]}"
  done
}

validate_iconset() {
  local iconset="$1"
  local i
  for i in "${!ICNS_FILES[@]}"; do
    validate_png "$iconset/${ICNS_FILES[$i]}" "${ICNS_SIZES[$i]}" "${ICNS_SIZES[$i]}"
  done
}

run_iconutil() {
  local description="$1"
  shift
  local stderr_file="$STAGING_ROOT/${description}.stderr"
  local status

  if "$ICONUTIL" "$@" 2>"$stderr_file"; then
    return 0
  fi

  status=$?
  echo "error: iconutil failed during $description (path: $ICONUTIL, exit: $status)" >&2
  [[ -s "$stderr_file" ]] && sed 's/^/iconutil: /' "$stderr_file" >&2
  exit "$status"
}

try_iconutil_package() {
  local stderr_file="$STAGING_ROOT/iconutil-package.stderr"
  local status

  if "$ICONUTIL" -c icns "$STAGING_ROOT/AppIcon.iconset" -o "$STAGED_ICNS" 2>"$stderr_file"; then
    status=0
  else
    status=$?
  fi

  if (( status == 0 )) && [[ -s "$STAGED_ICNS" ]] && file "$STAGED_ICNS" | grep -qi 'icon'; then
    return 0
  fi

  echo "error: iconutil could not package the iconset (path: $ICONUTIL, exit: $status)" >&2
  [[ -s "$stderr_file" ]] && sed 's/^/iconutil: /' "$stderr_file" >&2
  rm -f "$STAGED_ICNS"
  if (( status == 0 )); then
    return 1
  fi
  return "$status"
}

publish_file() {
  local staged="$1"
  local destination="$2"
  mkdir -p "$(dirname "$destination")"
  mv "$staged" "$destination"
}

case "$TARGET" in
  macos-assets|macos|ios|all) ;;
  *) echo "error: target must be macos-assets, macos, ios, or all" >&2; exit 64 ;;
esac

[[ -f "$MASTER" ]] || fail "master PNG does not exist: $MASTER"
validate_png "$MASTER" 1024 1024

mkdir -p "$OUTPUT_ROOT"
STAGING_ROOT="$(mktemp -d "$OUTPUT_ROOT/.generate-icons.XXXXXX")"

if [[ "$TARGET" == "ios" || "$TARGET" == "all" ]]; then
  mkdir -p "$STAGING_ROOT/ios"
  create_png 1024 "$STAGING_ROOT/ios/icon_1024.png"
fi

if [[ "$TARGET" == "macos-assets" || "$TARGET" == "macos" || "$TARGET" == "all" ]]; then
  STAGED_ASSETS="$STAGING_ROOT/Assets.xcassets"
  mkdir -p "$STAGED_ASSETS/AppIcon.appiconset"
  cp "$ROOT/Sources/macOS/Resources/Assets.xcassets/Contents.json" "$STAGED_ASSETS/Contents.json"
  cp "$ROOT/Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" \
    "$STAGED_ASSETS/AppIcon.appiconset/Contents.json"
  create_macos_catalog "$STAGED_ASSETS/AppIcon.appiconset"
fi

if [[ "$TARGET" == "macos" || "$TARGET" == "all" ]]; then
  create_iconset "$STAGING_ROOT/AppIcon.iconset"
  validate_iconset "$STAGING_ROOT/AppIcon.iconset"

  if [[ -n "${ICONUTIL:-}" ]]; then
    ICONUTIL="$(command -v "$ICONUTIL" 2>/dev/null || true)"
  else
    ICONUTIL="$(command -v iconutil 2>/dev/null || true)"
  fi
  [[ -n "$ICONUTIL" && -x "$ICONUTIL" ]] || fail "iconutil is unavailable; macOS ICNS was not regenerated"

  STAGED_ICNS="$STAGING_ROOT/AppIcon.icns"
  if try_iconutil_package; then
    :
  else
    iconutil_status=$?
    echo "error: macOS ICNS was not regenerated; use an environment where iconutil can package and round-trip the standard iconset" >&2
    exit "$iconutil_status"
  fi

  ROUNDTRIP_ICONSET="$STAGING_ROOT/roundtrip.iconset"
  run_iconutil verify -c iconset "$STAGED_ICNS" -o "$ROUNDTRIP_ICONSET"
  validate_iconset "$ROUNDTRIP_ICONSET"
fi

# Nothing under the requested output root is replaced before every requested
# artifact has been generated and validated.  Each final rename is atomic.
if [[ "$TARGET" == "macos-assets" || "$TARGET" == "macos" || "$TARGET" == "all" ]]; then
  for i in "${!MAC_FILES[@]}"; do
    publish_file "$STAGED_ASSETS/AppIcon.appiconset/${MAC_FILES[$i]}" "$MAC_ICONSET_DIR/${MAC_FILES[$i]}"
  done
fi

if [[ "$TARGET" == "macos" || "$TARGET" == "all" ]]; then
  publish_file "$STAGED_ICNS" "$ICNS_OUT"
fi

if [[ "$TARGET" == "ios" || "$TARGET" == "all" ]]; then
  publish_file "$STAGING_ROOT/ios/icon_1024.png" "$IOS_ICONSET_DIR/icon_1024.png"
fi

case "$TARGET" in
  ios) echo "Generated validated iOS icon in $IOS_ICONSET_DIR" ;;
  macos-assets) echo "Generated validated macOS icon catalog in $MAC_ICONSET_DIR; ICNS was not requested" ;;
  macos) echo "Generated validated macOS icon set in $MAC_ICONSET_DIR and $ICNS_OUT" ;;
  all) echo "Generated validated macOS and iOS icon sets, plus $ICNS_OUT" ;;
esac

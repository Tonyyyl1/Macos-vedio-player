#!/usr/bin/env bash
# Host-only integration tests for Scripts/generate-icons.sh.
#
# Real iconutil packaging requires access to macOS LaunchServices.  The Codex
# sandbox may deny that access and cause iconutil to report "Invalid Iconset"
# for a valid input.  Invoke this script only from an approved host execution
# context:
#   RUN_ICONUTIL_HOST_INTEGRATION=1 bash Tests/Scripts/generate-icons-integration-tests.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/Scripts/generate-icons.sh"
MASTER="$ROOT/docs/images/aetherplayer-icon.png"
TMP="$(mktemp -d)"

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

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

if [[ "${RUN_ICONUTIL_HOST_INTEGRATION:-}" != "1" ]]; then
  echo "SKIP: host ICNS integration was not run; set RUN_ICONUTIL_HOST_INTEGRATION=1 in an approved host environment" >&2
  exit 77
fi

metadata_value() {
  local key="$1"
  awk -v key="$key" '$1 == key ":" { print $2; exit }'
}

validate_png() {
  local png="$1"
  local expected_size="$2"
  local metadata width height format alpha

  [[ -s "$png" ]] || fail "expected non-empty PNG: $png"
  metadata="$(sips -g pixelWidth -g pixelHeight -g format -g hasAlpha "$png" 2>/dev/null)" \
    || fail "cannot inspect PNG: $png"
  width="$(printf '%s\n' "$metadata" | metadata_value pixelWidth)"
  height="$(printf '%s\n' "$metadata" | metadata_value pixelHeight)"
  format="$(printf '%s\n' "$metadata" | metadata_value format)"
  alpha="$(printf '%s\n' "$metadata" | metadata_value hasAlpha)"

  [[ "$width" == "$expected_size" && "$height" == "$expected_size" ]] \
    || fail "unexpected dimensions for $png: got ${width:-unknown}x${height:-unknown}, expected ${expected_size}x${expected_size}"
  [[ "$(printf '%s' "$format" | tr '[:upper:]' '[:lower:]')" == "png" ]] \
    || fail "expected PNG format: $png"
  [[ "$alpha" == "yes" ]] || fail "expected alpha channel: $png"
}

validate_macos_catalog() {
  local catalog="$1"
  local i
  for i in "${!MAC_FILES[@]}"; do
    validate_png "$catalog/${MAC_FILES[$i]}" "${MAC_SIZES[$i]}"
  done
}

validate_icns() {
  local icns="$1"
  local unpacked="$2"
  local i metadata width height format

  [[ -s "$icns" ]] || fail "expected non-empty ICNS: $icns"
  file "$icns" | grep -qi 'icon' || fail "file did not recognize ICNS: $icns"
  metadata="$(sips -g pixelWidth -g pixelHeight -g format "$icns" 2>/dev/null)" \
    || fail "cannot inspect ICNS: $icns"
  width="$(printf '%s\n' "$metadata" | metadata_value pixelWidth)"
  height="$(printf '%s\n' "$metadata" | metadata_value pixelHeight)"
  format="$(printf '%s\n' "$metadata" | metadata_value format)"
  [[ "$width" == "1024" && "$height" == "1024" && "$format" == "icns" ]] \
    || fail "unexpected ICNS metadata for $icns"

  /usr/bin/iconutil -c iconset "$icns" -o "$unpacked" \
    || fail "host iconutil could not unpack generated ICNS: $icns"
  [[ "$(find "$unpacked" -maxdepth 1 -type f | wc -l | tr -d ' ')" == "10" ]] \
    || fail "generated ICNS did not unpack to exactly ten PNG files"
  for i in "${!ICNS_FILES[@]}"; do
    validate_png "$unpacked/${ICNS_FILES[$i]}" "${ICNS_SIZES[$i]}"
  done
}

official_digest() {
  (
    cd "$ROOT"
    find Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset \
         Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset \
         docs/images/AppIcon.icns -type f -exec shasum -a 256 {} + | sort
  )
}

run_target() {
  local target="$1"
  local output_root="$2"
  local log_file="$TMP/${target}.log"
  local status

  set +e
  bash "$SCRIPT" "$MASTER" "$target" "$output_root" >"$log_file" 2>&1
  status=$?
  set -e
  if (( status != 0 )); then
    sed 's/^/generate-icons: /' "$log_file" >&2
    if rg -q 'Invalid Iconset' "$log_file"; then
      fail "host ICNS integration hit Invalid Iconset; verify this command is running outside the restricted executor"
    fi
    fail "generate-icons target $target exited $status"
  fi
}

BEFORE="$TMP/official-before.sha256"
AFTER="$TMP/official-after.sha256"
official_digest >"$BEFORE"

printf 'host_iconutil=%s\n' "$(xcrun --find iconutil)"
printf 'codex_sandbox_environment=%s\n' "${CODEX_SANDBOX:+present}"

IOS_ROOT="$TMP/ios-output"
run_target ios "$IOS_ROOT"
validate_png "$IOS_ROOT/Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" 1024
[[ ! -e "$IOS_ROOT/Sources/macOS" && ! -e "$IOS_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "ios target created macOS artifacts"

MACOS_ASSETS_ROOT="$TMP/macos-assets-output"
run_target macos-assets "$MACOS_ASSETS_ROOT"
validate_macos_catalog "$MACOS_ASSETS_ROOT/Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset"
[[ ! -e "$MACOS_ASSETS_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "macos-assets target created ICNS"

MACOS_ROOT="$TMP/macos-output"
run_target macos "$MACOS_ROOT"
validate_macos_catalog "$MACOS_ROOT/Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset"
validate_icns "$MACOS_ROOT/docs/images/AppIcon.icns" "$TMP/macos-roundtrip.iconset"

ALL_ROOT="$TMP/all-output"
run_target all "$ALL_ROOT"
validate_macos_catalog "$ALL_ROOT/Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset"
validate_png "$ALL_ROOT/Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png" 1024
validate_icns "$ALL_ROOT/docs/images/AppIcon.icns" "$TMP/all-roundtrip.iconset"

official_digest >"$AFTER"
cmp -s "$BEFORE" "$AFTER" || fail "temporary host integration changed official icon resources"

echo "generate-icons host integration tests passed"

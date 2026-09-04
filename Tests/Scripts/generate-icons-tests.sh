#!/usr/bin/env bash
# Sandboxed regression tests for Scripts/generate-icons.sh.
#
# This suite deliberately uses mock iconutil binaries for every ICNS packaging
# case.  On this host, the Codex sandbox denies iconutil access to LaunchServices
# and makes a valid iconset look like an "Invalid Iconset".  Real packaging and
# round-trip coverage lives in generate-icons-integration-tests.sh and must be
# run with RUN_ICONUTIL_HOST_INTEGRATION=1 in an approved host environment.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/Scripts/generate-icons.sh"
MASTER="$ROOT/docs/images/aetherplayer-icon.png"
TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_failure() {
  local expected_status="$1"
  shift
  local status
  set +e
  "$@"
  status=$?
  set -e
  [[ "$status" == "$expected_status" ]] || fail "expected exit $expected_status, got $status: $*"
}

official_digest() {
  (
    cd "$ROOT"
    find Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset \
         Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset \
         docs/images/AppIcon.icns -type f -exec shasum -a 256 {} + | sort
  )
}

BEFORE="$TMP/official-before.sha256"
AFTER="$TMP/official-after.sha256"
official_digest >"$BEFORE"

IOS_ROOT="$TMP/ios-output"
bash "$SCRIPT" "$MASTER" ios "$IOS_ROOT"
IOS_ICON="$IOS_ROOT/Sources/iOS/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
[[ -s "$IOS_ICON" ]] || fail "iOS icon was not generated"
[[ ! -e "$IOS_ROOT/docs/images/AppIcon.icns" ]] || fail "iOS generation unexpectedly created an ICNS"
[[ ! -e "$IOS_ROOT/Sources/macOS" ]] || fail "iOS generation unexpectedly created macOS assets"

expect_failure 64 bash "$SCRIPT" "$MASTER" invalid "$TMP/invalid-output"
[[ ! -e "$TMP/invalid-output" ]] || fail "invalid target created output"
expect_failure 1 bash "$SCRIPT" "$TMP/missing.png" ios "$TMP/missing-output"
[[ ! -e "$TMP/missing-output" ]] || fail "missing master created output"

SMALL_MASTER="$TMP/small-master.png"
sips -z 512 512 "$MASTER" --out "$SMALL_MASTER" >/dev/null
expect_failure 1 bash "$SCRIPT" "$SMALL_MASTER" ios "$TMP/small-output"
[[ ! -e "$TMP/small-output" ]] || fail "non-1024 master created output"

NO_ALPHA_JPEG="$TMP/no-alpha.jpg"
NO_ALPHA_MASTER="$TMP/no-alpha-master.png"
sips -s format jpeg "$MASTER" --out "$NO_ALPHA_JPEG" >/dev/null
sips -s format png "$NO_ALPHA_JPEG" --out "$NO_ALPHA_MASTER" >/dev/null
sips -g hasAlpha "$NO_ALPHA_MASTER" | grep -q 'hasAlpha: no' \
  || fail "could not create a no-alpha PNG fixture"
expect_failure 1 bash "$SCRIPT" "$NO_ALPHA_MASTER" ios "$TMP/no-alpha-output"
[[ ! -e "$TMP/no-alpha-output" ]] || fail "no-alpha master created output"

FAILING_ICONUTIL="$TMP/failing-iconutil"
EMPTY_ICONUTIL="$TMP/empty-iconutil"
ROUNDTRIP_ICONUTIL="$TMP/roundtrip-iconutil"
printf '%s\n' '#!/usr/bin/env bash' 'echo "mock iconutil failure" >&2' 'exit 23' >"$FAILING_ICONUTIL"
printf '%s\n' '#!/usr/bin/env bash' 'out=""' 'while (($#)); do' '  if [[ "$1" == "-o" ]]; then out="$2"; shift 2; else shift; fi' 'done' ': >"$out"' 'exit 0' >"$EMPTY_ICONUTIL"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'out=""' \
  'mode=""' \
  'while (($#)); do' \
  '  if [[ "$1" == "-c" ]]; then mode="$2"; shift 2; elif [[ "$1" == "-o" ]]; then out="$2"; shift 2; else shift; fi' \
  'done' \
  'if [[ "$mode" == "icns" ]]; then cp "$SOURCE_ICNS" "$out"; else mkdir -p "$out"; fi' \
  'exit 0' >"$ROUNDTRIP_ICONUTIL"
chmod +x "$FAILING_ICONUTIL" "$EMPTY_ICONUTIL" "$ROUNDTRIP_ICONUTIL"

MACOS_ASSETS_ROOT="$TMP/macos-assets-output"
env ICONUTIL="$FAILING_ICONUTIL" bash "$SCRIPT" "$MASTER" macos-assets "$MACOS_ASSETS_ROOT"
[[ ! -e "$MACOS_ASSETS_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "macOS catalog generation unexpectedly created an ICNS"
for mac_icon in icon_16.png icon_32.png icon_64.png icon_128.png icon_256.png icon_512.png icon_1024.png; do
  [[ -s "$MACOS_ASSETS_ROOT/Sources/macOS/Resources/Assets.xcassets/AppIcon.appiconset/$mac_icon" ]] \
    || fail "macOS catalog generation did not create: $mac_icon"
done

MAC_ROOT="$TMP/macos-failure-output"
expect_failure 23 env ICONUTIL="$FAILING_ICONUTIL" bash "$SCRIPT" "$MASTER" macos "$MAC_ROOT"
[[ ! -e "$MAC_ROOT/Sources/macOS" && ! -e "$MAC_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "failed iconutil changed macOS output"

EMPTY_ROOT="$TMP/empty-output"
expect_failure 1 env ICONUTIL="$EMPTY_ICONUTIL" bash "$SCRIPT" "$MASTER" macos "$EMPTY_ROOT"
[[ ! -e "$EMPTY_ROOT/Sources/macOS" && ! -e "$EMPTY_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "empty ICNS output changed macOS output"

ROUNDTRIP_ROOT="$TMP/roundtrip-output"
expect_failure 1 env ICONUTIL="$ROUNDTRIP_ICONUTIL" \
  SOURCE_ICNS="$ROOT/docs/images/AppIcon.icns" bash "$SCRIPT" "$MASTER" macos "$ROUNDTRIP_ROOT"
[[ ! -e "$ROUNDTRIP_ROOT/Sources/macOS" && ! -e "$ROUNDTRIP_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "unpackable ICNS output changed macOS output"

ALL_FAILURE_ROOT="$TMP/all-failure-output"
expect_failure 23 env ICONUTIL="$FAILING_ICONUTIL" bash "$SCRIPT" "$MASTER" all "$ALL_FAILURE_ROOT"
[[ ! -e "$ALL_FAILURE_ROOT/Sources/macOS" && ! -e "$ALL_FAILURE_ROOT/Sources/iOS" && ! -e "$ALL_FAILURE_ROOT/docs/images/AppIcon.icns" ]] \
  || fail "failed all-target generation changed output"

official_digest >"$AFTER"
cmp -s "$BEFORE" "$AFTER" || fail "temporary tests changed official icon resources"

echo "generate-icons sandbox regression tests passed (host ICNS integration not run)"

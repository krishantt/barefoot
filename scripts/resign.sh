#!/usr/bin/env bash
# Rebuild and reinstall Barefoot on your iPhone.
#
# Free-account signatures expire after 7 days; run this once a week and the app
# keeps working. No App Store, no developer program, no cost.
#
#   resign              # find the plugged-in iPhone
#   resign <udid>       # or name one explicitly
set -euo pipefail

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BUNDLE=dev.krishtimil.Barefoot
APP=build/Build/Products/Debug-iphoneos/Barefoot.app

find_device() {
  local tmp udid
  tmp=$(mktemp)
  xcrun devicectl list devices --json-output "$tmp" >/dev/null 2>&1 || true
  udid=$(python3 - "$tmp" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
for d in devices:
    cp, hw = d.get("connectionProperties", {}), d.get("hardwareProperties", {})
    # physical devices tunnel over the local network; simulators live on this machine
    if cp.get("transportType") == "localNetwork" and hw.get("udid"):
        print(hw["udid"])
        break
PY
  )
  rm -f "$tmp"
  printf '%s' "$udid"
}

UDID=${1:-$(find_device)}
if [ -z "$UDID" ]; then
  echo "No iPhone found." >&2
  echo "Plug it in, unlock it, and tap Trust if prompted." >&2
  exit 1
fi

build() {
  xcodegen generate >/dev/null
  xcodebuild -project Barefoot.xcodeproj -scheme Barefoot \
    -destination 'generic/platform=iOS' -derivedDataPath build \
    -allowProvisioningUpdates build > /tmp/barefoot-build.log 2>&1 || {
      echo "Build failed:" >&2
      grep -E "error:" /tmp/barefoot-build.log | head -10 >&2
      exit 1
    }
}

install() {
  xcrun devicectl device install app --device "$UDID" "$APP" 2>&1
}

echo "Building…"
build

if ! install | grep -q "App installed"; then
  # an expired profile can leave the incremental build signed with stale data
  echo "Install failed — rebuilding from clean…"
  xcodebuild -project Barefoot.xcodeproj -scheme Barefoot \
    -destination 'generic/platform=iOS' -derivedDataPath build \
    -allowProvisioningUpdates clean build > /tmp/barefoot-build.log 2>&1
  install | tail -3
fi

if [ -f "$APP/embedded.mobileprovision" ]; then
  expires=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null \
    | plutil -extract ExpirationDate raw - 2>/dev/null || true)
  [ -n "$expires" ] && echo "Signature valid until $expires."
fi

xcrun devicectl device process launch --device "$UDID" "$BUNDLE" >/dev/null 2>&1 \
  || echo "Installed. Unlock the phone and open Barefoot."

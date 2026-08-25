#!/usr/bin/env bash
# Run a command against a throwaway 13-inch iPad simulator, then delete it.
#
#   scripts/with-ipad-sim.sh <command> [args...]   # $IPAD_UDID is exported
#
# The shared agent-sim pool is iPhone-only apart from an 11-inch iPad Air, and
# App Store iPad screenshots have to be 2064x2752, which only a 13-inch device
# produces. This device is created outside the pool, booted headless, and
# removed on exit, so it never shows up in a lease or draws a window.
set -euo pipefail

NAME="dupriq-screenshot-ipad-$$"
TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB"
RUNTIME="$(xcrun simctl list runtimes -j | python3 -c "
import json,sys
rts=[r for r in json.load(sys.stdin)['runtimes'] if r['isAvailable'] and r['platform']=='iOS']
print(sorted(rts, key=lambda r: [int(x) for x in r['version'].split('.')])[-1]['identifier'])
")"

UDID="$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")"
cleanup() { xcrun simctl delete "$UDID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null

export IPAD_UDID="$UDID"
"$@"

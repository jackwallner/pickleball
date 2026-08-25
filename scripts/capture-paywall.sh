#!/usr/bin/env bash
# Render the purchase surfaces (in-app paywall + onboarding trial step) and
# export them as PNGs.
#
# Usage:
#   scripts/capture-paywall.sh <simulator-udid> <output-dir>
#
# Why a UI test and not simctl: SubscriptionService never configures RevenueCat
# on a simulator, so a plain launch shows an empty paywall. The Debug-only
# bridge reads the bundled StoreKit catalog and the shipping paywall renders
# the scheduled prices. Headless: never opens Simulator.app.
set -euo pipefail

UDID="${1:?usage: capture-paywall.sh <udid> <output-dir>}"
OUT="${2:?usage: capture-paywall.sh <udid> <output-dir>}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT="$ROOT/build/paywall.xcresult"
rm -rf "$RESULT"
mkdir -p "$ROOT/build"

cd "$ROOT"

test_status=0
xcodebuild test \
  -project DuprIQ.xcodeproj \
  -scheme Screenshots \
  -destination "id=$UDID" \
  -resultBundlePath "$RESULT" \
  -only-testing:DuprIQScreenshots/PaywallRenderTests \
  || test_status=$?

STAGE="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$STAGE"

mkdir -p "$OUT"
python3 - "$STAGE" "$OUT" <<'PY'
import json, pathlib, shutil, sys

stage, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
manifest = json.loads((stage / "manifest.json").read_text())

copied = 0
for entry in manifest:
    for att in entry.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att.get("exportedFileName", "")
        src = stage / att["exportedFileName"]
        if not src.exists() or not name:
            continue
        # Xcode appends _0_<uuid> to every attachment name; strip it so a re-run
        # overwrites the previous capture instead of piling up.
        stem = pathlib.Path(name).stem.split("_0_")[0]
        shutil.copyfile(src, out / f"{stem}{src.suffix}")
        copied += 1
print(f"wrote {copied} attachments to {out}")
PY

if (( test_status != 0 )); then
  echo "paywall render tests failed" >&2
  exit "$test_status"
fi

for expected in onboarding_trial.png paywall_plans.png; do
  if [[ ! -f "$OUT/$expected" ]]; then
    echo "missing required capture: $expected" >&2
    exit 1
  fi
done

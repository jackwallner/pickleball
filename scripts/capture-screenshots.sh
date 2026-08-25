#!/usr/bin/env bash
# Capture the App Store screenshot set from the real app.
#
# Usage:
#   scripts/capture-screenshots.sh [--strict] <simulator-udid> <output-dir> [prefix]
#
# --strict turns the capture into a release gate: a missing control fails the
# run instead of exporting whatever happened to render. Without it the run stays
# diagnostic and exports partial sets, which is what you want while iterating
# and emphatically not what you want before uploading to App Store Connect.
#
# The iPad set needs a 13-inch device (2064x2752); the pool has no iPad Pro, so
# scripts/with-ipad-sim.sh creates a throwaway one and hands the UDID over.
# Runs headless: it never opens Simulator.app.
set -euo pipefail

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
  shift
fi

UDID="${1:?usage: capture-screenshots.sh [--strict] <udid> <output-dir> [prefix]}"
OUT="${2:?usage: capture-screenshots.sh [--strict] <udid> <output-dir> [prefix]}"
PREFIX="${3:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT="$ROOT/build/screenshots.xcresult"
rm -rf "$RESULT"
mkdir -p "$ROOT/build"

cd "$ROOT"
# Export whatever the run captured even when the test reports a failure: a
# missing element on screen 4 should not throw away screens 1 to 3.
VERSION="$(awk '/MARKETING_VERSION/ {gsub(/[":]/, "", $2); print $2; exit}' project.yml)"

# TEST_RUNNER_-prefixed settings arrive in the UI test process as plain env
# vars, which is how the runner learns the marketing version it must mark as
# already seen to keep the What's New sheet off every screenshot.
STATUS=0
xcodebuild test \
  -project DuprIQ.xcodeproj \
  -scheme Screenshots \
  -destination "id=$UDID" \
  -resultBundlePath "$RESULT" \
  -only-testing:DuprIQScreenshots/ScreenshotTests \
  TEST_RUNNER_SCREENSHOT_APP_VERSION="$VERSION" \
  SCREENSHOT_STRICT="$STRICT" \
  || STATUS=1

if [[ "$STATUS" -ne 0 ]]; then
  echo "xcodebuild reported failures; exporting what was captured" >&2
fi

STAGE="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$STAGE"

mkdir -p "$OUT"
# The manifest maps Xcode's generated filenames back to the names the test gave
# each attachment; without it every shot lands as a UUID.
python3 - "$STAGE" "$OUT" "$PREFIX" <<'PY'
import json, pathlib, shutil, sys

stage, out, prefix = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
manifest = json.loads((stage / "manifest.json").read_text())

copied = 0
for entry in manifest:
    for att in entry.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att.get("exportedFileName", "")
        src = stage / att["exportedFileName"]
        if not src.exists() or not name:
            continue
        stem = pathlib.Path(name).stem
        shutil.copyfile(src, out / f"{prefix}{stem}{src.suffix}")
        copied += 1
print(f"wrote {copied} screenshots to {out}")
PY

# In strict mode the exit code is the point: a green shell here is the only
# thing that says the set is safe to upload.
if [[ "$STRICT" -eq 1 && "$STATUS" -ne 0 ]]; then
  echo "strict capture failed; see the problems attachment in $RESULT" >&2
  exit 1
fi

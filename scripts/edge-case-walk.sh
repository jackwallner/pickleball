#!/usr/bin/env bash
# usage: scripts/edge-case-walk.sh <udid> <tag> <video 0|1> <test>...
set -uo pipefail
U="$1"; TAG="$2"; VID="$3"; shift 3
cd ~/pickleball
DD=build/motion/dd
OUT=build/edgecase/video/$TAG; mkdir -p "$OUT"
for T in "$@"; do
  if [[ "$VID" == 1 ]]; then
    xcrun simctl io "$U" recordVideo --codec h264 --force "$OUT/$T.mp4" >/dev/null 2>&1 &
    RP=$!; sleep 1.5
  fi
  TEST_RUNNER_EDGE_TAG="$TAG" xcodebuild test-without-building -project DuprIQ.xcodeproj -scheme Screenshots \
    -destination "id=$U" -derivedDataPath "$DD" -only-testing:"DuprIQScreenshots/EdgeCaseTests/$T" 2>&1 \
    | tee "$OUT/$T.log" | grep -E "Test Case .*(passed|failed)|error:" | head -8
  if [[ "$VID" == 1 ]]; then
    sleep 1; kill -INT $RP; wait $RP 2>/dev/null
    mkdir -p "$OUT/${T}_frames"
    ffmpeg -v error -i "$OUT/$T.mp4" -vf "fps=20,scale=402:-1" "$OUT/${T}_frames/f_%04d.png"
    ffmpeg -v error -i "$OUT/$T.mp4" -vf "fps=8,scale=200:-1,tile=10x4" "$OUT/${T}_sheet_%02d.png"
  fi
done

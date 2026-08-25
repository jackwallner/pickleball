#!/usr/bin/env python3
"""Upload fastlane/screenshots/<locale>/*.png to the draft ASC version.

The app ships for iPhone AND iPad, so a shot is routed to its display type by
PIXEL SIZE, not by filename: 1320x2868 is the iPhone 6.9" set, 2064x2752 the
iPad 13" set. Every display type present in the folder is replaced wholesale;
types with no matching file are left alone. A file of any other size is a
mistake and stops the run rather than being uploaded to the wrong set.

    python3 scripts/asc-upload-screenshots.py [--locale en-US]
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib as L

BUNDLE = "com.jackwallner.pickleball"

# (width, height) -> ASC screenshotDisplayType.
DISPLAY_TYPE_BY_SIZE = {
    (1320, 2868): "APP_IPHONE_67",
    (2064, 2752): "APP_IPAD_PRO_3GEN_129",
}


def png_size(path: Path) -> tuple[int, int]:
    """Width/height straight out of the PNG IHDR, so this stays dependency
    free (no PIL) like the rest of the scripts here."""
    blob = path.read_bytes()
    if blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"error: {path.name} is not a PNG")
    return (
        int.from_bytes(blob[16:20], "big"),
        int.from_bytes(blob[20:24], "big"),
    )


def upload(c: L.ASCClient, set_id: str, png: Path) -> None:
    blob = png.read_bytes()
    created = c.post(
        "/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileSize": len(blob), "fileName": png.name},
                "relationships": {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}
                },
            }
        },
    )["data"]
    for op in created["attributes"]["uploadOperations"]:
        chunk = blob[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=300).read()
    c.patch(
        f"/appScreenshots/{created['id']}",
        {
            "data": {
                "type": "appScreenshots",
                "id": created["id"],
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": hashlib.md5(blob).hexdigest(),
                },
            }
        },
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--locale", default="en-US")
    args = ap.parse_args()

    shots = sorted((L.ROOT / "fastlane/screenshots" / args.locale).glob("*.png"))
    if not shots:
        raise SystemExit(f"error: no screenshots for {args.locale}")

    by_type: dict[str, list[Path]] = {}
    for png in shots:
        size = png_size(png)
        display_type = DISPLAY_TYPE_BY_SIZE.get(size)
        if display_type is None:
            raise SystemExit(
                f"error: {png.name} is {size[0]}x{size[1]}, which is not an App Store "
                f"size. Expected one of: "
                + ", ".join(f"{w}x{h}" for w, h in DISPLAY_TYPE_BY_SIZE)
            )
        by_type.setdefault(display_type, []).append(png)

    c = L.ASCClient(L.bearer_token(*L.load_credentials()))
    app_id = L.find_app(c, BUNDLE)["id"]
    version = L.ensure_draft_version(c, app_id, None)
    locs = {
        x["attributes"]["locale"]: x
        for x in L.list_all(c, f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    }
    loc = locs[args.locale]

    sets = {
        s["attributes"]["screenshotDisplayType"]: s
        for s in L.list_all(c, f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")
    }

    for display_type, pngs in sorted(by_type.items()):
        if display_type in sets:
            set_id = sets[display_type]["id"]
            for old in L.list_all(c, f"/appScreenshotSets/{set_id}/appScreenshots"):
                c.request("DELETE", f"/appScreenshots/{old['id']}")
        else:
            set_id = c.post(
                "/appScreenshotSets",
                {
                    "data": {
                        "type": "appScreenshotSets",
                        "attributes": {"screenshotDisplayType": display_type},
                        "relationships": {
                            "appStoreVersionLocalization": {
                                "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}
                            }
                        },
                    }
                },
            )["data"]["id"]

        for png in pngs:
            upload(c, set_id, png)
            print(f"uploaded {png.name} -> {display_type}")
        print(f"  {len(pngs)} screenshot(s) on {args.locale} / {display_type}")

    print(f"\nversion {version['attributes']['versionString']}")


if __name__ == "__main__":
    main()

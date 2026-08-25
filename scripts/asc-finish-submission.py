#!/usr/bin/env python3
"""Finish ASC release prerequisites that the API can set before submit-for-review.

Fills gaps the earlier metadata/setup scripts left behind:
  - contentRightsDeclaration (DOES_NOT_USE_THIRD_PARTY_CONTENT)
  - free USA base app price schedule
  - version copyright
  - supportUrl on every version localization (fallback to en-US)
  - review contact email aligned with review_information/

App Privacy nutrition labels still have no public ASC API — see
docs/asc-submission-checklist.md for the answers to fill in the web UI.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from asc_lib import (
    ASCClient,
    bearer_token,
    bundle_id_from_appfile,
    find_app,
    find_editable_version,
    list_all,
    load_credentials,
    read_meta,
)

COPYRIGHT = "2026 Jack Wallner"
SUPPORT_URL = "https://jackwallner.github.io/pickleball/support"
CONTENT_RIGHTS = "DOES_NOT_USE_THIRD_PARTY_CONTENT"


def ensure_free_pricing(c: ASCClient, app_id: str) -> None:
    has_manual = False
    try:
        sched = c.get(f"/apps/{app_id}/appPriceSchedule")
        sched_id = (sched.get("data") or {}).get("id")
        if sched_id:
            mp = c.get(f"/appPriceSchedules/{sched_id}/manualPrices")
            has_manual = bool(mp.get("data"))
    except RuntimeError as e:
        if "404" not in str(e):
            raise
    if has_manual:
        print("app price schedule already has manual prices")
        return

    points = list_all(c, f"/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")
    free = min(
        (p for p in points if float(p["attributes"]["customerPrice"]) == 0.0),
        key=lambda p: p["id"],
        default=None,
    )
    if not free:
        raise SystemExit("error: no free USA app price point")
    c.post(
        "/appPriceSchedules",
        {
            "data": {
                "type": "appPriceSchedules",
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "appPrices", "id": "${price0}"}]},
                },
            },
            "included": [
                {
                    "type": "appPrices",
                    "id": "${price0}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "appPricePoint": {
                            "data": {"type": "appPricePoints", "id": free["id"]}
                        },
                    },
                }
            ],
        },
    )
    print("app price set to free (USA base)")


def ensure_support_urls(c: ASCClient, vid: str) -> None:
    support = read_meta("en-US", "support_url") or SUPPORT_URL
    locs = list_all(c, f"/appStoreVersions/{vid}/appStoreVersionLocalizations")
    fixed = 0
    for loc in locs:
        if loc["attributes"].get("supportUrl"):
            continue
        lid = loc["id"]
        c.patch(
            f"/appStoreVersionLocalizations/{lid}",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": lid,
                    "attributes": {"supportUrl": support},
                }
            },
        )
        fixed += 1
    print(f"supportUrl patched on {fixed}/{len(locs)} localizations (url={support})")


def main() -> int:
    key_id, issuer_id, key_path = load_credentials()
    c = ASCClient(bearer_token(key_id, issuer_id, key_path))
    app = find_app(c, bundle_id_from_appfile())
    app_id = app["id"]
    print(f"app {app_id}")

    c.patch(
        f"/apps/{app_id}",
        {
            "data": {
                "type": "apps",
                "id": app_id,
                "attributes": {"contentRightsDeclaration": CONTENT_RIGHTS},
            }
        },
    )
    print(f"content rights: {CONTENT_RIGHTS}")

    ensure_free_pricing(c, app_id)

    version = find_editable_version(c, app_id)
    if not version:
        print("No editable version.")
        return 1
    vid = version["id"]

    copyright_text = (read_meta("en-US", "copyright") or COPYRIGHT).strip() or COPYRIGHT
    c.patch(
        f"/appStoreVersions/{vid}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": vid,
                "attributes": {"copyright": copyright_text},
            }
        },
    )
    print(f"copyright set ({copyright_text})")

    ensure_support_urls(c, vid)

    # Keep review contact email on the +m alias used for feedback.
    email = read_meta("review_information", "email_address") or "jackwallner+m@gmail.com"
    # review_information lives under metadata/review_information/, not a locale.
    ri = Path(__file__).resolve().parent.parent / "fastlane/metadata/review_information"
    if (ri / "email_address.txt").exists():
        email = (ri / "email_address.txt").read_text().strip() or email
    rd = c.get(f"/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if rd and rd["attributes"].get("contactEmail") != email:
        c.patch(
            f"/appStoreReviewDetails/{rd['id']}",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": rd["id"],
                    "attributes": {"contactEmail": email},
                }
            },
        )
        print(f"review contact email -> {email}")
    else:
        print("review detail contact email ok")

    print("done — next: fill App Privacy in ASC web UI if not already, then:")
    print("  python3 scripts/asc-submit-for-review.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

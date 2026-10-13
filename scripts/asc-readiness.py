#!/usr/bin/env python3
"""Read-only App Store Connect readiness report for the current draft version.

Prints what is ready and what still blocks a submit-for-review, without
changing anything. Run with ASC creds sourced (see ~/.baseball_credentials).
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from asc_lib import (
    ASCClient, bearer_token, bundle_id_from_appfile, find_app,
    find_editable_version, list_all, load_credentials,
)


def main() -> int:
    key_id, issuer_id, key_path = load_credentials()
    client = ASCClient(bearer_token(key_id, issuer_id, key_path))
    app = find_app(client, bundle_id_from_appfile())
    app_id = app["id"]
    print(f"App: {app['attributes'].get('name')}  ({app_id})")

    version = find_editable_version(client, app_id)
    if not version:
        # A dry-run review submission moves the draft to READY_FOR_REVIEW,
        # which is no longer returned by find_editable_version. Keep this
        # read-only report useful while the submission remains unsubmitted.
        ready = [
            item
            for item in list_all(client, f"/apps/{app_id}/appStoreVersions")
            if item.get("attributes", {}).get("appStoreState") == "READY_FOR_REVIEW"
        ]
        if ready:
            version = sorted(
                ready,
                key=lambda item: item.get("attributes", {}).get("versionString", ""),
                reverse=True,
            )[0]
    if not version:
        print("NO editable version found.")
        return 1
    vid = version["id"]
    vattr = version["attributes"]
    print(f"Version: {vattr.get('versionString')}  state={vattr.get('appStoreState')}")

    # Build attached + processing state
    try:
        build = client.request("GET", f"/appStoreVersions/{vid}/build")
        bdata = build.get("data")
        print(f"Build attached (linkage id): {bdata['id'] if bdata else 'NONE'}")
    except Exception as e:
        print(f"Build attached: error {e}")
    # latest builds available (source of truth)
    try:
        builds = list_all(client, f"/builds?filter[app]={app_id}&limit=8&sort=-version")
        for bb in builds[:8]:
            a = bb["attributes"]
            print(f"   build {a.get('version')}: processing={a.get('processingState')} expired={a.get('expired')} id={bb['id']}")
    except Exception as e:
        print(f"   build list error: {e}")

    # Screenshots per localization
    locs = list_all(client, f"/appStoreVersions/{vid}/appStoreVersionLocalizations")
    print(f"Version localizations: {len(locs)}")
    for loc in locs:
        if loc['attributes'].get('locale') != 'en-US':
            continue
        sets = list_all(client, f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")
        for s in sets:
            shots = list_all(client, f"/appScreenshotSets/{s['id']}/appScreenshots")
            print(f"   en-US {s['attributes'].get('screenshotDisplayType')}: {len(shots)} screenshots")

    # Age rating. The declaration hangs off appInfos, not appStoreVersions; the
    # relationship was removed from the version resource.
    try:
        infos = list_all(client, f"/apps/{app_id}/appInfos")
        ard = None
        for info in infos:
            got = client.request(
                "GET", f"/appInfos/{info['id']}/ageRatingDeclaration"
            ).get("data")
            if got:
                ard = got
                break
        print(f"Age rating declaration: {'present' if ard else 'MISSING'}")
    except Exception as e:
        print(f"Age rating declaration: error {e}")

    # IAP products
    iaps = list_all(client, f"/apps/{app_id}/inAppPurchasesV2?limit=200")
    print(f"In-app purchases: {len(iaps)}")
    for p in iaps:
        a = p["attributes"]
        print(f"   {a.get('productId')}: state={a.get('state')} type={a.get('inAppPurchaseType')}")
    subs = list_all(client, f"/apps/{app_id}/subscriptionGroups?limit=50")
    for g in subs:
        members = list_all(client, f"/subscriptionGroups/{g['id']}/subscriptions?limit=50")
        for m in members:
            a = m["attributes"]
            print(f"   sub {a.get('productId')}: state={a.get('state')}")

    # Pricing / availability
    try:
        sched = client.request("GET", f"/apps/{app_id}/appPriceSchedule")
        print(f"Price schedule: {'present' if sched.get('data') else 'MISSING'}")
    except Exception as e:
        print(f"Price schedule: {e}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

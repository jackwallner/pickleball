#!/usr/bin/env python3
"""Submit the current editable App Store version for review.

Uses the modern reviewSubmissions flow:
  1. reuse an OPEN reviewSubmission for the app, or create one (platform IOS)
  2. add a reviewSubmissionItem for the editable appStoreVersion (idempotent)
  3. PATCH submitted=true  (this is where ASC validates everything)

Paths are relative to asc_lib.API (already ends in /v1) — do NOT prefix /v1.

A validation failure leaves the submission OPEN and prints the exact blockers,
so this is safe to run to discover what remains. Pass --dry-run to stop before
the final submit and just report the prepared submission.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from asc_lib import (
    ASCClient, bearer_token, bundle_id_from_appfile, find_app,
    find_editable_version, list_all, load_credentials,
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    key_id, issuer_id, key_path = load_credentials()
    c = ASCClient(bearer_token(key_id, issuer_id, key_path))
    app = find_app(c, bundle_id_from_appfile())
    app_id = app["id"]
    version = find_editable_version(c, app_id)
    if not version:
        print("No editable version.")
        return 1
    vid = version["id"]
    print(f"App {app_id}  version {version['attributes'].get('versionString')} ({vid})")

    # 1. Reuse an editable (not-yet-submitted) reviewSubmission or create one.
    #    Prefer the app relationship path; top-level filter[app] 404s for some keys.
    all_subs = list_all(c, f"/apps/{app_id}/reviewSubmissions?limit=50")
    open_sub = next(
        (s for s in all_subs if s["attributes"].get("state") == "READY_FOR_REVIEW"),
        None,
    )
    if open_sub:
        sub_id = open_sub["id"]
        print(f"Reusing open reviewSubmission {sub_id} (state={open_sub['attributes'].get('state')})")
    else:
        created = c.request("POST", "/reviewSubmissions", {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        })
        sub_id = created["data"]["id"]
        print(f"Created reviewSubmission {sub_id}")

    # 2. Add the version as an item (skip if already present).
    #    ASC validates readiness on this POST as well as on the final submit.
    items = list_all(c, f"/reviewSubmissions/{sub_id}/items")
    have = any(
        (it.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id") == vid
        for it in items
    )
    if have:
        print("Version already an item on this submission.")
    else:
        try:
            c.request("POST", "/reviewSubmissionItems", {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}},
                    },
                }
            })
            print("Added appStoreVersion item.")
        except Exception as e:
            print("ADD ITEM FAILED (version not ready for review):")
            print(str(e)[:4000])
            return 2

    if args.dry_run:
        print("Dry run: prepared but NOT submitted.")
        return 0

    # 3. Submit — ASC validates here; failure leaves the submission open.
    try:
        res = c.request("PATCH", f"/reviewSubmissions/{sub_id}", {
            "data": {
                "type": "reviewSubmissions",
                "id": sub_id,
                "attributes": {"submitted": True},
            }
        })
        st = res["data"]["attributes"].get("state")
        print(f"SUBMITTED. reviewSubmission state = {st}")
        return 0
    except Exception as e:
        print("SUBMIT FAILED (submission left open, nothing sent):")
        print(str(e)[:4000])
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

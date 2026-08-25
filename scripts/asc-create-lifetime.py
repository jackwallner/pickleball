#!/usr/bin/env python3
"""Create the Pro Lifetime non-consumable in App Store Connect.

Creates com.jackwallner.pickleball.pro.lifetime, adds the en-US localization, sets a
$29.99 USA-based price schedule (other territories auto-equalize from the base
territory), and makes it available in all territories. Idempotent-ish: skips
steps whose object already exists. Review screenshot + submission happen with
the next app version.

Usage: source ~/.baseball_credentials && python3 scripts/asc-create-lifetime.py
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.pickleball"
PRODUCT_ID = "com.jackwallner.pickleball.pro.lifetime"
PRICE = "99.99"
NAME = "Pro Lifetime"
DISPLAY_NAME = "DUPR IQ Pro Lifetime"
DESCRIPTION = "Unlimited graded balls and every drill phase, forever"

BASE = "https://api.appstoreconnect.apple.com"


class Client:
    def __init__(self, token: str):
        self.token = token

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        req = urllib.request.Request(BASE + path, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        req.add_header("Content-Type", "application/json")
        data = json.dumps(body).encode() if body is not None else None
        try:
            with urllib.request.urlopen(req, data=data) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{method} {path} -> {e.code}: {e.read().decode()[:500]}")

    def get(self, path: str) -> dict:
        return self.request("GET", path)

    def post(self, path: str, body: dict) -> dict:
        return self.request("POST", path, body)


def main() -> None:
    c = Client(asc_lib.bearer_token(*asc_lib.load_credentials()))
    v1 = asc_lib.ASCClient(c.token)
    app = asc_lib.find_app(v1, BUNDLE)
    app_id = app["id"]

    # 1. The IAP itself.
    existing = c.get(f"/v1/apps/{app_id}/inAppPurchasesV2?filter[productId]={PRODUCT_ID}")["data"]
    if existing:
        iap_id = existing[0]["id"]
        print(f"IAP exists: {iap_id}")
    else:
        iap = c.post("/v2/inAppPurchases", {
            "data": {
                "type": "inAppPurchases",
                "attributes": {
                    "name": NAME,
                    "productId": PRODUCT_ID,
                    "inAppPurchaseType": "NON_CONSUMABLE",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        })
        iap_id = iap["data"]["id"]
        print(f"created IAP {iap_id}")

    # 2. en-US localization.
    locs = c.get(f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")["data"]
    if not any(l["attributes"]["locale"] == "en-US" for l in locs):
        c.post("/v1/inAppPurchaseLocalizations", {
            "data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {
                    "locale": "en-US",
                    "name": DISPLAY_NAME,
                    "description": DESCRIPTION,
                },
                "relationships": {
                    "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}
                },
            }
        })
        print("created en-US localization")
    else:
        print("localization exists")

    # 3. Price schedule based on USA (other territories equalize).
    points = []
    path = f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
    while path:
        d = c.get(path)
        points += d["data"]
        nxt = d.get("links", {}).get("next")
        path = nxt.replace(BASE, "") if nxt else None
    point = next(p for p in points if p["attributes"]["customerPrice"] == PRICE)
    c.post("/v1/inAppPurchasePriceSchedules", {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price1}"}]},
            },
        },
        "included": [{
            "id": "${price1}",
            "type": "inAppPurchasePrices",
            "attributes": {"startDate": None, "endDate": None},
            "relationships": {
                "inAppPurchasePricePoint": {
                    "data": {"type": "inAppPurchasePricePoints", "id": point["id"]}
                },
            },
        }],
    })
    print(f"price schedule set: USA {PRICE}")

    # 4. Available everywhere, including future territories.
    terrs = asc_lib.list_all(v1, "/territories?limit=200")
    c.post("/v1/inAppPurchaseAvailabilities", {
        "data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "availableTerritories": {
                    "data": [{"type": "territories", "id": t["id"]} for t in terrs]
                },
            },
        }
    })
    print(f"availability set: {len(terrs)} territories")
    print("done — needs review screenshot + submission with next app version")


if __name__ == "__main__":
    main()

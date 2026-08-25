#!/usr/bin/env python3
"""Wire the lifetime product into RevenueCat.

Creates the com.jackwallner.pickleball.pro.lifetime product on the App Store app record,
attaches it to the `pro` entitlement, adds a $rc_lifetime package to the
current offering, and attaches the product to it. Idempotent: skips anything
that already exists.

Usage: python3 scripts/rc-add-lifetime.py   (key read from ~/.pickleball_credentials)
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

PRODUCT_ID = "com.jackwallner.pickleball.pro.lifetime"
BASE = "https://api.revenuecat.com/v2"


def secret_key() -> str:
    for line in (Path.home() / ".pickleball_credentials").read_text().splitlines():
        if line.startswith("RC_SECRET_KEY"):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("RC_SECRET_KEY not found in ~/.pickleball_credentials")


def request(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Authorization", f"Bearer {KEY}")
    req.add_header("Content-Type", "application/json")
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data=data) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {path} -> {e.code}: {e.read().decode()[:400]}")


KEY = secret_key()


def main() -> None:
    projects = request("GET", "/projects")["items"]
    project = projects[0] if len(projects) == 1 else next(
        p for p in projects if "dupr" in p["name"].lower()
    )
    pid = project["id"]
    print(f"project: {project['name']} ({pid})")

    apps = request("GET", f"/projects/{pid}/apps")["items"]
    app = next(a for a in apps if a["type"] == "app_store")

    products = request("GET", f"/projects/{pid}/products?limit=50")["items"]
    product = next((p for p in products if p["store_identifier"] == PRODUCT_ID), None)
    if product is None:
        product = request("POST", f"/projects/{pid}/products", {
            "store_identifier": PRODUCT_ID,
            "app_id": app["id"],
            "type": "one_time",
            "display_name": "Pro Lifetime",
        })
        print(f"created product {product['id']}")
    else:
        print(f"product exists: {product['id']}")

    entitlements = request("GET", f"/projects/{pid}/entitlements")["items"]
    pro = next(e for e in entitlements if e["lookup_key"] == "pro")
    attached = request(
        "GET", f"/projects/{pid}/entitlements/{pro['id']}/products?limit=50"
    )["items"]
    if not any(p["id"] == product["id"] for p in attached):
        request("POST", f"/projects/{pid}/entitlements/{pro['id']}/actions/attach_products",
                {"product_ids": [product["id"]]})
        print("attached to entitlement pro")
    else:
        print("already attached to entitlement pro")

    offerings = request("GET", f"/projects/{pid}/offerings")["items"]
    offering = next((o for o in offerings if o.get("is_current")), offerings[0])
    packages = request(
        "GET", f"/projects/{pid}/offerings/{offering['id']}/packages?limit=50"
    )["items"]
    package = next((p for p in packages if p["lookup_key"] == "$rc_lifetime"), None)
    if package is None:
        package = request("POST", f"/projects/{pid}/offerings/{offering['id']}/packages", {
            "lookup_key": "$rc_lifetime",
            "display_name": "Lifetime",
        })
        print(f"created package {package['id']}")
    else:
        print(f"package exists: {package['id']}")

    pkg_products = request(
        "GET", f"/projects/{pid}/packages/{package['id']}/products?limit=50"
    )["items"]
    if not any(p["id"] == product["id"] for p in pkg_products):
        request("POST", f"/projects/{pid}/packages/{package['id']}/actions/attach_products",
                {"products": [{"product_id": product["id"], "eligibility_criteria": "all"}]})
        print("attached product to package")
    else:
        print("product already in package")

    print("done")


if __name__ == "__main__":
    main()

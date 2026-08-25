#!/usr/bin/env python3
"""One-time App Store Connect setup for DUPR IQ: subscription group,
monthly/yearly subs with prices + 1-week free trials (all territories),
localizations, categories, and the age-rating questionnaire.

Idempotent: safe to re-run; existing pieces are skipped.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.pickleball"
GROUP_NAME = "Pro"
SUBS = [
    {
        "productId": "com.jackwallner.pickleball.pro.monthly",
        "name": "DUPR IQ Pro Monthly",
        "period": "ONE_MONTH",
        "price": "9.99",
        "desc": "Unlimited graded balls and every drill phase, billed monthly.",
        "trial": True,
    },
    {
        "productId": "com.jackwallner.pickleball.pro.yearly",
        "name": "DUPR IQ Pro Yearly",
        "period": "ONE_YEAR",
        "price": "59.99",
        "desc": "Unlimited graded balls and every drill phase, billed yearly.",
        "trial": True,
    },
]
REVIEW_NOTE = "Unlocks unlimited graded balls and every drill phase. The free tier grades 15 balls per calendar day."


def main() -> None:
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    app_id = app["id"]
    print(f"app {app_id}")

    # --- categories + age rating on the editable appInfo ---
    infos = c.get(f"/apps/{app_id}/appInfos")["data"]
    for info in infos:
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        if state not in asc_lib.EDITABLE_STATES:
            continue
        c.patch(
            f"/appInfos/{info['id']}",
            {
                "data": {
                    "type": "appInfos",
                    "id": info["id"],
                    "relationships": {
                        "primaryCategory": {"data": {"type": "appCategories", "id": "EDUCATION"}},
                        "secondaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
                        "secondarySubcategoryOne": {"data": {"type": "appCategories", "id": "GAMES_BOARD"}},
                    },
                }
            },
        )
        print("categories set (EDUCATION / GAMES > BOARD)")
        decl = c.get(f"/appInfos/{info['id']}/ageRatingDeclaration")["data"]
        age_attrs = {
            "advertising": False,
            "alcoholTobaccoOrDrugUseOrReferences": "NONE",
            "contests": "NONE",
            "gambling": False,
            "gamblingSimulated": "NONE",
            "gunsOrOtherWeapons": "NONE",
            "healthOrWellnessTopics": False,
            "lootBox": False,
            "medicalOrTreatmentInformation": "NONE",
            "messagingAndChat": False,
            "parentalControls": False,
            "profanityOrCrudeHumor": "NONE",
            "ageAssurance": False,
            "sexualContentGraphicAndNudity": "NONE",
            "sexualContentOrNudity": "NONE",
            "horrorOrFearThemes": "NONE",
            "matureOrSuggestiveThemes": "NONE",
            "unrestrictedWebAccess": False,
            "userGeneratedContent": False,
            "violenceCartoonOrFantasy": "NONE",
            "violenceRealisticProlongedGraphicOrSadistic": "NONE",
            "violenceRealistic": "NONE",
        }
        c.patch(
            f"/ageRatingDeclarations/{decl['id']}",
            {
                "data": {
                    "type": "ageRatingDeclarations",
                    "id": decl["id"],
                    "attributes": age_attrs,
                }
            },
        )
        print("age rating set (everything NONE/false)")

    territories = [t["id"] for t in asc_lib.list_all(c, "/territories?limit=200")]
    print(f"{len(territories)} territories")

    # --- subscription group ---
    groups = c.get(f"/apps/{app_id}/subscriptionGroups")["data"]
    group = next((g for g in groups if g["attributes"]["referenceName"] == GROUP_NAME), None)
    if not group:
        group = c.post(
            "/subscriptionGroups",
            {
                "data": {
                    "type": "subscriptionGroups",
                    "attributes": {"referenceName": GROUP_NAME},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )["data"]
        print("group created")
    group_id = group["id"]

    glocs = c.get(f"/subscriptionGroups/{group_id}/subscriptionGroupLocalizations")["data"]
    if not any(l["attributes"]["locale"] == "en-US" for l in glocs):
        c.post(
            "/subscriptionGroupLocalizations",
            {
                "data": {
                    "type": "subscriptionGroupLocalizations",
                    "attributes": {"locale": "en-US", "name": GROUP_NAME, "customAppName": "DUPR IQ"},
                    "relationships": {
                        "subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group_id}}
                    },
                }
            },
        )
        print("group localization added")

    existing_subs = {
        s["attributes"]["productId"]: s
        for s in c.get(f"/subscriptionGroups/{group_id}/subscriptions")["data"]
    }

    for spec in SUBS:
        sub = existing_subs.get(spec["productId"])
        if not sub:
            sub = c.post(
                "/subscriptions",
                {
                    "data": {
                        "type": "subscriptions",
                        "attributes": {
                            "name": spec["name"],
                            "productId": spec["productId"],
                            "subscriptionPeriod": spec["period"],
                            "familySharable": False,
                            "groupLevel": 1,
                            "reviewNote": REVIEW_NOTE,
                        },
                        "relationships": {
                            "group": {"data": {"type": "subscriptionGroups", "id": group_id}}
                        },
                    }
                },
            )["data"]
            print(f"subscription created: {spec['productId']}")
        sub_id = sub["id"]

        locs = c.get(f"/subscriptions/{sub_id}/subscriptionLocalizations")["data"]
        if not any(l["attributes"]["locale"] == "en-US" for l in locs):
            c.post(
                "/subscriptionLocalizations",
                {
                    "data": {
                        "type": "subscriptionLocalizations",
                        "attributes": {"locale": "en-US", "name": spec["name"], "description": spec["desc"]},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
                    }
                },
            )
            print("  localization added")

        try:
            c.get(f"/subscriptions/{sub_id}/subscriptionAvailability")
            print("  availability exists")
        except RuntimeError:
            c.post(
                "/subscriptionAvailabilities",
                {
                    "data": {
                        "type": "subscriptionAvailabilities",
                        "attributes": {"availableInNewTerritories": True},
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                            "availableTerritories": {
                                "data": [{"type": "territories", "id": t} for t in territories]
                            },
                        },
                    }
                },
            )
            print("  availability set (all territories)")

        prices = c.get(f"/subscriptions/{sub_id}/prices?limit=1")["data"]
        if not prices:
            points = asc_lib.list_all(
                c, f"/subscriptions/{sub_id}/pricePoints?filter[territory]=USA&limit=200"
            )
            point = next(
                (p for p in points if p["attributes"]["customerPrice"] == spec["price"]), None
            )
            if not point:
                raise SystemExit(f"no USA price point {spec['price']} for {spec['productId']}")
            c.post(
                "/subscriptionPrices",
                {
                    "data": {
                        "type": "subscriptionPrices",
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                            "subscriptionPricePoint": {
                                "data": {"type": "subscriptionPricePoints", "id": point["id"]}
                            },
                        },
                    }
                },
            )
            print(f"  price set ${spec['price']} (USA base, auto-equalized)")

        if spec["trial"]:
            existing_offers = asc_lib.list_all(
                c, f"/subscriptions/{sub_id}/introductoryOffers?include=territory&limit=200"
            )
            covered = set()
            for o in existing_offers:
                terr = (o.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                if terr:
                    covered.add(terr)
            missing = [t for t in territories if t not in covered]
            for t in missing:
                c.post(
                    "/subscriptionIntroductoryOffers",
                    {
                        "data": {
                            "type": "subscriptionIntroductoryOffers",
                            "attributes": {
                                "duration": "ONE_WEEK",
                                "offerMode": "FREE_TRIAL",
                                "numberOfPeriods": 1,
                            },
                            "relationships": {
                                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                                "territory": {"data": {"type": "territories", "id": t}},
                            },
                        }
                    },
                )
            if missing:
                print(f"  1-week free trial added in {len(missing)} territories")

    print("done")


if __name__ == "__main__":
    main()

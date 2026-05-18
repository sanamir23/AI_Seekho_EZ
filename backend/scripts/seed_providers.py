"""Seed the providers table from Google Places Text Search.

Run:
    python -m scripts.seed_providers
Idempotent — upserts on place_id.
"""
from __future__ import annotations

import random
import re
import sys
import time
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import get_settings  # noqa: E402
from app.db.supabase import get_service_client  # noqa: E402

CATEGORY_QUERIES = {
    "ac_technician": "AC technician",
    "plumber": "plumber",
    "electrician": "electrician",
    "tutor": "tutor academy",
    "beautician": "beauty salon",
}

SECTOR_RE = re.compile(r"\b([A-I]-\d{1,2}(?:/\d)?)\b")
PLACES_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"


def extract_area(address: str | None) -> str | None:
    if not address:
        return None
    m = SECTOR_RE.search(address)
    return m.group(1) if m else None


def mock_hours() -> dict:
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    return {d: ["09:00-13:00", "14:00-19:00"] for d in days if d != "sun"}


def mock_phone() -> str:
    return f"+9230{random.randint(0, 9)}{random.randint(1000000, 9999999)}"


def fetch_places(api_key: str, query: str, city: str) -> list[dict]:
    """Up to 60 results via 3 pages."""
    results: list[dict] = []
    params = {"query": f"{query} in {city}", "key": api_key}
    with httpx.Client(timeout=20) as http:
        for _ in range(3):
            r = http.get(PLACES_URL, params=params)
            r.raise_for_status()
            data = r.json()
            results.extend(data.get("results", []))
            token = data.get("next_page_token")
            if not token:
                break
            # Google requires a short delay before next_page_token is valid.
            time.sleep(2.2)
            params = {"pagetoken": token, "key": api_key}
    return results


def to_row(place: dict, category: str) -> dict | None:
    place_id = place.get("place_id")
    name = place.get("name")
    geom = place.get("geometry", {}).get("location") or {}
    lat, lng = geom.get("lat"), geom.get("lng")
    if not (place_id and name and lat and lng):
        return None
    address = place.get("formatted_address") or place.get("vicinity")
    return {
        "place_id": place_id,
        "name": name,
        "category": category,
        "address": address,
        "lat": lat,
        "lng": lng,
        "rating": place.get("rating"),
        "user_ratings_total": place.get("user_ratings_total"),
        "phone": mock_phone(),
        "area": extract_area(address),
        "available_hours": mock_hours(),
    }


def main() -> None:
    s = get_settings()
    svc = get_service_client()
    total = 0
    for category, q in CATEGORY_QUERIES.items():
        print(f"[seed] fetching '{q}' in {s.seed_city} ...")
        places = fetch_places(s.google_places_api_key, q, s.seed_city)
        rows = [r for p in places if (r := to_row(p, category))]
        if not rows:
            print(f"  no results for {category}")
            continue
        svc.table("providers").upsert(rows, on_conflict="place_id").execute()
        total += len(rows)
        print(f"  upserted {len(rows)} providers for {category}")
    print(f"[seed] done. total upserted: {total}")


if __name__ == "__main__":
    main()

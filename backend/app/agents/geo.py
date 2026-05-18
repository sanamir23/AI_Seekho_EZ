"""Pure geo helpers — no I/O, no LLM, no DB.

Used by the ranking node and (indirectly) by the agent tools for distance
scoring. Centroids are approximate, hand-tuned values for Islamabad sectors —
they're "good enough" for ranking without needing to geocode user input at
request time.
"""
from math import asin, cos, radians, sin, sqrt

# Approximate centroids for Islamabad sectors.
# Source: rough hand-pick from the city plan. Precision: ~500m, which is fine
# for a 5-km distance score that decays linearly.
SECTOR_CENTROIDS: dict[str, tuple[float, float]] = {
    "F-6":  (33.7197, 73.0779),
    "F-7":  (33.7195, 73.0590),
    "F-8":  (33.7064, 73.0480),
    "F-10": (33.6938, 73.0140),
    "F-11": (33.6845, 72.9988),
    "G-6":  (33.7166, 73.0809),
    "G-7":  (33.7100, 73.0700),
    "G-8":  (33.7000, 73.0500),
    "G-9":  (33.6900, 73.0300),
    "G-10": (33.6820, 73.0150),
    "G-11": (33.6740, 73.0010),
    "G-13": (33.6500, 72.9800),
    "I-8":  (33.6700, 73.0700),
    "I-9":  (33.6580, 73.0750),
    "I-10": (33.6470, 73.0540),
    # Fallback if we can't resolve a specific sector.
    "Islamabad": (33.6844, 73.0479),
}


def sector_centroid(area: str | None) -> tuple[float, float]:
    """Lookup centroid by sector code, case-insensitive. Defaults to city center."""
    if not area:
        return SECTOR_CENTROIDS["Islamabad"]
    key = area.strip().upper()
    return SECTOR_CENTROIDS.get(key, SECTOR_CENTROIDS["Islamabad"])


def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in kilometres between two lat/lng points."""
    r = 6371.0  # Earth radius (km).
    p1, p2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlam = radians(lng2 - lng1)
    a = sin(dphi / 2) ** 2 + cos(p1) * cos(p2) * sin(dlam / 2) ** 2
    return 2 * r * asin(sqrt(a))

#!/usr/bin/env python3
"""Validate a MiFi submission (from ISSUE_BODY) and merge it into data/tiles/<geohash>.json.

Writes a human-readable outcome to result.txt (posted back on the issue).
Uses only the standard library. The issue body is untrusted input.
"""
import json
import math
import os
import re
import sys
from datetime import datetime, timezone

BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"
PRECISION = 5  # must match Geohash.tilePrecision in the app
SECURITY = {"WPA2", "WPA3", "WEP", "Open"}
MERGE_RADIUS_M = 150
REPORTS_TO_REMOVE = 3
MAX_PER_TILE = 2000
TILE_DIR = "data/tiles"


def geohash(lat, lon, precision=PRECISION):
    lat_r, lon_r = [-90.0, 90.0], [-180.0, 180.0]
    out, bits, bit, even = "", 0, 0, True
    while len(out) < precision:
        rng, val = (lon_r, lon) if even else (lat_r, lat)
        mid = (rng[0] + rng[1]) / 2
        if val >= mid:
            bit = bit * 2 + 1
            rng[0] = mid
        else:
            bit = bit * 2
            rng[1] = mid
        even = not even
        bits += 1
        if bits == 5:
            out += BASE32[bit]
            bits, bit = 0, 0
    return out


def distance_m(lat1, lon1, lat2, lon2):
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def clean_text(value, max_len, name, required=False):
    if not isinstance(value, str):
        raise ValueError(f"`{name}` must be text")
    value = value.strip()
    if required and not value:
        raise ValueError(f"`{name}` is required")
    if len(value) > max_len:
        raise ValueError(f"`{name}` is too long")
    if any(ord(c) < 32 or ord(c) == 127 for c in value):
        raise ValueError(f"`{name}` contains control characters")
    return value


def coord(data, key, limit):
    v = data.get(key)
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or abs(v) > limit:
        raise ValueError(f"`{key}` is not a valid coordinate")
    return float(v)


def load_tile(tile):
    path = os.path.join(TILE_DIR, f"{tile}.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return path, json.load(f)
    return path, {"networks": []}


def save_tile(path, data):
    data["networks"].sort(key=lambda n: n["id"])
    os.makedirs(TILE_DIR, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")


def handle_add(data, user):
    ssid = clean_text(data.get("ssid"), 32, "ssid", required=True)
    if len(ssid.encode("utf-8")) > 32:
        raise ValueError("`ssid` is longer than 32 bytes")
    security = data.get("security")
    if security not in SECURITY:
        raise ValueError("`security` must be one of " + ", ".join(sorted(SECURITY)))
    if security == "Open":
        password = ""
    else:
        password = clean_text(data.get("password"), 63, "password", required=True)
    venue = clean_text(data.get("venue", ""), 80, "venue")
    lat, lon = round(coord(data, "lat", 90), 6), round(coord(data, "lon", 180), 6)

    tile = geohash(lat, lon)
    path, tile_data = load_tile(tile)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    for n in tile_data["networks"]:
        if n["ssid"] == ssid and distance_m(lat, lon, n["lat"], n["lon"]) <= MERGE_RADIUS_M:
            n.update(password=password, security=security, reports=0, reporters=[], updated=now)
            if venue:
                n["venue"] = venue
            save_tile(path, tile_data)
            return f"Updated **{ssid}** in tile `{tile}`. Thanks @{user}!"

    if len(tile_data["networks"]) >= MAX_PER_TILE:
        raise ValueError("this area is full")
    import hashlib
    nid = hashlib.sha1(f"{ssid}|{lat:.4f}|{lon:.4f}".encode("utf-8")).hexdigest()[:12]
    tile_data["networks"].append({
        "id": nid, "ssid": ssid, "password": password, "security": security,
        "venue": venue, "lat": lat, "lon": lon, "by": user, "added": now,
        "reports": 0, "reporters": [],
    })
    save_tile(path, tile_data)
    return f"Added **{ssid}** to tile `{tile}`. It will show up in the app within a few minutes. Thanks @{user}!"


def handle_report(data, user):
    nid = clean_text(data.get("id"), 32, "id", required=True)
    lat, lon = coord(data, "lat", 90), coord(data, "lon", 180)
    tile = geohash(lat, lon)
    path, tile_data = load_tile(tile)
    for n in list(tile_data["networks"]):
        if n["id"] != nid:
            continue
        reporters = n.setdefault("reporters", [])
        if user not in reporters:
            reporters.append(user)
        n["reports"] = len(reporters)
        if n["reports"] >= REPORTS_TO_REMOVE:
            tile_data["networks"].remove(n)
            save_tile(path, tile_data)
            return f"Network `{nid}` received {n['reports']} reports and was removed."
        save_tile(path, tile_data)
        return f"Report recorded for `{nid}` ({n['reports']}/{REPORTS_TO_REMOVE})."
    raise ValueError("network not found in that tile")


def main():
    body = os.environ.get("ISSUE_BODY", "") or ""
    user = re.sub(r"[^A-Za-z0-9-]", "", os.environ.get("ISSUE_USER", "anonymous")) or "anonymous"
    try:
        m = re.search(r"```json\s*(\{.*?\})\s*```", body, re.DOTALL)
        if not m:
            raise ValueError("no JSON payload found in the issue body")
        data = json.loads(m.group(1))
        action = data.get("action")
        if action == "add":
            msg = handle_add(data, user)
        elif action == "report":
            msg = handle_report(data, user)
        else:
            raise ValueError("unknown `action`")
    except (ValueError, json.JSONDecodeError) as e:
        msg = f"Submission rejected: {e}"
    with open("result.txt", "w", encoding="utf-8") as f:
        f.write(msg + "\n\n---\n_Processed automatically by MiFi._")
    print(msg)


if __name__ == "__main__":
    sys.exit(main())

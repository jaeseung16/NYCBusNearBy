#!/usr/bin/env python3
"""Regenerate the app's bundled static bus data from the MTA bus GTFS zips.

Writes into OUT_DIR (default: NYCBusNearby/Resources):
  stops.txt            stop_id,stop_name,stop_desc,stop_lat,stop_lon (column order is
                       what MTABusStop decodes; deduplicated by stop_id)
  routes.txt           routes from all feeds, deduplicated by route_id
  route_headsigns.txt  route_id,direction_id,trip_headsign: the most common
                       trip_headsign per route and direction (see MTABusRouteHeadsign)
  gtfs_version.txt     one line identifying this data. The app re-imports stops into
                       Core Data whenever it differs from the version it last imported.

Usage:
  scripts/update_gtfs.py --download DIR [--out OUT_DIR]   # fetch the six zips into DIR first
  scripts/update_gtfs.py [--out OUT_DIR] gtfs_b.zip gtfs_bx.zip ...

The zips are at https://rrgtfsfeeds.s3.amazonaws.com/gtfs_{b,bx,m,q,si,busco}.zip.
MTA refreshes them quarterly, about a week before each schedule takes effect.
"""
import argparse
import csv
import hashlib
import io
import os
import sys
import urllib.request
import zipfile
from collections import Counter, defaultdict

FEEDS = ["b", "bx", "m", "q", "si", "busco"]
URL = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_{}.zip"
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "NYCBusNearby", "Resources")
ROUTE_FIELDS = ["route_id", "agency_id", "route_short_name", "route_long_name", "route_desc",
                "route_type", "route_color", "route_text_color"]


def rows(zf, name):
    with zf.open(name) as f:
        for row in csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig")):
            yield {k.strip(): (v or "").strip() for k, v in row.items() if k}


def write_csv(path, header, data):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("zips", nargs="*")
    parser.add_argument("--download", metavar="DIR")
    parser.add_argument("--out", default=DEFAULT_OUT)
    args = parser.parse_args()

    zip_paths = list(args.zips)
    if args.download:
        os.makedirs(args.download, exist_ok=True)
        for feed in FEEDS:
            path = os.path.join(args.download, f"gtfs_{feed}.zip")
            print(f"downloading {URL.format(feed)}")
            urllib.request.urlretrieve(URL.format(feed), path)
            zip_paths.append(path)
    if not zip_paths:
        parser.error("give GTFS zips or --download DIR")

    stops, routes = {}, {}
    stop_conflicts = 0
    headsign_counts = defaultdict(Counter)
    versions, starts, ends = set(), set(), set()

    for path in zip_paths:
        with zipfile.ZipFile(path) as zf:
            if "feed_info.txt" in zf.namelist():
                for info in rows(zf, "feed_info.txt"):
                    versions.add(info.get("feed_version", ""))
                    starts.add(info.get("feed_start_date", ""))
                    ends.add(info.get("feed_end_date", ""))

            for s in rows(zf, "stops.txt"):
                if s.get("location_type", "0") not in ("", "0"):
                    continue
                stop = (s["stop_id"], s["stop_name"], s.get("stop_desc", ""),
                        f'{float(s["stop_lat"]):.6f}', f'{float(s["stop_lon"]):.6f}')
                if stop[0] in stops:
                    # The same stop appears in several feeds; keep the first, prefer one with a desc.
                    old = stops[stop[0]]
                    if old[:2] != stop[:2] or old[3:] != stop[3:]:
                        stop_conflicts += 1
                    if not old[2] and stop[2]:
                        stops[stop[0]] = old[:2] + (stop[2],) + old[3:]
                    continue
                stops[stop[0]] = stop

            for r in rows(zf, "routes.txt"):
                routes.setdefault(r["route_id"], [r.get(k, "") for k in ROUTE_FIELDS])

            for t in rows(zf, "trips.txt"):
                if t.get("trip_headsign"):
                    headsign_counts[(t["route_id"], t["direction_id"])][t["trip_headsign"]] += 1

    os.makedirs(args.out, exist_ok=True)
    stops_path = os.path.join(args.out, "stops.txt")
    write_csv(stops_path, ["stop_id", "stop_name", "stop_desc", "stop_lat", "stop_lon"],
              [stops[k] for k in sorted(stops)])
    write_csv(os.path.join(args.out, "routes.txt"), ROUTE_FIELDS, [routes[k] for k in sorted(routes)])
    write_csv(os.path.join(args.out, "route_headsigns.txt"), ["route_id", "direction_id", "trip_headsign"],
              [[r, d, headsign_counts[(r, d)].most_common(1)[0][0]] for (r, d) in sorted(headsign_counts)])

    with open(stops_path, "rb") as f:
        digest = hashlib.sha256(f.read()).hexdigest()[:12]
    version = (f"{'+'.join(sorted(v for v in versions if v))} "
               f"{min(s for s in starts if s) if any(starts) else '?'}-{max(e for e in ends if e) if any(ends) else '?'} "
               f"stops:{digest}")
    with open(os.path.join(args.out, "gtfs_version.txt"), "w", encoding="utf-8") as f:
        f.write(version + "\n")

    total = sum(sum(c.values()) for c in headsign_counts.values())
    hits = sum(c.most_common(1)[0][1] for c in headsign_counts.values())
    print(f"stops: {len(stops)} ({stop_conflicts} cross-feed duplicates differing in name/location; first kept)")
    print(f"routes: {len(routes)}")
    print(f"route_headsigns: {len(headsign_counts)} keys, {hits}/{total} trips match exactly ({hits / total:.1%})")
    print(f"version: {version}")


if __name__ == "__main__":
    sys.exit(main())

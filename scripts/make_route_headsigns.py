#!/usr/bin/env python3
"""Build route_headsigns.txt from MTA bus GTFS zips.

For each (route_id, direction_id) it picks the most common trip_headsign in
trips.txt across all given feeds. The app uses this table to label live buses,
because GTFS-RT trip IDs change every schedule pick and rarely match bundled trips.

Usage:
  scripts/make_route_headsigns.py OUT.txt gtfs_b.zip gtfs_bx.zip gtfs_m.zip \
      gtfs_q.zip gtfs_si.zip gtfs_busco.zip

The zips are at https://rrgtfsfeeds.s3.amazonaws.com/gtfs_{b,bx,m,q,si,busco}.zip
"""
import csv
import io
import sys
import zipfile
from collections import Counter, defaultdict


def main(out_path, zip_paths):
    counts = defaultdict(Counter)
    for path in zip_paths:
        with zipfile.ZipFile(path) as zf, zf.open("trips.txt") as f:
            for row in csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig")):
                headsign = row.get("trip_headsign", "").strip()
                if headsign:
                    counts[(row["route_id"], row["direction_id"])][headsign] += 1

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["route_id", "direction_id", "trip_headsign"])
        for (route_id, direction_id) in sorted(counts):
            headsign = counts[(route_id, direction_id)].most_common(1)[0][0]
            writer.writerow([route_id, direction_id, headsign])

    total = sum(sum(c.values()) for c in counts.values())
    hits = sum(c.most_common(1)[0][1] for c in counts.values())
    print(f"{len(counts)} route/direction keys, {hits}/{total} trips match exactly ({hits / total:.1%})")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])

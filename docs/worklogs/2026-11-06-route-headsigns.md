# 2026-11-06 — Headsigns by route + direction (plan item 1)

## Task
Item 1 from `2026-11-03-mta-developer-data-review.md`: label buses by route and direction instead of by
trip ID, fall back to the last stop name, and remove trips.txt, `MTABusTripEntity`, and the trip-ID
lookup. This uses `MTATrip.directionId`, which MTAFeed-Swift 0.3.0 exposes (item 0).

## Changes
- `scripts/make_route_headsigns.py` (new): reads `trips.txt` from the given GTFS zips and writes
  `route_id,direction_id,trip_headsign`, using the most common headsign per key.
- `Resources/route_headsigns.txt` (new, 683 rows): generated from the six zips at
  `https://rrgtfsfeeds.s3.amazonaws.com/gtfs_{b,bx,m,q,si,busco}.zip` (feed_version 20261009, valid
  2026-10-12 to 2027-01-02). It matches 93.5% of scheduled trips exactly (215,571 of 230,532), the
  same as in the earlier analysis. The misses are LTD and short-turn variants.
- `Model/MTABusRouteHeadsign.swift` (new): CSV row type plus the `routeId|directionId` key.
- `ViewModel.swift`: `headsignByTripId` and `populateHeadsignByTripId()` / `getMTABusTrips()` are
  replaced by `headsignByRouteDirection`, `populateHeadsigns()` (reads the bundled CSV on every launch,
  no Core Data), and `headsign(for: MTATripUpdate)`. If the route or direction is unknown,
  `headsign(for:)` uses the name of the last stop in the trip update. `buses(within:from:)` calls it.
- Removed `Model/MTABusTrip.swift` and `Resources/trips.txt` (11 MB).
- Core Data: new model version `NYCBusNearby 2.xcdatamodel` (only `MTABusStopEntity`), set as current.
  The old `NYCBusTrips.xcdatamodel` is kept so existing stores and the bundled seed sqlite migrate
  automatically (`NSPersistentContainer` infers the mapping by default).
- `project.pbxproj`: added the new resource, source file, and model version; removed the two deleted files.
- `CLAUDE.md`: updated the data-sources section.

## Verification
- iOS Simulator Debug build succeeded. The bundle contains `route_headsigns.txt`, both `.mom` versions,
  and no `trips.txt`.
- Migration test (macOS command-line tool, compiled `.momd`, copy of the bundled
  `NYCBusNearby.sqlite`): the store loaded, the trip table was dropped, and all 15,018 stops were kept.
- Not run in the simulator against live data, so the headsigns have not been checked on screen.

## Notes for item 2
- The seed `NYCBusNearby.sqlite` (27 MB) still holds the old trip table until it is migrated on
  device. Item 2 deletes it.
- `make_route_headsigns.py` can be folded into `scripts/update_gtfs.py`.
- Not committed.

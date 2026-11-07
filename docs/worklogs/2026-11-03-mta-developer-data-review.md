# 2026-11-03 — MTA developer resources review (bus data)

## Task
Reviewed the bus docs under https://www.mta.info/developers and https://bustime.mta.info/developers/
to check (a) whether the bundled routes/stops/trips are current, and (b) which of SIRI or OneBusAway
Discovery the app uses and whether either has useful updates.

## Which API the app uses
Neither. `MTAFeed-Swift` `BusFeedURL` calls the Bus Time **GTFS-Realtime** feeds
(`https://gtfsrt.prod.obanyc.com/{tripUpdates,vehiclePositions,alerts}?key=...`). It uses the same Bus
Time developer key as SIRI and OBA. `MTAFeedConstant.restUrlString` (an EC2 http URL) is unused, and so
is the `amazonaws.com` ATS exception in Info.plist.

## Static data staleness (measured against the GTFS feeds published Oct 16, 2026; feed_version 20261009, valid 2026-10-12 to 2027-01-02)
- The bundled `stops.txt`, `trips.txt`, and `NYCBusNearby.sqlite` are from Jan 2023. `routes.txt` is from Dec 2022.
- **Trips:** 0 of 223,754 bundled trip_ids exist today. A live tripUpdates sample had 2,272 trip IDs:
  2,102 matched the current static trips and 0 matched the bundled ones.
  -> `headsignByTripId[tripId]` is always nil, so every bus shows a blank headsign.
- **Stops:** 11,539 stop IDs appeared in the live feed. All are in the current GTFS, but 819 (~7%) are
  missing from the bundled stops, so buses at those stops are dropped silently. Of the bundled stops,
  2,550 no longer exist, 114 moved more than about 50 m, and about 4,800 were renamed (mostly
  abbreviations expanded, e.g. "PK BL" -> "PKWY").
- **Routes:** 288 bundled, 399 current. The Queens Bus Network Redesign was completed Aug 31, 2025,
  with new routes such as Q06-Q121 and Q52+/Q53+/Q70+. The bundled data also seems to lack the MTA Bus
  Company feed entirely (BM/BxM/QM, B100/B103, Bx23), and 276 busco stops are missing.
- Live stop IDs carry no N/S suffix. The suffix-stripping in `buses(within:from:)` is a subway
  leftover and harmless.

## API updates worth considering
- **Cancelled trips (CAPI):** the GTFS-RT tripUpdates feed now flags cancellations with
  `trip.schedule_relationship = CANCELED`, and the alerts feed carries cancellation alerts with
  `effect = REDUCED_SERVICE`. The URLs are the same. The app currently ignores both.
- SIRI v2 (`/api/2/siri/...`, `detailLevel=minimum`) adds cancelled trips, distance-away text, and
  occupancy. It is useful only if the app switches to per-stop requests. The changelog has had no entries since 2016.
- The OBA Discovery API base is now `https://bustime-classic.mta.info/api/where/`. It is static only,
  but `stops-for-location` / `stops-for-route` could replace bundling stops.
- MTA refreshes bus GTFS quarterly and replaces the files about a week before they take effect.

## Status
Research only. No code changed. The downloaded feeds and comparison scripts are in the session scratchpad.

---

## Follow-up: implementation plans per recommendation

### Extra findings that shaped the plans
- `MTAFeedProcessor` drops TripDescriptor `direction_id` and `schedule_relationship`. Its alert parsing
  keeps only informed entities with a NYCT *subway* trip descriptor, so every bus alert ends up with no
  routes or trips. No alert effect is exposed, and the UI never shows `viewModel.alerts`.
- Live decode at 05:55 ET:
  - tripUpdates: 2,915 trips, all with `route_id` and `direction_id` (0/1). No CANCELED trips yet, so
    re-check at peak hours.
  - alerts: 91 entries, `effect` unset. Informed entities are agency+route (71) or agency+trip (134).
    The text contains HTML (`&#x200c;`, `<p>`).
  - vehiclePositions: 616/1529 vehicles carry `occupancy_status`, and 800 carry extension 1006
    (likely an MTA passenger-count extension).
- Headsigns: on the current GTFS, the most common headsign per (route_id, direction_id) matches 93.5% of
  trips exactly (683 keys, 502 with a single headsign). The misses are LTD and short-turn variants.
- The last stop in a live trip update equals the trip's static terminal for 245 of 362 Manhattan trips
  (68%). That is good enough as a fallback, not as the primary source.
- The API key has been in git history since commit bac9c15. The remote is github.com/jaeseung16/NYCBusNearBy.

### Plan summary (sequenced)
0. MTAFeed-Swift: expose `directionId`, `scheduleRelationship`, alert `effect` and `informedEntities`
   (route/trip/stop), and optionally occupancy. Tag a release.
1. Headsigns: route+direction table (generated), falling back to the last stop name. Remove trips.txt,
   MTABusTripEntity, and the trip-ID lookup.
2. Static data: `scripts/update_gtfs.py` merges all six zips into stops.txt, routes.txt, and
   route_headsigns.txt, plus a data_version. A version gate replaces `launchedBefore`. Import once in aPle
   background context with a single save. Delete the 27 MB seed sqlite.
3. Cancellations and alerts: mark or hide CANCELED trips, show route alerts on the stop and bus views,
   and strip HTML from alert text.
4. (Optional) Runtime refresh of the GTFS zips, or the Discovery API.
5. Cleanup: remove `restUrlString` and the ATS exception, rotate the key, move it to an untracked xcconfig.

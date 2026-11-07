# 2026-11-07 — Static data from current GTFS (plan item 2)

## Task
Committed item 1 (headsigns by route and direction) as "feat: Look up headsigns by route and direction",
together with the 11-03 and 11-06 worklogs. Then did item 2 from
`2026-11-03-mta-developer-data-review.md`:
- regenerate the bundled stops and routes from the current MTA bus GTFS
- replace the `launchedBefore` gate with a data-version gate
- import once in the background with a single save
- delete the 27 MB seed sqlite

## Changes
- `scripts/update_gtfs.py` (new; replaces `make_route_headsigns.py`): optionally downloads
  `gtfs_{b,bx,m,q,si,busco}.zip` (`--download DIR`). From those zips it writes:
  - `stops.txt` (fixed column order for `MTABusStop`, dedup by stop_id, location_type 0 only)
  - `routes.txt` (dedup by route_id)
  - `route_headsigns.txt`
  - `gtfs_version.txt`: feed_versions, the validity range, and the sha256 prefix of stops.txt,
    e.g. `20261009+20261012 20261012-20270102 stops:ac97808a8f50`
- Regenerated resources from feed_version 20261009 (busco 20261012), valid 2026-10-12 to 2027-01-02:
  - stops: 13,465 (was 15,018 from Jan 2023)
  - routes: 399 (was 288)
  - route_headsigns.txt came out byte-identical to the item 1 version
  - 783 stop IDs appear in both an NYCT feed and busco with slightly different coordinates. Only 41
    differ by more than 50 m (max 147 m), and none differ by name. The NYCT copy is kept.
- Removed `Resources/NYCBusNearby.sqlite` (27 MB) and its pbxproj entries. Added `gtfs_version.txt`
  to the project.
- `ViewModel.swift`:
  - Removed `launchedBefore` and the seed-store replacement. The obsolete `launchedBefore` key is
    removed from UserDefaults at init.
  - `persistenceContainer` is a plain container (no longer lazy).
  - `populateBusStops()` is now async. If the bundled `gtfs_version.txt` differs from the
    `stopsDataVersion` UserDefaults value, `importBundledStops(into:)` runs in
    `performBackgroundTask` as one `NSBatchDeleteRequest` plus one `NSBatchInsertRequest`, then stores
    the version. Stops are then fetched on the view context. If the store is still empty, it falls
    back to decoding `stops.txt` directly.
  - `stopsById` uses `uniquingKeysWith` (no crash on duplicate IDs).
  - New `@Published stopsLoaded`. `logger` and `read(from:type:)` are `nonisolated` so the
    background import can use them.
- `ContentView.swift`: recomputes on `viewModel.$stopsLoaded`. `updateStopsAndTrainsNearby()` does
  nothing until stops are loaded, so the "no nearby stations" alert can't fire before the import finishes.
- `CLAUDE.md`: updated the data-sources section.

## Verification
- iOS Simulator Debug build succeeded. The app bundle has no sqlite (34 MB total).
- Upgrade test on a temporary iOS 26.5 simulator (deleted afterwards):
  - Setup: planted the old seed store (NYCBusTrips model, with the trip table and 15,018 stops) as
    the app's store before first launch.
  - First launch: the store migrated, the trip table was dropped, and the file shrank from 27 MB to
    about 1 MB (sqlite + wal). It now holds 13,465 stops, and `stopsDataVersion` was set.
  - Relaunch: no re-import. "Loaded 13465 entities" was logged.
  - At Times Square (40.7580, -73.9855), nearby stops were listed (7 AV/W 44 ST, W 42 ST/7 AV, ...).
- Not checked: a fresh install with no prior store (same code path, minus migration), and headsigns
  and buses on the stop detail screen.

## Notes
- `routes.txt` is bundled but still not read by the app.
- Not committed.

# 2026-11-13: App Intents Phase 2 commit and favorites plan

## Phase 2 commit
- Reviewed `docs/plans/app-intents.md` and the pending Phase 2 changes.
- Simulator Debug build succeeded.
- Committed `b8f560c` ("feat: Add the "Show Nearby Buses" App Shortcut"):
  - `AppIntents/ShowNearbyBusesIntent.swift` and `AppIntents/NYCBusShortcuts.swift`
  - the `AppIntents` group in `project.pbxproj`
  - the CLAUDE.md App Intents section
  - the 2026-11-09 and 2026-11-10 App Intents worklogs
- Left out the unrelated worklog edits and untracked docs (`static-data-refresh.md` and older
  worklogs). Not pushed.

## Favorites investigation
- Read `ContentView`, `ViewModel`, `BusStopRowView`, `BusesAtStopView`, `BusTripUpdateView`,
  `MTABusStop`, the Core Data model, and the entitlements.
- Findings:
  - Each GTFS import batch-deletes the stop entity, so favorites need separate storage.
  - Arrivals are computed only for stops near the user.
  - The sidebar is hidden when there are no nearby buses.
  - The maps are centered on the user.
  - Selection uses the stop value.
  - There are no App Group or iCloud entitlements.
- Wrote `docs/plans/favorites.md`:
  - storage options (UserDefaults recommended) and the `FavoriteStop` model
  - Step 1: store
  - Step 2: `buses(at:)`
  - Step 3: UI (sections, star toolbar button, swipe actions, rename, missing stops, map centering)
  - Step 4: App Intents (`BusStopEntity`, query, open and next-bus intents, navigation request)
  - Step 5: later work
  - testing and decisions
- No code changes.

## Decisions and Step 1 details
- The user decided:
  - device-only storage (iCloud later)
  - favorites left out of Nearby (possibly a separate favorites menu)
  - nicknames in v1
  - Steps 1–3 to TestFlight, then the intents
- Recorded the decisions in `docs/plans/favorites.md` and expanded Step 1 into concrete steps:
  - `FavoriteStop`
  - `FavoriteStopsStore` (a JSON string in UserDefaults, with a backup if decoding fails)
  - `ViewModel` properties and the favorites extension
  - the snapshot refresh after the stops load
  - the project file entries
  - verification with `simctl defaults`
- Added an open question to Step 3: what "a separate menu for favorites" means.
- No code changes.

## Step 3 design revised
- The user chose no separate favorites section or screen. Instead, a toggle filters the stop list
  to favorites.
- Rewrote Step 3 in `docs/plans/favorites.md`:
  - a persisted `showFavoritesOnly` button-style toggle in the sidebar header
  - filter off: nearby stops, with a star on favorites
  - filter on: all favorites in the user's order, showing "No longer served" for missing ones,
    with reorder/delete and an empty state
  - star swipe actions and context menu items on every row
  - clear the selection when it's filtered out
- Updated decision 2 and G7.

## Step 1 implemented: favorites storage
- New `Model/FavoriteStop.swift`:
  - a `Codable`/`Sendable` copy of the stop's ID, name and coordinate, plus nickname and `addedAt`
  - `displayName`, `normalizedNickname` (trims, blank → nil, max 40), and `refresh(from:)`
- New `Model/FavoriteStopsStore.swift`:
  - a JSON string under the UserDefaults key `favoriteStops`, with ISO 8601 dates and sorted keys
  - if decoding fails: logs the error, copies the raw value to `favoriteStops.unreadable`, and
    returns `[]`
- `ViewModel.swift`:
  - `favoritesStore`, `@Published private(set) favoriteStops`, and `missingFavoriteIds`
  - favorites load in `init`, and `refreshFavoriteSnapshots()` runs before `stopsLoaded.toggle()`
  - a `// MARK: - Favorites` extension: `favoriteMTABusStops`, `isFavorite`,
    `favorite(forStopId:)`, add, remove, toggle, `moveFavorites(fromOffsets:toOffset:)` (written
    by hand, no SwiftUI import), and `renameFavorite`
  - every change goes through `updateFavorites(_:)` (saves only when something changed), which
    calls the empty `favoritesDidChange()` hook kept for Step 4
- `project.pbxproj`: added both files to the Model group and the Sources phase.

### Verification
- Generic simulator build: succeeded, no errors or warnings.
- On an iPhone 16e (iOS 26) simulator:
  - Seeded two favorites: stop 100014 with a wrong name, zero coordinates and nickname "Home",
    and a made-up 999999.
  - The log showed "Loaded 2 favorite stops", then "Favorite stops not in the stop data:
    ["999999"]".
  - The app's plist had 100014 corrected to "BEDFORD PK BLVD/GRAND CONCOURSE" (40.872562,
    -73.888156) with the nickname kept. 999999 was unchanged.
  - Wrote a corrupt value: the log showed the decode error and "Loaded 0 favorite stops".
    `favoriteStops.unreadable` held the raw value, and the original value wasn't overwritten.
- Found that `simctl spawn defaults read <bundle id>` doesn't show the app's saved value. Read the
  plist in the app's data container by path. Fixed the plan's instructions.
- Removed the test values and shut down the simulator.
- Add, remove, rename and move are only exercised once there's UI (Step 3).

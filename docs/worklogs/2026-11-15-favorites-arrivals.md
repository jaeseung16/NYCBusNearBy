# 2026-11-15: Favorites Step 2, arrivals for any stop

- Asked to do Step 3 of `docs/plans/favorites.md`, but Step 2 (which Step 3 builds on) wasn't
  done. The user chose to do Step 2 only for now.

## Changes
- `ViewModel.swift`:
  - New `buses(at stops:)`, the body of the old `buses(within:from:)`:
    - stop IDs in a `Set` instead of an `Array`
    - the `N`/`S` suffix is stripped *before* the membership test (it used to be tested with
      the raw feed ID and stripped afterwards)
    - `buses[stop, default: []].append`, and an early return when there are no stops
    - fixed the "Can't find a stop" log, which had a misplaced `)` and printed
      `privacy: .public)` literally
  - `buses(within:from:)` is now `buses(at: stops(within:from:))`.
- `ContentView.swift`:
  - `busesNearby` renamed to `busesByStop`
  - `updateStopsAndTrainsNearby()` always sets `busesByStop = buses(at: stopsNearby + favoriteMTABusStops)`.
    Without a location fix, favorites still get arrivals and the last nearby stops are kept.
  - The "no nearby stops" alert is shown only when there are no favorites either. Its text is
    now "There are no nearby bus stops" (was "subway stations").
  - `.onChange(of: viewModel.favoriteStops)` recomputes the arrivals. It's `onChange`, not
    `onReceive`, because `@Published` sends before the value is stored.
- `docs/plans/favorites.md`: status updated, and the Step 2 notes describe what was built.

## Verification
- Generic simulator Debug build: succeeded, no errors or warnings.
- Not run in the simulator. There's no UI for favorites yet (Step 3), so a far favorite's arrivals
  can't be seen. Check them during Step 3 testing.

## Step 2 committed
- `eb4ed68` "feat: Show arrivals for favorite stops anywhere": `ContentView.swift`,
  `ViewModel.swift`, the plan and this worklog. The unrelated worklog edits and untracked docs
  were left out.

## Step 3 implemented: favorites UI
- `ContentView.swift`:
  - `@AppStorage("showFavoritesOnly")`, a button-style star toggle in a new `sidebarHeader` next
    to the location label (icon only, `star.fill` when on)
  - filter off (`nearbyList`): nearby stops as before, favorites show ★ and their nickname
  - filter on (`favoritesList`): every favorite in the user's order, with distance when there's a
    fix. A favorite without a stop is greyed out and can't be selected ("No longer served" when
    it's in `missingFavoriteIds`). Empty state: `ContentUnavailableView("No Favorites", …)`.
  - `EditButton` (filter on, at least one favorite) with `.onMove` → `moveFavorites` and
    `.onDelete` → `removeFavorite`. Edit mode is shared `@State`, and is reset when the filter
    is turned off.
  - leading swipe action and context menu "Add to Favorites" / "Remove from Favorites" (yellow),
    plus "Rename…" on favorites: an alert with a `TextField`. Leaving it blank clears the
    nickname.
  - the `if !busesByStop.isEmpty` gate is gone
  - turning the filter on or off clears the selection if the selected stop isn't in the list.
    Not when favorites change, so unstarring the stop being viewed doesn't close it.
  - `distance(to:)` returns `nil` without a location fix. Removed the `kmSelected` branch,
    which only passed a different `distanceUnit`.
- `BusStopRowView`: `title`, `stopId`, optional `distance`, `isFavorite` (★), and
  `isUnavailable` ("No longer served", greyed out). It no longer takes an `MTABusStop`, so it can
  show a favorite whose stop is gone.
- `BusesAtStopView`:
  - toolbar star button ("Add to Favorites" / "Remove from Favorites") with
    `.sensoryFeedback(.selection, trigger:)`
  - the nickname as the title, with the GTFS name below it
- Maps: `ViewModel.mapRegion(showing:)` (and `MKCoordinateRegion.contains`) starts the camera on
  the stop when the stop is outside the current region. Used in `BusesAtStopView` and
  `BusTripUpdateView`. Both maps get `.id(stop.id)` so another stop gets a new camera.
- Plan updated with these details and the status.

### Verification
- Generic simulator Debug build: succeeded, no errors or warnings.
- iPad Pro 13-inch (M5) simulator, location set to Grand Central:
  - Filter on, favorites 100014 (nickname "Bronx", wrong snapshot) and a made-up 999999: the list
    showed ★ Bronx, 9.5 mi and greyed-out ★ OLD STOP "No longer served", with Edit and a filled
    star in the header.
  - Filter off, favorites 100014 and 403245 ("Office"): the nearby list sorted by distance, with
    ★ Office in place, an unfilled star, and no Edit button.
  - Removed the test values and shut down the simulator.
- Not tested yet, because these need taps: selecting a far favorite and its arrivals and map,
  the toolbar star, swipe actions, the context menu, rename, reorder and delete, selection clearing,
  relaunch persistence, and VoiceOver. These are in the plan's Testing section.

## Step 3 committed
- `46c39ee` "feat: Add the favorites UI", after the user tested it.

## Step 4 implemented: App Intents for stops
- New files in `AppIntents/`, added to the group and the Sources phase in `project.pbxproj`:
  - `BusStopEntity.swift`:
    - `BusStopEntity`, an `AppEntity` with the stop code as its ID. The title is the nickname or
      the name. The subtitle is "Stop #code", and also shows the GTFS name when there's a nickname.
    - `BusStopQuery` (`EntityStringQuery`):
      - suggestions are the favorites
      - `entities(for:)` looks in the favorites, then `stopsById`
      - `entities(matching:)` matches favorites by nickname or name, then stop codes (exact, then
        by prefix), then stop names, up to 20 results
  - `OpenStopIntent.swift`: `.foreground`, sets `viewModel.requestedStopId`.
  - `NextBusesAtStopIntent.swift`: `.background`. Waits for the stops and a feed up to 60 s old.
    Returns `[BusArrival]` and a dialog that reads the next three arrivals, e.g. "M15 to South
    Ferry in 4 minutes. B44 to Sheepshead Bay is canceled." Separate dialogs for a stop that's
    no longer served, an unreachable feed, and no buses in the time window.
  - `BusArrival.swift`: a `TransientAppEntity` with route, headsign, arrival time, minutes away,
    and canceled.
- `NYCBusShortcuts`: two App Shortcuts, 3 of the 10 allowed:
  - "When is the next bus at <stop>", "Next buses at <stop>", "Next buses at a stop"
  - "Show <stop>", "Open <stop>", "Open a bus stop"
  - each phrase ends with "in <app name>"
- `ViewModel`:
  - `requestedStopId`
  - `ensureStopsLoaded()`, which waits for the first stop load (now kept as `stopsLoadTask`)
  - `ensureFreshFeed(maxAge:)` and `lastFeedDownload`
  - `upcomingBuses(at:)`
  - `getAllDataAsync()` shares a download that is already running, so an intent and the launch
    (or Refresh) don't clear each other's data
  - `favoritesDidChange()` calls `NYCBusShortcuts.updateAppShortcutParameters()`
- `NYCBusNearbyApp.init` also calls `updateAppShortcutParameters()`.
- `ContentView`:
  - `showRequestedStop()` selects the requested stop and clears the selected bus. It runs on
    `requestedStopId` changes (`initial: true`, for a cold launch) and again once the stops load.
  - It turns the favorites filter off for a stop that isn't a favorite.
  - `busesByStop` also covers the selected stop.

### Verification
- Generic simulator build: succeeded, no errors or warnings.
- `Metadata.appintents/extract.actionsdata` lists:
  - the three intents: `OpenStopIntent` opens the app, `NextBusesAtStopIntent` doesn't
  - both entities
  - all nine phrases, with `${stop}` and `${applicationName}`
- F7: in four launches on the iPad simulator, all feeds downloaded in 0.29–0.35 s.
- Not run yet: the intents themselves. That needs Siri or the Shortcuts app, which can't be driven
  from the command line. To test:
  - the Shortcuts picker lists the favorites with their nicknames
  - search by code and by name
  - "Show <nickname>" with the app cold and warm
  - "When is the next bus at <nickname>" with the app not running
  - a canceled trip in the dialog
- Not committed.

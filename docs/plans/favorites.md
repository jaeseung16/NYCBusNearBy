# Plan: Favorite stops

Status: **Step 1 implemented** (2026-11-13). Step 2 is next. Decisions are recorded at the end.

Favorites came up in `docs/plans/app-intents.md` (finding F8, Phase 3 candidate 3): a stop-based
intent needs a short list of stops the user cares about, and stop names are poor search keys
(duplicated, GTFS-style). Favorites are also useful without intents: today the app shows nothing
about a stop once the user walks away from it.

## Findings from the current code

| # | Finding | Consequence |
|---|---------|-------------|
| G1 | `populateBusStops()` runs an `NSBatchDeleteRequest` on `MTABusStopEntity` every time `gtfs_version.txt` changes. | A favorite flag on the stop entity would be wiped each quarter. Favorites need their own storage. |
| G2 | A new GTFS can drop or renumber stops. | Store a snapshot (name, coordinate) with each favorite, so a missing stop can still be shown as "no longer served" instead of vanishing. |
| G3 | `buses(within:from:)` only builds arrivals for stops inside `maxDistance` of the user (F3). It also looks up `stopIds.contains` in an `Array` inside a triple loop. | A favorite across town gets no arrivals. Add `buses(at stops:)`, use a `Set`, and have `buses(within:)` call it. |
| G4 | `ContentView` hides the whole sidebar `List` when `busesNearby.isEmpty`. | Favorites must show even with no nearby buses and no location fix. |
| G5 | `updateStopsAndTrainsNearby()` does nothing without `viewModel.location`. The "no nearby stations" alert fires when there are no nearby stops (and still says "subway"). | Compute favorites' arrivals without a location. Don't show the alert when the user has favorites. |
| G6 | The maps in `BusesAtStopView` and `BusTripUpdateView` start from `viewModel.region`, which is centered on the user. | A far-away favorite's marker would be off screen. Center on the stop when it's outside the region. |
| G7 | The sidebar `List` uses the `MTABusStop` value as its selection. | Resolved by decision 2: one list with a favorites filter, so no stop is listed twice. |
| G8 | The entitlements file is empty: no App Group, no iCloud. | Local storage first. An App Group (widget) or iCloud sync is a later, separate step. |
| G9 | `selectedStop` / `selectedBus` are `@State` in `ContentView` (F2). | "Open favorite stop" intents need a navigation request the view model can set. |

## Storage

| Option | Pros | Cons |
|--------|------|------|
| **UserDefaults, JSON-encoded `[FavoriteStop]`** (recommended) | Tiny list, keeps order, survives stop re-imports, no model migration. Moving to `UserDefaults(suiteName:)` for an App Group later is one line. | No sync across devices. |
| New Core Data entity (model version `NYCBusNearby 3`) | Same store as the stops. | Migration for a list of ~10 IDs. Sharing with a widget needs the whole store in the App Group. |
| `NSUbiquitousKeyValueStore` (iCloud KVS) | Syncs between iPhone and iPad. | Needs the iCloud entitlement and merge handling. Can be layered on top of the UserDefaults store later. |

Recommendation: UserDefaults now, behind a small store type so the backing can change.

```swift
/// A stop the user starred. Keeps a snapshot of the stop so it survives GTFS updates.
struct FavoriteStop: Codable, Hashable, Identifiable, Sendable {
    let id: String          // stop_id, the code on the sign
    var name: String        // snapshot of MTABusStop.name, refreshed after each stop load
    var latitude: Double
    var longitude: Double
    var nickname: String?   // "Home", "Work"; what Siri and the list show when set
    var addedAt: Date

    var displayName: String { nickname ?? name }
}
```

## Steps

### Step 1: Model and store (~0.5 day)

Two new files plus a `// MARK: - Favorites` extension at the end of `ViewModel.swift`. The extension
goes in that file, not a separate one, because `favoriteStops` has a `private(set)` setter.
Step 1 doesn't change anything the user can see. It ships to TestFlight together with Steps 2–3.

1. **`Model/FavoriteStop.swift`**: `Codable, Hashable, Identifiable, Sendable` with
   `id`, `name`, `latitude`, `longitude`, `nickname: String?`, `addedAt`.
   - `init(stop: MTABusStop, nickname: String? = nil, addedAt: Date = .now)`
   - `displayName`
   - `static func normalizedNickname(_:)`: trims whitespace, returns `nil` for an empty
     string, and cuts the name to 40 characters.
   - `mutating func refresh(from stop: MTABusStop) -> Bool` updates the snapshot and returns
     whether anything changed.
   - Don't embed `MTABusStop`. Its `CodingKeys` are CSV column positions (`Int`), so stored JSON
     would be unreadable and fragile. New fields must be optional so old JSON still decodes.
2. **`Model/FavoriteStopsStore.swift`**: a struct, used only on the main actor.
   - `init(defaults: UserDefaults = .standard, key: String = "favoriteStops")`.
   - `load() -> [FavoriteStop]` and `save(_:)` store a JSON **string** (dates as `.iso8601`,
     keys sorted). A string, not `Data`, so it can be read and edited with `defaults` while
     testing.
   - In the simulator, read and write the app's own plist by **path**:
     `xcrun simctl spawn booted defaults read "$(xcrun simctl get_app_container booted com.resonance.NYCBusNearby data)/Library/Preferences/com.resonance.NYCBusNearby"`.
     `defaults read com.resonance.NYCBusNearby` (by domain) uses a different domain. The app
     reads that domain only as a fallback, and its saves don't show there. Use `-string` when
     writing JSON.
   - If decoding fails: log it, copy the raw value to `favoriteStops.unreadable`, and return `[]`.
     The user's favorites are never silently lost.
   - Later, an App Group is `UserDefaults(suiteName:)`, and iCloud sync goes behind this same type.
3. **`ViewModel.swift`, stored properties:**
   - `let favoritesStore = FavoriteStopsStore()`
   - `@Published private(set) var favoriteStops = [FavoriteStop]()`
   - `private(set) var missingFavoriteIds = Set<String>()`
4. **`ViewModel.init`:** set `favoriteStops = favoritesStore.load()` before the two `Task`s, and
   log the count.
5. **`populateBusStops()`:** call `refreshFavoriteSnapshots()` right before
   `stopsLoaded.toggle()`. Then `ContentView` sees refreshed favorites in the same update.
6. **The `// MARK: - Favorites` extension:**
   - `favoriteMTABusStops: [MTABusStop]` returns favorites that still exist, in the user's order
     (`compactMap { stopsById[$0.id] }`).
   - `isFavorite(_ stop:)` and `favorite(forStopId:)`.
   - `addFavorite(_:)` appends and ignores duplicates. `removeFavorite(id:)`,
     `toggleFavorite(_:)`, and `moveFavorites(fromOffsets:toOffset:)` do the rest. `move` is a
     SwiftUI extension on `Array`, so import SwiftUI or reorder the array by hand.
   - `renameFavorite(id:nickname:)` stores the result of `normalizedNickname`.
   - `refreshFavoriteSnapshots()`:
     - Does nothing if `stopsById` is empty.
     - Otherwise it recomputes `missingFavoriteIds`, and refreshes each favorite whose stop
       still exists.
   - `private func updateFavorites(_ change: (inout [FavoriteStop]) -> Void)` is the single point
     where favorites change:
     - It applies the change to a copy and returns early if nothing changed.
     - Otherwise it assigns `favoriteStops`, saves, and calls `favoritesDidChange()`.
   - `favoritesDidChange()` is empty for now. Step 4 adds
     `NYCBusShortcuts.updateAppShortcutParameters()` there.
7. **`project.pbxproj`:** add both files to the `Model` group and the Sources build phase. Each
   needs a `PBXBuildFile`, a `PBXFileReference`, a group child, and a Sources entry, as in
   `b8f560c`.
8. **Verify** (no UI yet):
   - Build.
   - Write a favorite with the simulator's `defaults write`, using a real stop ID, a wrong name,
     and a made-up ID. Then launch.
   - The log should show "Loaded 2 favorites", then one missing favorite after the stops load.
   - `defaults read` should show the real stop's name corrected.
   - Corrupt the value and relaunch: the log shows the error and `favoriteStops.unreadable` holds
     the raw value.
9. **Commit** "feat: Store favorite stops", with a worklog entry.

### Step 2: Arrivals for any stop (~0.5 day)

- `ViewModel.buses(at stops: [MTABusStop]) -> [MTABusStop: [MTABus]]`: the body of today's
  `buses(within:from:)`, with the stop IDs in a `Set` and the `N`/`S` suffix stripped *before* the
  membership test (today the test uses the raw ID and the stripping happens after it).
- `buses(within:from:)` becomes `buses(at: stops(within:from:))`.
- `ContentView.updateStopsAndTrainsNearby()`:
  - Always compute `buses(at: viewModel.favoriteMTABusStops)`, with or without a location.
  - Merge it with the nearby result into one `busesByStop` dictionary (rename `busesNearby`), so
    `getBuses(at:)`, `getSortedBuses(at:)`, and `getTripUpdates(for:near:)` work for both.
  - Show the "no nearby stops" alert only when there are no favorites either. Fix its text to
    "There are no nearby bus stops".
- Also call it from `.onReceive(viewModel.$favoriteStops)`.

### Step 3: UI (~1–1.5 days)

**Sidebar (`ContentView`)**: one list plus a favorites filter (decision 2). No separate
section or screen.
- **Filter toggle:** `@AppStorage("showFavoritesOnly")`. It's a
  `Toggle(isOn:) { Label("Favorites", systemImage: "star") }` with `.toggleStyle(.button)` in the
  header row next to the location label, and shows `star.fill` when on. Persisting it means a user
  who mostly uses favorites gets them on every launch.
- **Off (default):** nearby stops sorted by distance, as today. Rows that are favorites show a
  `star.fill` and their nickname.
- **On:** all favorites, wherever they are, in the user's order. They show the distance when
  there's a location fix. Missing favorites (G2) are greyed out with "No longer served", can't be
  selected, and can be swiped to delete. When there are no favorites, show
  `ContentUnavailableView("No Favorites", systemImage: "star", description: "Tap ☆ on a stop to add it.")`.
- Remove the `if !busesNearby.isEmpty` gate (G4). With the filter on, the list doesn't need a
  location fix.
- Every row has a leading swipe action and a context menu item "Add to Favorites" or
  "Remove from Favorites" (`star`, yellow tint). Favorite rows also get "Rename…" (an alert with a
  `TextField`).
- With the filter on, an `EditButton` reorders favorites (`.onMove` → `moveFavorites`), and
  `.onDelete` removes them.
- If `selectedStop` isn't in the filtered list when the filter changes, clear `selectedStop` and
  `selectedBus`.

**`BusStopRowView`**
- Add `title: String` (so a nickname can replace the name), make `distance` optional, and add
  `isFavorite: Bool` for a small `star.fill`.

**`BusesAtStopView`**
- Toolbar button: `star` / `star.fill`, accessibility label "Add to Favorites" / "Remove from
  Favorites", `.sensoryFeedback(.selection, trigger:)`. This is the main way to add a favorite,
  because it's where the user is looking at the stop.
- Show the nickname as the title with the GTFS name below it when a nickname is set.
- Map (G6): if the stop is outside `viewModel.region`, start the camera on the stop. Do the same in
  `BusTripUpdateView`.

### Step 4: App Intents (~1.5–2 days)

This is candidate 3 of `docs/plans/app-intents.md`. Follow its "How to add an intent" steps.

- `AppIntents/BusStopEntity.swift`: `AppEntity`, `id` = stop code, display title = `displayName`,
  subtitle "Stop #<code>". Built from `FavoriteStop` or `MTABusStop`, and `Sendable` (F9).
- `BusStopQuery: EntityStringQuery`:
  - `suggestedEntities()` returns the favorites (this list feeds the Siri phrase parameter and the
    Shortcuts picker).
  - `entities(for:)` looks up favorites, then `stopsById`.
  - `entities(matching:)` matches favorites first, then the stop code, then the name (capped at
    20 results).
- Navigation (G9): `ViewModel.@Published var requestedStopId: String?`. `ContentView` observes it,
  sets `selectedStop`, clears `selectedBus`, and resets the request.
- Readiness (F4): `ViewModel.ensureStopsLoaded()` (awaits the first `populateBusStops()`), and
  `ensureFreshFeed(maxAge: 60)` for the background intent.
- `OpenStopIntent` (`.foreground`, parameter `stop: BusStopEntity`): sets `requestedStopId`.
- `NextBusesAtStopIntent` (`.background`): `ensureStopsLoaded`, `ensureFreshFeed`,
  `buses(at: [stop])`. Returns `[BusArrival]` (`Sendable`: route, headsign, minutesAway,
  isCanceled) and a dialog such as "M15 to South Ferry in 4 minutes. B44 is canceled." Measure the
  feed time first (F7).
- `NYCBusShortcuts`: add `"Show \(\.$stop) in \(.applicationName)"` and
  `"When is the next bus at \(\.$stop) in \(.applicationName)"`. The provider would then have
  3 of the 10 allowed App Shortcuts.
- Call `NYCBusShortcuts.updateAppShortcutParameters()` on launch and whenever favorites change.

### Step 5: Later

- Spotlight: `IndexedEntity` on `BusStopEntity` for the favorites.
- Onscreen "this stop": `.userActivity` with `appEntityIdentifier` in `BusesAtStopView`.
- Widget or Control: move the favorites to an App Group suite (G8). That's a change to one line in
  `FavoriteStopsStore`.
- iCloud KVS sync, if users ask for it.
- Next arrival in the favorite row ("M15 · 4 min"), if the sidebar has room.

## Testing (manual, no test target)

- Add, remove, rename, and reorder favorites, then relaunch: the order and nicknames persist.
- Favorite a stop, then set the simulator location somewhere else in the city. The favorite still
  shows arrivals, and its map is centered on the stop.
- Set a location outside NYC with favorites: no "no nearby stops" alert, favorites still work.
- Deny location permission: favorites still show arrivals.
- Change `gtfs_version.txt` locally to force a re-import: favorites survive. Edit a favorite's ID
  in UserDefaults to a nonexistent one: it shows as "No longer served".
- Filter toggle: on/off survives relaunch. Turning it on while a nearby non-favorite is selected
  clears the selection. A far favorite is selectable and shows arrivals (iPad three columns too).
- VoiceOver: the star button and swipe actions have labels.
- Step 4: the Shortcuts picker lists favorites with nicknames. Siri "Show Home in NYC Buses Near
  Me" opens the stop, with the app cold and warm.

## Decisions (2026-11-13)

1. **Storage:** device only (UserDefaults). Consider iCloud sync after the screens are done.
2. **Display:** no separate section or screen. One list, with a toggle that filters it to favorites
   (revised 2026-11-13).
3. **Nicknames:** in the first version.
4. **Order:** Steps 1–3 go to TestFlight for testing. Then Step 4 (intents) and a second
   TestFlight round.

# Plan: Sync favorites through iCloud

Status: **Step 1 implemented** (2026-11-17). Steps 2–3 planned. Decisions are recorded at the end.

Follows `docs/plans/favorites.md` (Step 5, "iCloud KVS sync") and decision 1 there ("consider iCloud
sync after the screens are done"). Favorites, nicknames, and their order should be the same on the
user's iPhone and iPad.

## Findings from the current code

| # | Finding | Consequence |
|---|---------|-------------|
| S1 | `FavoriteStopsStore` saves the whole list as one JSON string under `favoriteStops` in `UserDefaults.standard`. | The store is the one place for the App Group move. Nothing else reads UserDefaults for favorites. |
| S2 | Every change goes through `ViewModel.updateFavorites(_:)`, which saves and calls `favoritesDidChange()` (updates the App Shortcut parameters). | A change that arrives from iCloud can go through the same path, but must not be written back to iCloud. |
| S3 | `NYCBusNearby.entitlements` is empty. Team `U8VSJXRJTQ`, bundle ID `com.resonance.NYCBusNearby`, automatic signing. | Add the iCloud key-value storage and App Group entitlements. Xcode updates the App ID and profiles on the next signed build. |
| S4 | `refreshFavoriteSnapshots()` rewrites names and coordinates after each stop load. | Two devices on different GTFS versions would keep rewriting each other's snapshot. Only the ID, nickname, and order are synced. |
| S5 | A widget (later, not in this plan) needs favorites in an App Group. | Move the local copy to an App Group in the same release, so favorites migrate once. |
| S6 | `ContentView` already observes `scenePhase` and `viewModel.favoriteStops` (`.onChange`). | A remote change updates the sidebar with no new view code. Foregrounding is the place to ask KVS for fresh values. |

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **`NSUbiquitousKeyValueStore` (iCloud KVS)** (chosen) | Made for small preferences. No schema, no CloudKit dashboard. Works for any user signed in to iCloud. | Last writer wins per key. Sync is batched (seconds to minutes). Limits of 1 MB and 1,024 keys, far above a list of favorites. Keys are at most 64 bytes. |
| CloudKit private database (`CKSyncEngine`) | Per-record sync and conflict handling. | Record type, container, schema deployment, and much more code for ~10 items. |
| Core Data + `NSPersistentCloudKitContainer` | Same store as the stops. | The stop entity is batch-deleted each quarter, so a second store configuration is needed anyway. Overkill. |

## Design

### What lives where

| Where | Key | Value |
|-------|-----|-------|
| App Group suite `group.com.resonance.NYCBusNearby` (local) | `favoriteStops` | The JSON list, as today. **What the app shows.** |
| | `favoriteStops.unreadable` | As today. |
| | `favoriteSyncedIds` | `[String]`: the IDs in iCloud after the last merge or upload. |
| iCloud KVS | `favorite.<stopId>` | One `FavoriteStop` JSON string per favorite (same encoding). |
| | `favoriteOrder` | `[String]` of stop IDs. |

**One key per favorite, not one list.** If the whole list were one key, an edit made on the iPad
while the iPhone is offline would be lost when the iPhone's list arrives. With one key per
favorite, iCloud merges independent additions, removals, and renames.

**KVS caches writes.** `NSUbiquitousKeyValueStore` writes to a local cache right away and uploads
later, so edits made offline sync by themselves once the device is online. `favoriteSyncedIds`
covers the remaining cases: favorites that existed before this release, and favorites added while
signed out of iCloud.

### Merge (iCloud → local)

Runs at launch, on every external-change notification, and when the app becomes active. Inputs:
the local list `L`, the cloud favorites `C` (decoded from every `favorite.` key), the cloud order
`O` (may be missing), and the synced IDs `S`.

1. For each favorite in `L`, in order:
   - In `C`: keep it. Take the nickname from `C` (normalized with `normalizedNickname`). Keep the
     local name and coordinate (S4).
   - Not in `C`, but in `S`: it was removed on another device. Drop it.
   - Not in `C` and not in `S`: it was added here without reaching iCloud. Keep it and upload it.
2. Each favorite in `C` that's not in `L` was added on another device. Add it with the cloud
   snapshot. `refreshFavoriteSnapshots()` corrects the snapshot later, and an unknown stop shows
   as "No longer served", as today.
3. Order: the IDs in `O` that are in the result, then the rest. The rest is the local favorites in
   local order, then the new cloud favorites by `addedAt`. So an order written before a concurrent
   add never hides that favorite.
4. Upload: write `favorite.<id>` for the favorites from step 1's third case. Write `favoriteOrder`
   if the result's order differs from `O`.
5. Save `S` = the result's IDs.

A cloud value that doesn't decode is logged and skipped, never deleted. It may come from a newer
version of the app.

### Upload (local → iCloud)

`upload(old:new:)` runs after each local change. It compares only the synced fields:
- an ID in `old`, not in `new`: `removeObject(forKey: "favorite.<id>")`
- an ID in `new`, not in `old`, or its nickname changed: `set(json, forKey: "favorite.<id>")`
- the ID order changed: `set(ids, forKey: "favoriteOrder")`
- then save `S` = `new`'s IDs

A snapshot refresh changes only the name and coordinate, so it writes nothing. Writing unchanged
keys would undo a concurrent edit on the other device.

### Notifications

`NSUbiquitousKeyValueStore.didChangeExternallyNotification`, by the reason in
`NSUbiquitousKeyValueStoreChangeReasonKey`:
- `NSUbiquitousKeyValueStoreServerChange`, `NSUbiquitousKeyValueStoreInitialSyncChange`: merge.
  Log `NSUbiquitousKeyValueStoreChangedKeysKey`.
- `NSUbiquitousKeyValueStoreAccountChange`: clear `S`, then merge. The local favorites are kept and
  uploaded to the new account.
- `NSUbiquitousKeyValueStoreQuotaViolationChange`: log an error. Not expected at this size.

Swift 6: use `NotificationCenter.default.addObserver(forName:object:queue: .main)`. Read the reason
as an `Int` and the keys as `[String]` in the closure, then call `MainActor.assumeIsolated`. Don't
pass the `Notification` itself across, because it isn't `Sendable`.

### Known limits (acceptable)

- Renaming the same favorite on two devices at once: the last write wins.
- Removing a favorite on A while B renames it offline: if B's rename arrives last, the favorite
  comes back with the new nickname.
- Reordering on two devices at once: the last order wins. Favorites missing from it are appended.
- An older app version that re-uploads a favorite drops fields it doesn't know. New fields stay
  optional, as `FavoriteStop` already requires.

## Steps

### Step 1: Move favorites to the App Group (~0.5 day)

1. **Entitlements** (`NYCBusNearby/NYCBusNearby.entitlements`). Add both keys now, so the App ID and
   profiles change only once:
   ```xml
   <key>com.apple.developer.ubiquity-kvstore-identifier</key>
   <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.resonance.NYCBusNearby</string>
   </array>
   ```
   Then build once in Xcode with automatic signing. Xcode registers the App Group and enables
   iCloud on the App ID. Check Signing & Capabilities: iCloud shows "Key-value storage" checked,
   and App Groups shows the group checked with no red warnings.
2. **`FavoriteStopsStore`:**
   - `static let appGroupId = "group.com.resonance.NYCBusNearby"`.
   - `static var sharedDefaults: UserDefaults`: `UserDefaults(suiteName: appGroupId)`, or
     `.standard` with a logged error if that returns `nil`.
   - Change the `init` default to `defaults: UserDefaults = FavoriteStopsStore.sharedDefaults`.
   - `migrateFromStandardDefaults()`, called at the start of `load()`: if the suite has no
     `favoriteStops` and `.standard` has one, copy it (and `favoriteStops.unreadable` if present),
     then remove both from `.standard`. Log "Moved favorites to the App Group".
   - `loadSyncedIds() -> Set<String>` and `saveSyncedIds(_:)` for `favoriteSyncedIds` (used in
     Step 2).
   - Update the doc comment's `simctl` command. The App Group plist is at:
     `"$(xcrun simctl get_app_container booted com.resonance.NYCBusNearby groups | awk '$1 == "group.com.resonance.NYCBusNearby" {print $2}')/Library/Preferences/group.com.resonance.NYCBusNearby.plist"`.
3. **`favorites.md`:** update the Step 1 testing note for the new location.
4. **Verify:**
   - Simulator CLI build (`CODE_SIGNING_ALLOWED=NO`).
   - Delete the app, then run the last commit's `FavoriteStopsStore`
     (`git stash push NYCBusNearby/Model/FavoriteStopsStore.swift`, Cmd+R) and add two favorites
     with a nickname. (`main` predates favorites, so it can't be used.) Then `git stash pop` and run
     again: the log shows the move, the favorites and nickname survive, and the suite plist has
     them while the app's own plist no longer does.
   - Relaunch: no second move.
5. **Commit** "feat: Move favorites to an App Group", with a worklog entry.

### Step 2: iCloud sync (~1 day)

1. **`Model/FavoritesCloudSync.swift`** (new), a `@MainActor final class`:
   - `init(store: NSUbiquitousKeyValueStore = .default, local: FavoriteStopsStore)`.
   - `start(onExternalChange: @escaping @MainActor () -> Void)`: adds the observer (above), then
     calls `store.synchronize()` and logs a `false` result. `false` means no entitlement, for
     example in an unsigned CLI build. Favorites still work locally.
   - `merge(local: [FavoriteStop]) -> [FavoriteStop]`: reads the cloud state, applies the merge
     rules, does the uploads from merge step 4, saves `S`, and returns the merged list. Log counts
     (kept, removed remotely, added remotely, uploaded).
   - `upload(old: [FavoriteStop], new: [FavoriteStop])`.
   - `accountChanged()`: clears `S`.
   - Private helpers: `cloudFavorites() -> [String: FavoriteStop]` (keys with the `favorite.`
     prefix, from `store.dictionaryRepresentation`), `cloudOrder() -> [String]?`, and `key(for:)`.
   - Use the same JSON encoder and decoder settings as `FavoriteStopsStore` (`.iso8601`,
     `.sortedKeys`). Share them through two static helpers on `FavoriteStopsStore` rather than
     copying them.
2. **`ViewModel`:**
   - `private(set) lazy var favoritesSync = FavoritesCloudSync(local: favoritesStore)`, or create it
     in `init`.
   - In `init`, after `favoriteStops = favoritesStore.load()`: call
     `favoritesSync.start { [weak self] in self?.mergeFavoritesFromCloud() }`, then
     `mergeFavoritesFromCloud()`.
   - `func mergeFavoritesFromCloud()`:
     `let merged = favoritesSync.merge(local: favoriteStops)` and
     `updateFavorites(origin: .cloud) { $0 = merged }`.
   - `enum FavoritesChangeOrigin { case local, cloud }`. `updateFavorites(origin: = .local, _:)`
     keeps the old value and, after saving, calls `favoritesSync.upload(old:new:)` only for
     `.local`. `favoritesDidChange()` runs for both, so the Siri and Shortcuts suggestions update
     on remote changes too.
   - `removeFavorite(id:)` already removes the ID from `missingFavoriteIds`. A remote removal goes
     through `updateFavorites` instead, so call `refreshFavoriteSnapshots()` (or recompute
     `missingFavoriteIds`) at the end of `mergeFavoritesFromCloud()`. That also corrects the
     snapshot of favorites added remotely, when the stops are loaded.
3. **`ContentView`:** in the existing `.onChange(of: scenePhase)`, when `.active`, call
   `viewModel.syncFavorites()`, which calls `NSUbiquitousKeyValueStore.default.synchronize()` and
   then merges. Nothing else changes (S6). A remote removal of the stop on screen leaves it open,
   matching what unstarring does today.
4. **`project.pbxproj`:** add `FavoritesCloudSync.swift` to the `Model` group and the Sources phase
   (`PBXBuildFile`, `PBXFileReference`, group child, Sources entry), as for `FavoriteStopsStore`.
5. **CLAUDE.md:** a short "Favorites" paragraph under Architecture covering the App Group,
   the KVS keys, the merge entry points, and the rule that snapshots aren't synced.
6. **Verify:**
   - Simulator CLI build.
   - Run from Xcode on a simulator signed in to iCloud: the log shows `synchronize` succeeded and
     the first merge uploaded the existing favorites.
   - **Device testing**, listed below.
7. **Commit** "feat: Sync favorites through iCloud", with a worklog entry.

### Step 3: TestFlight (~0.5 day of waiting and testing)

- Bump the build number. Archive: the distribution profile must contain both entitlements. Check
  App Store Connect's processing email for entitlement errors.
- Test the upgrade path from the App Store version on a device that has favorites.

## Testing (manual, no test target)

KVS needs a signed build and an iCloud account. Use two devices (or a device and a simulator)
signed in to the same Apple ID. The Simulator's Features > Trigger iCloud Sync menu item forces a
sync. Between devices, foregrounding the app usually picks up changes within a minute.

| Case | Expected |
|------|----------|
| Upgrade with existing favorites | Favorites, order, and nicknames survive. They appear on the second device. |
| Fresh install on device B | Favorites from A appear after the initial sync (`InitialSyncChange`). |
| Add, rename, reorder, remove on A | B updates. B's Shortcuts picker shows the new names. |
| Both offline: A adds X, B adds Y, A removes a shared Z | Online again: both have X and Y, and Z is gone on both. |
| Remote favorite whose stop B doesn't have | Shows as "No longer served" on B, can be removed. |
| Sign out of iCloud on B | B keeps its favorites, no errors. Changes made while signed out upload after signing in again. |
| Settings > Apple Account > iCloud > turn off the app | Favorites still work locally. |
| Rename the same favorite on both | The last rename wins on both. |

## Decisions (2026-11-16)

1. **Backend:** iCloud key-value storage.
2. **App Group:** move the local favorites to `group.com.resonance.NYCBusNearby` in this work
   (Step 1).
3. **Scope:** sync only favorites (IDs, nicknames, order). Not `maxDistance`, `maxComing`,
   `distanceUnit`, or `showFavoritesOnly`.
4. **Widget:** not now.

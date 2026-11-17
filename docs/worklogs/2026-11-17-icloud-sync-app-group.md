# 2026-11-17: iCloud sync Step 1, move favorites to the App Group

Following `docs/plans/icloud-sync.md`, Step 1.

- `NYCBusNearby.entitlements`: added `com.apple.developer.ubiquity-kvstore-identifier`
  (`$(TeamIdentifierPrefix)$(CFBundleIdentifier)`) and `com.apple.security.application-groups`
  (`group.com.resonance.NYCBusNearby`). Both go in now, so the App ID and profiles change once.
- `Model/FavoriteStopsStore.swift`:
  - `appGroupId`, and `sharedDefaults` (the suite, or `.standard` with a logged error).
  - The `init` now defaults to `sharedDefaults`.
  - `migrateFromStandardDefaults()`, run at the start of `load()`: if the suite has no
    `favoriteStops` and `.standard` has one, it copies the value (and `favoriteStops.unreadable`),
    removes both from `.standard`, and logs "Moved favorites to the App Group". It skips the move
    when the store itself is backed by `.standard`.
  - `loadSyncedIds()` and `saveSyncedIds(_:)` for `favoriteSyncedIds`, to be used in Step 2.
  - Updated the doc comment with the `simctl` path of the App Group plist.
- `docs/plans/favorites.md`: added the App Group plist path to the Step 1 testing note.
- `docs/plans/icloud-sync.md`: status set to Step 1 in progress.
- Verified: simulator CLI build (`CODE_SIGNING_ALLOWED=NO`) succeeds.
- Still to do: a signed build in Xcode to register the capabilities, the migration test from a
  `main` build, then the commit.

## Signing check
- The iCloud capability wasn't listed in Signing & Capabilities until the user added it with
  "+ Capability". Key-value storage was already checked, because the entitlement was in the file.
- Xcode changed two files: an empty `com.apple.developer.icloud-container-identifiers` array in the
  entitlements (harmless; KVS doesn't use containers) and `DEVELOPMENT_TEAM = U8VSJXRJTQ` in both
  target configurations of `project.pbxproj`. Both are kept.
- Explained how to set a nickname: long-press a favorite stop's row in the sidebar, then choose
  "Rename…".

## Correction to the migration test
- The plan said to set up favorites with a build from `main`, but `main` (54a716d) predates the
  favorites; they exist only on branch `2026`. The "old" build is `2026` at HEAD (a1b4741) without
  the uncommitted `FavoriteStopsStore` change.
- The user's favorites were already saved in the App Group by the new code, so the move would be
  skipped. Updated the plan's Step 1 test: delete the app, stash only `FavoriteStopsStore.swift`,
  add favorites, pop the stash, and run again.

## Verification and commit
- Migration test in the simulator (iPhone 18 Pro Max, iOS 27.0) passed: "Moved favorites to the App
  Group" and "Loaded 2 favorite stops" on the first run, and only "Loaded 2 favorite stops" after a
  relaunch. The App Group plist has both favorites (one with a nickname), and the app's own plist no
  longer has `favoriteStops`.
- `simctl get_app_container booted <bundle> <group id>` doesn't work in this Xcode (prints usage),
  although its help lists that form. Replaced the command in the `FavoriteStopsStore` doc comment,
  `favorites.md`, and `icloud-sync.md` with the `groups` form filtered by `awk`:
  `xcrun simctl get_app_container booted com.resonance.NYCBusNearby groups | awk '$1 == "group.com.resonance.NYCBusNearby" {print $2}'`.
  Verified it reads the favorites.
- Plan status: Step 1 implemented.
- Committed "feat: Move favorites to an App Group" (code, entitlements, project, the plan, and this
  worklog with the plan's worklog). Unrelated doc changes in the working tree were left out.

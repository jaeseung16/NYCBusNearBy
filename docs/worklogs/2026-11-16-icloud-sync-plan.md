# 2026-11-16: iCloud sync plan for favorites, widget overview

- The user tested the App Intents and favorites on a device; both look good.
- Read `docs/plans/app-intents.md`, `docs/plans/favorites.md`, `FavoriteStopsStore`, `FavoriteStop`,
  the favorites extension of `ViewModel`, and the (empty) entitlements.
- Wrote `docs/plans/icloud-sync.md`:
  - options: iCloud KVS (recommended), CloudKit, Core Data + CloudKit
  - one KVS key per favorite plus a `favoriteOrder` key, so edits on two devices merge
  - `favoriteSyncedIds` to tell remote removals from offline additions
  - snapshot refreshes stay local; changes from iCloud aren't written back
  - move the local copy to an App Group in the same change, for a future widget
  - testing on two devices, and three decisions (backend, App Group now, which settings sync)
- Explained what a widget would involve (in the conversation): App Group, a widget extension,
  shared intents, the per-stop data source, and refresh budgets.
- No code changes.

## Decisions and detailed plan
- The user decided: iCloud KVS, move the local favorites to the App Group now, sync only
  favorites, no widget for now.
- Rewrote `docs/plans/icloud-sync.md` with the decisions and a step-by-step plan:
  - storage table (App Group suite locally, `favorite.<id>` and `favoriteOrder` in KVS)
  - exact merge rules (iCloud → local) and upload rules (local → iCloud), notification handling,
    Swift 6 observer notes, and known last-writer-wins limits
  - Step 1: entitlements + App Group move with migration from `UserDefaults.standard`
  - Step 2: `FavoritesCloudSync`, `updateFavorites(origin:)`, merge on launch / notification /
    foreground, project and CLAUDE.md updates
  - Step 3: TestFlight
  - a testing table for two devices
- No code changes.

# 2026-11-10: App Intents base setup and "Show Nearby Buses"

## Plan revision (`docs/plans/app-intents.md`)
- Reordered the plan:
  - Phase 1: base setup that makes each new intent a small change.
  - Phase 2: a parameterless intent that opens the app.
- Moved the stop-name intents (`OpenBusStopIntent`, `GetNextBusesIntent`) to a Phase 3 candidate
  list. It's unclear how a user would know a stop name: names are duplicated and GTFS-style.
- Added a "How would a user choose a stop?" table: nearest, favorites, onscreen "this stop",
  sign stop code, name search. Ranked candidates: route alerts, next buses at the nearest stop,
  favorites, Use Model chaining, onscreen entity.
- Added a "How to add an intent" checklist.

## Phase 1: base setup
- `NYCBusNearbyApp.init` creates the `ViewModel` and registers it with
  `AppDependencyManager.shared.add(dependency:)`.
- New `AppIntents/` group in the Xcode project (added to `project.pbxproj` by hand; the project
  doesn't use synchronized folders).
- `AppIntents/NYCBusShortcuts.swift`: the single `AppShortcutsProvider`.

## Phase 2: "Show Nearby Buses"
- `AppIntents/ShowNearbyBusesIntent.swift`: no parameters, `supportedModes = .foreground`, and it
  just opens the app.
- Phrases: "Show nearby buses in ${applicationName}", "Show buses near me in …",
  "Find bus stops near me in …". Short title "Nearby Buses".

## Verification
- Simulator Debug build succeeded with no errors or warnings.
- `Metadata.appintents/extract.actionsdata` contains `ShowNearbyBusesIntent` and the three phrases.
- Not yet tested on a device or in the Shortcuts app.

## Other
- Updated CLAUDE.md: App wiring (the dependency registration; ATT/AdMob now start in
  `AdsStarter`) and a new App Intents section.

## Phase 1 commit
- Committed `a4e163d` ("feat: Register the view model for App Intents"): the
  `AppDependencyManager` registration in `NYCBusNearbyApp.swift` and `docs/plans/app-intents.md`.
- `NYCBusShortcuts.swift` and the `AppIntents/` project group were left for the Phase 2 commit,
  because an `AppShortcutsProvider` needs at least one shortcut.
- Built that commit alone in a temporary worktree: build succeeded.
- Phase 2 (`ShowNearbyBusesIntent`) was already implemented earlier today. It's still uncommitted,
  waiting for the user.

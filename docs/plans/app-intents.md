# Plan: App Intents, Siri/Shortcuts, and Apple Intelligence

Status: **Phases 1–2 implemented** (2026-11-10). Phase 3 is waiting on use-case decisions.
First written 2026-11-09. Revised 2026-11-10.

## What changed in this revision

- **Base setup first.** Phase 1 sets up the structure that every later intent uses, so adding an
  intent is "write one file and add one `AppShortcut`".
- **No stop-name intents for now.** The first draft centered on `OpenBusStopIntent` /
  `GetNextBusesIntent` with a `BusStopEntity` parameter. It is unclear how a user would know a stop's
  name: the app never asks for one, the user just sees the stops nearby. 3,485 of 13,465 names are
  duplicated, and the names are GTFS-style ("BROADWAY/W 72 ST"), not what people say. Those
  intents moved to the candidate list in Phase 3. Each one has a note on how the user would pick
  the stop.
- **Phase 2 is just "open the app".** `ShowNearbyBusesIntent` has no parameters. The app already
  shows the stops near the user, so opening it is already useful.

## Findings from the current code (still true)

| # | Finding | Consequence for intents |
|---|---------|-------------------------|
| F1 | `ViewModel` was a private property of the `App` struct. | Fixed in Phase 1: it's registered with `AppDependencyManager`. |
| F2 | `selectedStop` / `selectedBus` are `@State` in `ContentView`. | An intent can't navigate to a stop yet. Only needed by stop intents (Phase 3). |
| F3 | Arrivals are computed only for stops within `maxDistance` of the user. | A stop far away would show an empty list. Add `ViewModel.buses(at:)` when an intent first needs it. |
| F4 | Stop loading and the feed download are fire-and-forget `Task`s in `ViewModel.init`. | A background intent can't `await` readiness. Add `ensureStopsLoaded()` / `ensureFreshFeed(maxAge:)` with the first background intent. |
| F5 | Stop names are not unique and use GTFS abbreviations. | Name search is a poor way to choose a stop. See "How would a user choose a stop?" below. |
| F6 | The `stop_id` is the 6-digit stop code printed on the bus stop sign. | Typing the code from the sign is a reliable way to pick a stop. |
| F7 | The `tripUpdates` feed covers the whole city and is large. | A background "next bus" answer may be slow. Measure it, or use SIRI StopMonitoring per stop. |
| F8 | There are no favorites. | Without them, parameterized Siri phrases have nothing to list. |
| F9 | MTAFeed types are not `Sendable`. | Map them into small `Sendable` structs before returning them from intents. |
| F10 | `routes.txt` is bundled but not read. | Riders know route names (M15, B44, Q58), so routes are a good parameter. |

## Phase 1: Base setup (done)

Goal: make each new intent a small, local change.

- **Folder.** `NYCBusNearby/AppIntents/` is a group in the Xcode project. The project does **not**
  use synchronized folders, so add each new file to the `NYCBusNearby` target (Xcode's "Add Files",
  or a `project.pbxproj` entry).
- **Dependency.** `NYCBusNearbyApp.init` creates the `ViewModel` and registers it:
  `AppDependencyManager.shared.add(dependency: viewModel)`. An intent reads it with
  `@Dependency private var viewModel: ViewModel`, and marks `perform()` `@MainActor`.
  The intent and the UI share the same instance, so they share downloaded data.
- **One shortcuts provider.** `AppIntents/NYCBusShortcuts.swift` (`AppShortcutsProvider`) lists
  every App Shortcut and its Siri phrases. The app can declare at most 10.
- **Open vs. background.** Use `static let supportedModes: IntentModes = .foreground` for intents
  that open the app, and `.background` for intents that answer without opening it (iOS 26 API; it
  replaces `openAppWhenRun`). In Swift 6 mode, declare the static members with `let`.

### How to add an intent

1. Create `AppIntents/<Name>Intent.swift` with a struct that conforms to `AppIntent`: a `title`, a
   `description`, `supportedModes`, and `perform()`.
2. Add the file to the `NYCBusNearby` target.
3. To make it a Siri phrase / Spotlight / Action-button shortcut, add an `AppShortcut` to
   `NYCBusShortcuts`. Every phrase must contain `\(.applicationName)`. Without this step the intent
   still appears in the Shortcuts app as an action.
4. Build. Mistakes in phrases or metadata show up as build errors from the App Intents metadata
   processor. Check `NYCBusNearby.app/Metadata.appintents/extract.actionsdata` to see what was
   extracted.
5. Add the `ViewModel` helpers the intent needs (F2–F4). Don't add them before an intent uses them.

## Phase 2: "Show Nearby Buses" (done)

`AppIntents/ShowNearbyBusesIntent.swift`:
- No parameters. `supportedModes = .foreground`. `perform()` returns `.result()`. Opening the app is
  the whole job.
- On a cold launch, `ViewModel.init` gets the location and downloads the feeds as usual. If the app
  was already running, it shows what it had, and the user taps Refresh after 60 seconds as usual.
- Phrases (`NYCBusShortcuts`): "Show nearby buses in …", "Show buses near me in …",
  "Find bus stops near me in …". Short title "Nearby Buses", symbol `bus`.
  "Open NYC Buses Near Me" works without any code, because Siri opens apps by name.
- Where it shows up: Siri, the Shortcuts app (both as an App Shortcut and as an action), Spotlight,
  and the Action button (Settings > Action Button > Shortcut).

Possible follow-ups, if they turn out to be useful:
- Refresh on open when the data is older than 60 s. This needs F4 (`ensureFreshFeed`) plus a way to
  tell `ContentView` to recompute (`feedAvailable` is already observed).
- Pop back to the stop list (clear `selectedStop`). This needs F2.
- `INAlternativeAppNames` (e.g. "NYC Bus", "Bus Nearby"), so Siri recognizes shorter names.

### Testing (manual, no test target)
- Shortcuts app: "Nearby Buses" appears under the app's shortcuts, and the action "Show Nearby
  Buses" runs and opens the app.
- On a device: say each phrase with the app killed and with it in the background.
- Spotlight: search "Nearby Buses".
- Action button: assign the shortcut and press it.

## Phase 3: Next use cases (to decide)

### How would a user choose a stop?

This decides which stop-based intents are worth building:

| Way | How it works | Cost |
|-----|--------------|------|
| **Nearest stop** | No choice: use the stop closest to the user. | Needs a location fix. A background intent may not get one with "When In Use" permission. Test on a device. |
| **Favorites** | The user stars a stop in the app. Shortcuts and Siri list only favorites. | Favorites UI + storage (F8). It's the most natural option. |
| **This stop** | While a stop is on screen, Siri / Apple Intelligence can refer to "this stop" (`NSUserActivity` + `appEntityIdentifier`). | Small, but depends on what Siri supports in the current iOS. |
| **Stop code** | The 6-digit code printed on the sign (F6), typed in Shortcuts. | Easy, but only useful while standing at the stop. |
| **Name search** | Type part of the name. | Duplicate and abbreviated names (F5). Only as a fallback inside the Shortcuts picker. |

### Candidates

Ordered by value for effort. Each one needs the user's decision.

1. **Service alerts for a route** (`GetServiceAlertsIntent`, background). Parameter: a
   `BusRouteEntity` from `routes.txt` (F10). Riders know route names, so there's no stop-name
   problem. Returns alert entities and a dialog read from `plainHeaderText` /
   `plainDescriptionText` (never the raw HTML). Needs F4 and F9. About 1 day.
2. **Next buses at the nearest stop** (background). No parameter. "When is the next bus near me?"
   Needs F3, F4, and F9, a location fix in the background (risk), and a feed-time measurement (F7).
   About 2 days.
3. **Favorites, then "Open favorite stop" and "Next buses at favorite stop"**. Needs F2, F3, and
   F8, a `BusStopEntity` whose `suggestedEntities()` returns the favorites, and
   `updateAppShortcutParameters()` when favorites change. About 3 days. This also unlocks
   Spotlight indexing (`IndexedEntity`) and future widgets/controls.
4. **Return values for Shortcuts "Use Model"**. Once 1–3 return entities with clearly titled
   properties (route, headsign, minutesAway, isCanceled), users can chain them into Apple
   Intelligence's Use Model action. This needs no extra code.
5. **Onscreen "this stop"** (`.userActivity` with `appEntityIdentifier` in `BusesAtStopView`).
   Needs `BusStopEntity`.

Not recommended for now:
- Assistant schemas (`@AppIntent(schema:)`). There is no transit domain.
- Visual Intelligence stop-sign matching. Niche.

Design notes for these candidates (from the first draft):
- `BusStopEntity`: `id` = stop code. Subtitle "Stop #401234", plus distance and routes once
  `update_gtfs.py` emits `stop_routes.txt`.
- `BusArrival` return values: `Sendable` structs / `TransientAppEntity` with `@Property` route,
  headsign, minutesAway, arrivalTime, isCanceled. Say "canceled" in dialogs, don't hide those trips.
- Errors: a custom `Error` with a `CustomLocalizedStringResourceConvertible` message ("Can't reach
  the MTA feed right now").
- Per-stop data: the MTA SIRI StopMonitoring API (`/api/siri/stop-monitoring.json?MonitoringRef=…`,
  same key) returns a few KB instead of the city-wide feed. Its endpoint, shape, and rate limits
  are unverified.

## Phase 4 (later): Widgets, Controls, Live Activities

- A Control Center / Lock Screen control can run `ShowNearbyBusesIntent` today. It needs a widget
  extension.
- A "next buses at favorite stop" widget needs an **App Group** (the Core Data store and favorites
  moved to the group container), and probably the per-stop API.
- At that point, move the intents into a local Swift package (e.g. `NYCBusIntents`) and declare
  `AppIntentsPackage` in both the app and the extension.

## Decisions for you

- Which Phase 3 candidates do you want, and in what order? Recommended: 1 (route alerts), then 3
  (favorites).
- Is a background location fix acceptable to test for candidate 2, or should "near me" intents
  always open the app?

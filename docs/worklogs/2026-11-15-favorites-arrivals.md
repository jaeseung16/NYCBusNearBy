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

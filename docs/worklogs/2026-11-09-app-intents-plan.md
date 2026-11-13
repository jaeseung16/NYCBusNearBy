# 2026-11-09 — App Intents investigation and plan

## Investigation
- Read `NYCBusNearbyApp`, `ViewModel`, `ContentView`, the models, `Resources/stops.txt`, and the MTAFeed `BusFeedURL`.
- Blockers for intents:
  - The `ViewModel` can't be reached outside the view tree.
  - Selection is `@State` in `ContentView`.
  - Arrivals are computed only for stops near the user.
  - Stop and feed readiness can't be awaited.
- Data facts:
  - 3,485 of 13,465 stop names are duplicated, so search results need a disambiguating subtitle.
  - `stop_id` is the stop code printed on the sign.
  - The `tripUpdates` feed covers the whole city, so a background "next bus" request may be slow.
- No favorites exist yet. Siri phrases with a parameter need a small set of suggested entities.

## Output
- Wrote `docs/plans/app-intents.md`:
  - Phase 0: refactors (`AppDependencyManager`, awaitable readiness, `buses(at:)`, navigation, favorites).
  - Phase 1: `BusStopEntity`/query, `OpenBusStopIntent`, App Shortcuts.
  - Phase 2: background `GetNextBusesIntent` and `GetServiceAlertsIntent`, and `BusRouteEntity` from `routes.txt`.
  - Phase 3: Apple Intelligence tiers (Shortcuts Use Model, Spotlight `IndexedEntity`, onscreen entity, Siri in-app actions, schemas, Visual Intelligence).
  - Phase 4: widgets/controls prerequisites.
  - A testing checklist, and the decisions the user needs to make.
- No code changes.

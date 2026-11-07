# 2026-11-07 — Service alerts and canceled trips (plan item 3)

## Task
Committed item 2 as `dbf850f` ("feat: Refresh static bus data from current GTFS with a version gate").
Then did item 3 from `2026-11-03-mta-developer-data-review.md`: mark CANCELED trips, show route alerts
on the stop and bus views, and strip HTML from alert text.

## Live feed check (Sat 2026-11-07, ~09:00 ET, via a Swift probe against MTAFeed 0.3.0)
- tripUpdates: 3,458 trips, and `scheduleRelationship` is unset on all of them (no cancellations flagged).
- alerts: 93 total, 89 active. `effect` and `cause` are unset on all of them. All 93 are
  route-only: no trip IDs or stop IDs. Median 1 route per alert, max 9.
- Header text contains `&#x200c;`. Each description repeats the header, then HTML (`<p>`, `<strong>`,
  `<br>`, `<ul><li>`, `<a href=...png>`).
- So route matching does all the work, and effect-based filtering is not possible yet.

## Changes
- `Model/MTAAlertText.swift` (new): `MTAAlert.plainHeaderText` and `plainDescriptionText`, built on
  `AlertText.plain(_:)`:
  - `<br>`, `</p>`, `</li>`, and similar become newlines; `<li>` becomes "• "; other tags are dropped.
  - Numeric and common named entities are decoded.
  - Zero-width characters and NBSP are filtered at the Unicode-scalar level. U+200C/U+200D are
    grapheme extenders, so a Character-level regex silently missed them (first attempt, caught by
    hex dump).
  - Blank-line runs are collapsed, and the header line repeated in the description is dropped.
- `Views/ServiceAlertsView.swift` (new): `ServiceAlertsButton` (orange "N service alerts", hidden when
  there are none) opens `ServiceAlertsView`, a sheet listing route IDs, header, and description.
- `ViewModel.swift`:
  - `alertedRouteIds` is recomputed after each download and cleared in `resetData()`.
  - `activeAlerts(routeIds:tripId:at:)` returns the active alerts that name one of the routes or the trip.
- `MTABus.isCanceled` (from `MTATrip.isCanceled`).
- `BusAtStopView`: an orange warning icon next to routes with an active alert. A canceled bus shows
  a red "Canceled" with its time struck through, instead of the countdown.
- `BusesAtStopView`: an alerts button under the stop name, for the routes of the buses shown.
- `BusTripUpdateView`: a "This trip is canceled" label and an alerts button for the bus's route and trip.
- `project.pbxproj`: added the two new files. `CLAUDE.md`: added an "Alerts and cancellations" paragraph.

## Verification
- iOS Simulator Debug build succeeded.
- Ran `AlertText` on all 93 live alerts: no tags, entities, or zero-width/NBSP scalars remain. No
  description starts with its header anymore. Spot-checked M101, Bx21, and X28/X38 output by eye.
- Not verified on screen: the alert button and sheet, and the canceled row. No live trip was canceled
  to exercise the canceled row, and the split view needs taps to reach the stop and bus columns.

## Notes / limits
- Stop-view alerts cover only routes with a bus arriving in the current window, because the app has no
  stop-to-routes table. Adding one (from GTFS stop_times) to `update_gtfs.py` would fix that.
- Canceled trips with no stop time updates never match a stop, so they still don't appear. Showing
  them would need scheduled times from static GTFS.
- "What?s happening?" in some alerts is a literal `?` in MTA's text, not a decoding bug.
- Not committed.

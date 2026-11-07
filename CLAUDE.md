# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Single Xcode project, one target (`NYCBusNearby`), one shared scheme. There is no test target and no linter configured.

```bash
# Build for the iOS Simulator (verified; CODE_SIGNING_ALLOWED=NO avoids needing a signing identity)
xcodebuild -project NYCBusNearby.xcodeproj -scheme NYCBusNearby \
  -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build

# Resolve SPM packages / list schemes
xcodebuild -list -project NYCBusNearby.xcodeproj
```

Run the app from Xcode (Cmd+R). The app needs a location to show anything, so use the simulator's Features > Location menu or a custom GPX location. Live bus data comes from the MTA feeds over the network.

## Dependencies

Swift Package Manager only (no CocoaPods/Carthage). Resolved in `NYCBusNearby.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`:
- `MTAFeed` (jaeseung16/MTAFeed-Swift, tracks `main`): `MTAFeedDownloader`, `BusFeedURL`, `MTAFeedWrapper`, `MTAVehicle`, `MTATripUpdate`, `MTAAlert`. Its types are not in this repo, so look in the package source when changing feed handling.
- `Persistence` (PersistenceSwift), `CodableCSV`, `GoogleMobileAds` (+ UMP), and `SwiftProtobuf`, which the app target links directly.

Swift 6.0 language mode, iOS 26.0 deployment target. Views use iOS 26 APIs such as `glassEffect()` and `GlassEffectContainer`.

## Architecture

**App wiring.** `NYCBusNearbyApp` creates one `ViewModel` and injects it as an `@EnvironmentObject` into `ContentView`. `ViewModel` is `@MainActor` and owns nearly all state: static bus stops, route headsigns, live feed data, and location. It also starts the ATT/AdMob setup in the app's `init`.

**Data sources.** There are two, and they are loaded differently:
1. *Static reference data.* Bus stops live in Core Data (`NYCBusNearby.xcdatamodeld`, entity `MTABusStopEntity`; current model version `NYCBusNearby 2`, and the old `NYCBusTrips` version is kept so existing stores migrate automatically). `Resources/stops.txt` is imported into the store whenever `Resources/gtfs_version.txt` differs from the `stopsDataVersion` UserDefaults value. The import is one background `NSBatchDeleteRequest` plus `NSBatchInsertRequest` in `ViewModel.populateBusStops()`. Stops load asynchronously, and `ViewModel.stopsLoaded` tells `ContentView` to recompute the nearby stops. No seed sqlite is bundled.
   Headsigns are not stored per trip, because GTFS-RT trip IDs change with every schedule. `Resources/route_headsigns.txt` (route_id, direction_id, most common trip_headsign) is read from the bundle at every launch. `ViewModel.headsign(for:)` falls back to the trip update's last stop name.
   To refresh the static data (MTA publishes new bus GTFS quarterly), run `scripts/update_gtfs.py --download <dir>`. It regenerates `stops.txt`, `routes.txt`, `route_headsigns.txt`, and `gtfs_version.txt` from the six bus GTFS zips. The new version string makes installed apps re-import on their next launch. `routes.txt` is bundled but not read by the app yet.
2. *Live data* comes from the MTA real-time feeds. `getAllDataAsync()` downloads every `BusFeedURL` case in parallel through a `TaskGroup`, then fills `tripUpdatesByTripId`, `vehiclesByStopId`, and `alerts`. It runs at launch and when the user taps Refresh.

**Joining live data to stops.** `ViewModel.buses(within:from:)` is the core logic. It takes the stops within a radius, walks all trip updates, and matches each `stopTimeUpdate.stopId` against those stops. MTA stop IDs carry a direction suffix (`N`/`S`), which is stripped before the lookup in `stopsById`. Results are grouped as `[MTABusStop: [MTABus]]`. Arrival times are filtered with `isValid` (`maxAgo` to `maxComing`).

**Alerts and cancellations.** Bus alerts name routes (rarely trips) through `MTAAlert.informedEntities`. `ViewModel.activeAlerts(routeIds:tripId:)` filters them by `isActive()`, and `alertedRouteIds` is recomputed after each download. Alert text is HTML with entities such as `&#x200c;`. Always display `plainHeaderText` and `plainDescriptionText` (`Model/MTAAlertText.swift`), not the raw fields; the description also drops the header that it repeats. `ServiceAlertsButton` (`Views/ServiceAlertsView.swift`) shows the alerts in a sheet in `BusesAtStopView` and `BusTripUpdateView`. A trip whose `schedule_relationship` is CANCELED is shown as canceled (`MTABus.isCanceled`) rather than hidden.

**UI flow.** `ContentView` is a three-column `NavigationSplitView`:
- sidebar: `stopsNearby` (`BusStopRowView`), sorted by distance
- content: `BusesAtStopView` for the selected stop
- detail: `BusTripUpdateView` for the selected bus, showing its remaining stops and ETAs

Selecting a stop or bus is tracked with `selectedStop` and `selectedBus` `@State`. Helper methods on `ContentView` (`getSortedBuses`, `getTripUpdates`) turn the view model's data into what each column shows.

**Refresh and settings.** `ContentView` polls every 10 seconds with a `Timer` publisher. After 60 seconds (`refreshThreshold`) it enables the Refresh button, and the progress ring counts down until then. User settings (`maxDistance`, `maxComing`, `distanceUnit`) are stored with `@AppStorage` in `ContentView`, and `ViewModel` reads the same UserDefaults keys at init. Changes are pushed to the view model through `onChange` and when the settings sheet is dismissed. Setting `maxDistance` on the view model also recomputes the map `region`.

**Location.** `LocationHelper` wraps `CLLocationManager`. It forwards location updates to `ViewModel` (via `CLLocationManagerDelegate`) and does reverse geocoding with `MKReverseGeocodingRequest` for the locality label.

**Ads.** `AdMob/BannerAd.swift` wraps a `BannerAdViewController` in a `UIViewControllerRepresentable`. It is shown only on iOS (`#if os(iOS)`) at the bottom of the sidebar.

## Other notes

- Documentation lives in `docs/`. Worklog entries go in `docs/worklogs/`, named `YYYY-MM-DD-<topic>.md`.
- `README.md` describes the app as showing subway stations. It is a bus app; the README copy is out of date.

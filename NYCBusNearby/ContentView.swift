//
//  ContentView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    @EnvironmentObject private var viewModel: ViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var adsStarter = AdsStarter()
    @AppStorage("maxDistance") private var maxDistance = 1000.0
    @AppStorage("distanceUnit") private var distanceUnit = DistanceUnit.mile
    @AppStorage("maxComing") private var maxComing: TimeInterval = 30 * 60
    @AppStorage("showFavoritesOnly") private var showFavoritesOnly = false
    
    private let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(width: .abbreviated,
                                                                          usage: .asProvided,
                                                                          numberFormatStyle: .number.precision(.fractionLength(1)))
    
    
    @State private var location = CLLocationCoordinate2D(latitude: 40.712778, longitude: -74.006111) // NYC City Hall
    
    @State private var userLocality = "Unknown"
    @State private var stopsNearby = [MTABusStop]()
    @State private var busesByStop = [MTABusStop: [MTABus]]()
    @State private var lastRefresh = Date()
    
    @State private var presentAlertNotInNYC = false
    @State private var presentedAlertNotInNYC = false
    @State private var presentSettings = false
    @State private var presentAlertLocationUnkown = false
    @State private var presentAlertFeedUnavailable = false
    @State private var timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    @State private var refreshable = false
    
    @State private var showProgress = false
    
    @State private var selectedStop: MTABusStop?
    @State private var selectedBus: MTABus?
    
    @State private var editMode = EditMode.inactive
    @State private var renamingFavorite: FavoriteStop?
    @State private var nicknameDraft = ""
    
    private let refreshThreshold: TimeInterval = 60
    
    private var interval: ClosedRange<Date> {
        let start = lastRefresh
        let end = lastRefresh.addingTimeInterval(refreshThreshold)
        return start...end
    }
    
    var body: some View {
        VStack {
            NavigationSplitView {
                VStack {
                    sidebarHeader
                    
                    ZStack {
                        if showFavoritesOnly {
                            favoritesList
                        } else {
                            nearbyList
                        }
                        
                        bottomView
                    }
                    
                    Spacer()
                    
#if os(iOS)
                    if adsStarter.adsStarted {
                        BannerAd()
                            .frame(height: 50)
                    } else {
                        Color.clear
                            .frame(height: 50)
                    }
#endif
                }
            } content: {
                if let stop = selectedStop {
                    if let buses = getSortedBuses(at: stop) {
                        BusesAtStopView(stop: stop, buses: buses, selectedBus: $selectedBus)
                    } else {
                        BusesAtStopView(stop: stop, buses: [], selectedBus: $selectedBus)
                    }
                }
            } detail: {
                if let stop = selectedStop, let bus = selectedBus, let tripUpdate = getTripUpdates(for: bus, near: stop) {
                    BusTripUpdateView(bus: bus, tripUpdate: tripUpdate, stop: stop)
                } else {
                    EmptyView()
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .padding()
        .overlay {
            ProgressView("Please wait...")
                .progressViewStyle(.circular)
                .opacity(showProgress ? 1 : 0)
        }
        .sheet(isPresented: $presentSettings) {
            SettingsView(distanceUnit: $distanceUnit, distance: $maxDistance, maxComing: $maxComing)
        }
        .onReceive(viewModel.$feedAvailable) { _ in
            if viewModel.feedAvailable {
                updateStopsAndTrainsNearby()
            }
        }
        .onReceive(viewModel.$userLocalityUpdated) { _ in
            userLocality = viewModel.userLocality
        }
        .onReceive(viewModel.$locationUpdated) { _ in
            updateStopsAndTrainsNearby()
        }
        .onReceive(viewModel.$stopsLoaded) { _ in
            updateStopsAndTrainsNearby()
            showRequestedStop()
        }
        .onChange(of: viewModel.requestedStopId, initial: true) { _, _ in
            showRequestedStop()
        }
        .onChange(of: viewModel.favoriteStops) { _, _ in
            // onChange, not onReceive: @Published sends before the new value is stored.
            updateStopsAndTrainsNearby()
        }
        .onChange(of: showFavoritesOnly) { _, newValue in
            if !newValue {
                editMode = .inactive
            }
            clearSelectionIfHidden()
        }
        .onReceive(timer) { _ in
            if !refreshable && lastRefresh.distance(to: Date()) > refreshThreshold {
                withAnimation {
                    refreshable = true
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .active {
                Task {
                    await adsStarter.appDidBecomeActive()
                }
            }
        }
        .onChange(of: maxComing) { _, newValue in
            viewModel.maxComing = newValue
        }
        .onChange(of: presentSettings) { _, _ in
            if viewModel.maxDistance != maxDistance {
                viewModel.maxDistance = maxDistance
                updateStopsAndTrainsNearby()
            }
        }
        .alert(Text("There are no nearby bus stops"), isPresented: $presentAlertNotInNYC) {
            Button("OK") {
                presentedAlertNotInNYC = true
            }
        }
        .alert(Text("Can't determine your current location"), isPresented: $presentAlertLocationUnkown) {
            Button("OK") {
                
            }
        }
        .alert(Text("Can't access MTA feed"), isPresented: $presentAlertFeedUnavailable) {
            Button("OK") {
                
            }
        }
        .alert("Rename Favorite", isPresented: isRenaming, presenting: renamingFavorite) { favorite in
            TextField(favorite.name, text: $nicknameDraft)
            Button("Save") {
                viewModel.renameFavorite(id: favorite.id, nickname: nicknameDraft)
            }
            Button("Cancel", role: .cancel) { }
        } message: { favorite in
            Text("Leave blank to use \(favorite.name).")
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarHeader: some View {
        HStack {
            locationLabel
            
            Spacer()
            
            if showFavoritesOnly && !viewModel.favoriteStops.isEmpty {
                EditButton()
            }
            
            Toggle(isOn: $showFavoritesOnly.animation()) {
                Label("Favorites", systemImage: showFavoritesOnly ? "star.fill" : "star")
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .accessibilityLabel("Show Favorites Only")
        }
        .environment(\.editMode, $editMode)
    }
    
    /// Stops near the user, sorted by distance.
    private var nearbyList: some View {
        List(selection: $selectedStop) {
            ForEach(stopsNearby, id: \.self) { stop in
                let favorite = viewModel.favorite(forStopId: stop.id)
                NavigationLink(value: stop) {
                    BusStopRowView(title: favorite?.displayName ?? stop.name,
                                   stopId: stop.id,
                                   distance: distance(to: stop),
                                   distanceUnit: distanceUnit,
                                   isFavorite: favorite != nil)
                }
                .swipeActions(edge: .leading) {
                    favoriteToggleButton(for: stop.id, stop: stop)
                }
                .contextMenu {
                    favoriteMenuItems(for: stop.id, stop: stop)
                }
            }
        }
    }
    
    /// All favorites, wherever they are, in the user's order.
    @ViewBuilder
    private var favoritesList: some View {
        if viewModel.favoriteStops.isEmpty {
            ContentUnavailableView("No Favorites", systemImage: "star",
                                   description: Text("Tap \(Image(systemName: "star")) on a stop to add it."))
        } else {
            List(selection: $selectedStop) {
                ForEach(viewModel.favoriteStops) { favorite in
                    favoriteRow(favorite)
                        .swipeActions(edge: .leading) {
                            favoriteToggleButton(for: favorite.id, stop: viewModel.stopsById[favorite.id])
                        }
                        .contextMenu {
                            favoriteMenuItems(for: favorite.id, stop: viewModel.stopsById[favorite.id])
                        }
                }
                .onMove { source, destination in
                    viewModel.moveFavorites(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    let ids = offsets.map { viewModel.favoriteStops[$0].id }
                    ids.forEach { viewModel.removeFavorite(id: $0) }
                }
            }
            .environment(\.editMode, $editMode)
        }
    }
    
    @ViewBuilder
    private func favoriteRow(_ favorite: FavoriteStop) -> some View {
        if let stop = viewModel.stopsById[favorite.id] {
            NavigationLink(value: stop) {
                BusStopRowView(title: favorite.displayName,
                               stopId: favorite.id,
                               distance: distance(to: stop),
                               distanceUnit: distanceUnit,
                               isFavorite: true)
            }
        } else {
            // Not selectable: either the stop is gone from the GTFS data, or the stops haven't loaded yet.
            BusStopRowView(title: favorite.displayName,
                           stopId: favorite.id,
                           distance: nil,
                           distanceUnit: distanceUnit,
                           isFavorite: true,
                           isUnavailable: viewModel.missingFavoriteIds.contains(favorite.id))
        }
    }
    
    /// "Add to Favorites" or "Remove from Favorites". `stop` is `nil` for a favorite whose stop is gone.
    @ViewBuilder
    private func favoriteToggleButton(for stopId: String, stop: MTABusStop?) -> some View {
        if viewModel.favorite(forStopId: stopId) != nil {
            Button {
                viewModel.removeFavorite(id: stopId)
            } label: {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
            .tint(.yellow)
        } else if let stop {
            Button {
                viewModel.addFavorite(stop)
            } label: {
                Label("Add to Favorites", systemImage: "star")
            }
            .tint(.yellow)
        }
    }
    
    @ViewBuilder
    private func favoriteMenuItems(for stopId: String, stop: MTABusStop?) -> some View {
        favoriteToggleButton(for: stopId, stop: stop)
        if let favorite = viewModel.favorite(forStopId: stopId) {
            Button {
                nicknameDraft = favorite.nickname ?? ""
                renamingFavorite = favorite
            } label: {
                Label("Rename…", systemImage: "pencil")
            }
        }
    }
    
    private var isRenaming: Binding<Bool> {
        Binding {
            renamingFavorite != nil
        } set: { isPresented in
            if !isPresented {
                renamingFavorite = nil
            }
        }
    }
    
    /// Selects the stop an App Intent asked for. After a cold launch, waits for the stops to load.
    private func showRequestedStop() {
        guard let stopId = viewModel.requestedStopId else { return }
        guard let stop = viewModel.stopsById[stopId] else {
            if !viewModel.mtaStops.isEmpty {
                // The stops are loaded and this one isn't there.
                viewModel.requestedStopId = nil
            }
            return
        }
        viewModel.requestedStopId = nil
        if showFavoritesOnly && !viewModel.isFavorite(stop) {
            showFavoritesOnly = false
        }
        selectedBus = nil
        selectedStop = stop
        updateStopsAndTrainsNearby()
    }
    
    /// After the filter changes, clears the selection if the selected stop isn't in the list being shown.
    /// Not called when favorites change, so unstarring the stop being viewed doesn't close it.
    private func clearSelectionIfHidden() {
        guard let stop = selectedStop else { return }
        let isShown = showFavoritesOnly ? viewModel.isFavorite(stop) : stopsNearby.contains(stop)
        if !isShown {
            selectedStop = nil
            selectedBus = nil
        }
    }
    
    private var locationLabel: some View {
        if !userLocality.isEmpty && userLocality != "Unknown" {
            return Label(userLocality, systemImage: "mappin.and.ellipse")
        } else {
            return Label("Nearby Bus Stops", systemImage: "bus")
        }
    }
    
    /// `nil` until there's a location fix.
    private func distance(to stop: MTABusStop) -> Measurement<UnitLength>? {
        guard viewModel.location != nil else { return nil }
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let stopLocation = stop.getCLLocation()
        return Measurement(value: stopLocation.distance(from: clLocation), unit: UnitLength.meters)
    }
    
    private func updateStopsAndTrainsNearby() -> Void {
        // Stops load in the background; don't conclude "not in NYC" before they arrive.
        if let coordinate = viewModel.location?.coordinate, !viewModel.mtaStops.isEmpty {
            location = coordinate
            stopsNearby = viewModel.stops(within: maxDistance, from: location)
            
            if stopsNearby.isEmpty && viewModel.favoriteStops.isEmpty {
                presentAlertNotInNYC = !presentedAlertNotInNYC
            } else if presentedAlertNotInNYC {
                presentedAlertNotInNYC = false
            }
        }
        
        // Favorites get arrivals wherever they are, with or without a location fix.
        // Without a fix, the last nearby stops are kept, as before.
        // The selected stop may be neither, when an App Intent opened it.
        busesByStop = viewModel.buses(at: stopsNearby + viewModel.favoriteMTABusStops + [selectedStop].compactMap { $0 })
    }
    
    private func getBuses(at stop: MTABusStop) -> [MTABus]? {
        return busesByStop[stop]?.filter { $0.eventTime != nil  && viewModel.isValid($0.eventTime!)}
    }
    
    private func getSortedBuses(at stop: MTABusStop) -> [MTABus]? {
        guard let buses = getBuses(at: stop), !buses.isEmpty else {
            return nil
        }
        
        return buses.sorted(by: { $0.eventTime! < $1.eventTime! })
    }
    
    private func getTripUpdates(for bus: MTABus, near stop: MTABusStop) -> MTABusTripUpdate? {
        guard let buses = getBuses(at: stop), !buses.isEmpty else {
            return nil
        }
            
        guard let tripId = bus.tripId else {
            return nil
        }
          
        return viewModel.getTripUpdateByTripId(from: buses)[tripId]
    }
    
    private var bottomView: some View {
        VStack {
            Spacer()
            
            GlassEffectContainer {
                HStack {
                    Spacer()
                    
                    Button {
                        presentSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .padding(5.0)
                    .frame(width: 120.0)
                    .glassEffect()
                    
                    Spacer()

                    if refreshable {
                        Button {
                            downloadAllDataByButton()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise.circle")
                        }
                        .padding(5.0)
                        .frame(width: 120.0)
                        .glassEffect()
                    } else {
                        ProgressView(timerInterval: interval, countsDown: true)
                            .progressViewStyle(.linear)
                            .padding(5.0)
                            .frame(width: 120.0)
                            .glassEffect()
                    }
                    
                    Spacer()
                }
                .disabled(showProgress)
            }
        }
    }
    
    private func downloadAllDataByButton() -> Void {
        refreshable = false
        if !showProgress {
            showProgress = true
            downloadAllData()
        }
    }
    
    private func downloadAllData() -> Void {
        lastRefresh = Date()
        if viewModel.location?.coordinate != nil {
            Task {
                let result = await viewModel.getAllDataAsync()
                presentAlertFeedUnavailable = !result
                showProgress = false
                updateStopsAndTrainsNearby()
            }
        } else if showProgress {
            presentAlertLocationUnkown.toggle()
            showProgress = false
        }
    }
}

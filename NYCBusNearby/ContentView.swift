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
    
    private var kmSelected: Bool {
        distanceUnit == .km
    }
    
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
                    locationLabel
                    
                    ZStack {
                        if !busesByStop.isEmpty {
                            List(stopsNearby, id: \.self, selection: $selectedStop) { stop in
                                NavigationLink(value: stop) {
                                    if kmSelected {
                                        BusStopRowView(stop: stop, distance: distance(to: stop), distanceUnit: .km)
                                    } else {
                                        BusStopRowView(stop: stop, distance: distance(to: stop), distanceUnit: .mile)
                                    }
                                }
                            }
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
        }
        .onChange(of: viewModel.favoriteStops) { _, _ in
            // onChange, not onReceive: @Published sends before the new value is stored.
            updateStopsAndTrainsNearby()
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
    }
    
    private var locationLabel: some View {
        if !userLocality.isEmpty && userLocality != "Unknown" {
            return Label(userLocality, systemImage: "mappin.and.ellipse")
        } else {
            return Label("Nearby Bus Stops", systemImage: "bus")
        }
    }
    
    private func distance(to stop: MTABusStop) -> Measurement<UnitLength> {
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
        busesByStop = viewModel.buses(at: stopsNearby + viewModel.favoriteMTABusStops)
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

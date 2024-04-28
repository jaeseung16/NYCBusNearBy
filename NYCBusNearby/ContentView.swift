//
//  ContentView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: ViewModel
    @AppStorage("maxDistance") private var maxDistance = 1000.0
    @AppStorage("distanceUnit") private var distanceUnit = DistanceUnit.mile
    @AppStorage("maxComing") private var maxComing: TimeInterval = 30 * 60
    
    private let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(width: .abbreviated,
                                                                          usage: .asProvided,
                                                                          numberFormatStyle: .number.precision(.fractionLength(1)))
    
    
    @State private var location = CLLocationCoordinate2D(latitude: 40.712778, longitude: -74.006111) // NYC City Hall
    
    @State private var userLocality = "Unknown"
    @State private var stopsNearby = [MTABusStop]()
    @State private var busesNearby = [MTABusStop: [MTABus]]()
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
    
    var body: some View {
        VStack {
            locationLabel
            
            if !busesNearby.isEmpty {
                NavigationSplitView {
                    List(stopsNearby, id: \.self, selection: $selectedStop) { stop in
                        NavigationLink(value: stop) {
                            if kmSelected {
                                BusStopRowView(stop: stop, distance: distance(to: stop), distanceUnit: .km)
                            } else {
                                BusStopRowView(stop: stop, distance: distance(to: stop), distanceUnit: .mile)
                            }
                        }
                    }
                } content: {
                    if let stop = selectedStop, let buses = getSortedBuses(at: stop) {
                        BusesAtStopView(stop: stop, buses: buses, selectedBus: $selectedBus)
                        .navigationTitle(stop.name)
                    }
                } detail: {
                    if let bus = selectedBus, let tripUpdate = getTripUpdates(for: bus) {
                        BusTripUpdateView(tripUpdate: tripUpdate)
                            .navigationTitle(bus.routeId ?? "")
                    } else {
                        EmptyView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
            
            Spacer()
            
            bottomView
            
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
        .onReceive(timer) { _ in
            refreshable = lastRefresh.distance(to: Date()) > 60
        }
        .onChange(of: maxComing) { newValue in
            viewModel.maxComing = newValue
        }
        .onChange(of: presentSettings) { _ in
            if viewModel.maxDistance != maxDistance {
                viewModel.maxDistance = maxDistance
                updateStopsAndTrainsNearby()
            }
        }
        .alert(Text("There are no nearby subway stations"), isPresented: $presentAlertNotInNYC) {
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
        if let coordinate = viewModel.location?.coordinate {
            location = coordinate
            stopsNearby = viewModel.stops(within: maxDistance, from: location)
            busesNearby = viewModel.buses(within: maxDistance, from: location)
            
            if stopsNearby.isEmpty {
                presentAlertNotInNYC = !presentedAlertNotInNYC
            } else if presentedAlertNotInNYC {
                presentedAlertNotInNYC = false
            }
        }
    }
    
    private func getBuses(at stop: MTABusStop) -> [MTABus]? {
        return busesNearby[stop]?.filter { $0.eventTime != nil  && viewModel.isValid($0.eventTime!)}
    }
    
    private func getSortedBuses(at stop: MTABusStop) -> [MTABus]? {
        guard let buses = getBuses(at: stop), !buses.isEmpty else {
            return nil
        }
        
        return getSortedBuses(from: buses)
    }
    
    private func getSortedBuses(from buses: [MTABus]) -> [MTABus] {
        return buses.sorted(by: { $0.eventTime! < $1.eventTime! })
    }
    
    private func getTripUpdates(for bus: MTABus) -> MTABusTripUpdate? {
        guard let stop = selectedStop else {
            return nil
        }
        
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
            HStack {
                Spacer()
                
                Button {
                    presentSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                
                Spacer()

                Button {
                    downloadAllDataByButton()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise.circle")
                }
                .disabled(!refreshable)
                
                Spacer()
            }
            .disabled(showProgress)
            
            HStack {
                Spacer()
                Text("Refreshed:")
                Text(lastRefresh, style: .time)
            }
            
            #if os(iOS)
            BannerAd()
                .frame(height: 50)
            #endif
            
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
            viewModel.getAllData() { result in
                switch result {
                case .success(let success):
                    presentAlertFeedUnavailable = !success
                case .failure:
                    presentAlertFeedUnavailable.toggle()
                }
                showProgress = false
                updateStopsAndTrainsNearby()
            }
        } else if showProgress {
            presentAlertLocationUnkown.toggle()
            showProgress = false
        }
    }
}

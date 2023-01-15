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
    
    private let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(width: .abbreviated,
                                                                          usage: .asProvided,
                                                                          numberFormatStyle: .number.precision(.fractionLength(1)))
    
    
    @State private var location = CLLocationCoordinate2D(latitude: 40.712778, longitude: -74.006111) // NYC City Hall
    
    @State private var userLocality = "Unknown"
    @State private var stopsNearby = [MTABusStop]()
    @State private var busesNearby = [MTABusStop: [MTABus]]()
    
    @State private var presentAlertNotInNYC = false
    @State private var presentedAlertNotInNYC = false
    
    private var kmSelected: Bool {
        distanceUnit == .km
    }
    
    var body: some View {
        VStack {
            locationLabel
            
            if !busesNearby.isEmpty {
                NavigationView {
                    List {
                        ForEach(stopsNearby, id:\.self) { stop in
                            if let trains = getBuses(at: stop) {
                                NavigationLink {
                                    BusesAtStopView(stop: stop,
                                                    buses: getSortedBuses(from: trains),
                                                    tripUpdateByTripId: getTripUpdateByTripId(from: trains))
                                        .navigationTitle(stop.name)
                                } label: {
                                    if kmSelected {
                                        label(for: stop, distanceUnit: .km)
                                    } else {
                                        label(for: stop, distanceUnit: .mile)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationViewStyle(.stack)
            }
            
        }
        .padding()
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
        .alert(Text("There are no nearby subway stations"), isPresented: $presentAlertNotInNYC) {
            Button("OK") {
                presentedAlertNotInNYC = true
            }
        }
    }
    
    private var locationLabel: some View {
        if !userLocality.isEmpty && userLocality != "Unknown" {
            return Label(userLocality, systemImage: "mappin.and.ellipse")
        } else {
            return Label("Nearby Subway Stations", systemImage: "tram.fill.tunnel")
        }
    }
    
    private func label(for stop: MTABusStop, distanceUnit: DistanceUnit) -> some View {
        HStack {
            Text("\(stop.name)")
            
            Spacer()
            
            Text(distance(to: stop).converted(to: distanceUnit.unitLength), format: distanceFormatStyle)
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
        return busesNearby[stop]?.filter { $0.eventTime != nil }
    }
    
    private func getSortedBuses(from buses: [MTABus]) -> [MTABus] {
        print("buses=\(buses)")
        return buses.sorted(by: { $0.eventTime! < $1.eventTime! })
    }
    
    private func getTripUpdateByTripId(from buses: [MTABus]) -> [String: MTATripUpdate] {
        var result = [String: MTATripUpdate]()
        for bus in buses {
            if let trip = bus.trip, let tripId = trip.tripId, let tripUpdates = viewModel.tripUpdatesByTripId[tripId], !tripUpdates.isEmpty {
                result[tripId] = tripUpdates[0]
            }
        }
        return result
    }
}

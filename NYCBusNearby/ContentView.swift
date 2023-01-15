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
    
    private let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(width: .abbreviated,
                                                                          usage: .asProvided,
                                                                          numberFormatStyle: .number.precision(.fractionLength(1)))
    
    
    @State private var location = CLLocationCoordinate2D(latitude: 40.712778, longitude: -74.006111) // NYC City Hall
    
    @State private var userLocality = "Unknown"
    @State private var stopsNearby = [MTABusStop]()
    
    @State private var presentAlertNotInNYC = false
    @State private var presentedAlertNotInNYC = false
    
    var body: some View {
        VStack {
            locationLabel
            
            NavigationView {
                List {
                    ForEach(stopsNearby, id:\.self) { stop in
                        label(for: stop, distanceUnit: .mile)
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .padding()
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
            //trainsNearby = viewModel.trains(within: maxDistance, from: location)
            
            if stopsNearby.isEmpty {
                presentAlertNotInNYC = !presentedAlertNotInNYC
            } else if presentedAlertNotInNYC {
                presentedAlertNotInNYC = false
            }
        }
    }
}

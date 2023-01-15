//
//  BusesAtStopView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import SwiftUI
import MapKit

struct BusesAtStopView: View {
    @EnvironmentObject private var viewModel: ViewModel
    
    var stop: MTABusStop
    var buses: [MTABus]
    var tripUpdateByTripId: [String: MTATripUpdate]
    
    private var region : Binding<MKCoordinateRegion> {
        Binding {
            viewModel.region ?? MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.712778, longitude: -74.006111),
                                                   latitudinalMeters: viewModel.regionSpan,
                                                   longitudinalMeters: viewModel.regionSpan)
        } set: { region in
            DispatchQueue.main.async {
                viewModel.region = region
            }
        }
    }
    
    var body: some View {
        VStack {
            Map(coordinateRegion: region, interactionModes: .zoom, showsUserLocation: true, annotationItems: [stop]) { place in
                MapMarker(coordinate: place.getCLLocationCoordinate2D())
            }
            .aspectRatio(CGSize(width: 1.0, height: 1.0), contentMode: .fit)
            
            List {
                ForEach(buses, id: \.self) { bus in
                    if let trip = bus.trip, let eventTime = bus.eventTime, isValid(eventTime) {
                        label(for: bus, trip: trip, arrivalTime: eventTime)
                        
                        /*
                        NavigationLink {
                            if let tripId = trip.tripId, let tripUpdate = tripUpdateByTripId[tripId] {
                                TripUpdatesView(tripUpdate: tripUpdate)
                                    .navigationTitle(trip.getRouteId()?.rawValue ?? "")
                            } else {
                                EmptyView()
                            }
                        } label: {
                                label(for: train, trip: trip, arrivalTime: eventTime)
                        }
                         */
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func label(for bus: MTABus, trip: MTATrip, arrivalTime: Date) -> some View {
        HStack {
            if let systemName = bus.getDirection()?.systemName {
                Image(systemName: systemName)
            }
            
            Text(bus.trip?.routeId ?? "")
                //.frame(width: 30, height: 30)
            
            Text(bus.getDirection()?.rawValue ?? "")
            
            Spacer()
            
            if Date().distance(to: arrivalTime) > 15*60 {
                Text(arrivalTime, style: .time)
                    .foregroundColor(.secondary)
            } else {
                Text(timeInterval(to: arrivalTime))
                    .foregroundColor(arrivalTime < Date() ? .secondary : .primary)
            }
        }
    }
    
    private func isValid(_ eventTime: Date) -> Bool {
        return eventTime.timeIntervalSinceNow > viewModel.maxAgo && eventTime.timeIntervalSinceNow < viewModel.maxComing
    }
    
    private func timeInterval(to arrivalTime: Date) -> String {
        return RelativeDateTimeFormatter().localizedString(for: arrivalTime, relativeTo: Date())
    }
}


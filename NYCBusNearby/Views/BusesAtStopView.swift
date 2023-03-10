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
    var tripUpdateByTripId: [String: MTABusTripUpdate]
    
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
                    if bus.trip != nil, let eventTime = bus.eventTime, viewModel.isValid(eventTime) {
                        NavigationLink {
                            if let tripId = bus.tripId, let tripUpdate = tripUpdateByTripId[tripId] {
                                BusTripUpdateView(tripUpdate: tripUpdate)
                                    .navigationTitle(bus.routeId ?? "")
                            } else {
                                EmptyView()
                            }
                        } label: {
                                label(for: bus, arrivalTime: eventTime)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func label(for bus: MTABus, arrivalTime: Date) -> some View {
        VStack(alignment: .trailing) {
            HStack {
                Text(bus.routeId ?? "")
                
                Spacer()
                
                Text(bus.headsign ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if Date().distance(to: arrivalTime) > 15*60 {
                Text(arrivalTime, style: .time)
                    .foregroundColor(.secondary)
            } else {
                Text(timeInterval(to: arrivalTime))
                    .foregroundColor(arrivalTime < Date() ? .secondary : .primary)
            }
        }
    }
    
    private func timeInterval(to arrivalTime: Date) -> String {
        return RelativeDateTimeFormatter().localizedString(for: arrivalTime, relativeTo: Date())
    }
}


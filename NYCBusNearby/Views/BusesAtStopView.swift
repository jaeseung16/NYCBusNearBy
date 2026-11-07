//
//  BusesAtStopView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import SwiftUI
import MapKit
import MTAFeed

struct BusesAtStopView: View {
    @EnvironmentObject private var viewModel: ViewModel
    
    var stop: MTABusStop
    var buses: [MTABus]
    @Binding var selectedBus: MTABus?
    
    private var alerts: [MTAAlert] {
        viewModel.activeAlerts(routeIds: Set(buses.compactMap { $0.routeId }.filter { !$0.isEmpty }))
    }
    
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
        GeometryReader { geometry in
            VStack {
                Text(stop.name)
                    .font(.title3)
                    .bold()
                
                ServiceAlertsButton(alerts: alerts)
                
                if #available(iOS 17.0, *) {
                    MapReader { proxy in
                        Map(initialPosition: MapCameraPosition.region(region.wrappedValue), interactionModes: .all) {
                            UserAnnotation()
                            Marker("", coordinate: stop.getCLLocationCoordinate2D())
                        }
                        .onMapCameraChange { context in
                            let region = context.region
                            DispatchQueue.main.async {
                                viewModel.region = region
                            }
                        }
                    }
                    .aspectRatio(CGSize(width: 1.0, height: 1.0), contentMode: .fit)
                    .frame(width: 0.95 * geometry.size.width)
                } else {
                    Map(coordinateRegion: region, interactionModes: .zoom, showsUserLocation: true, annotationItems: [stop]) { place in
                        MapMarker(coordinate: place.getCLLocationCoordinate2D())
                    }
                    .aspectRatio(CGSize(width: 1.0, height: 1.0), contentMode: .fit)
                    .frame(width: 0.95 * geometry.size.width)
                }
                
                if buses.isEmpty {
                    ContentUnavailableView("No Buses", systemImage: "bus", description: Text("There are no buses to show. Please try again later or update the settings."))
                } else {
                    List(buses, selection: $selectedBus) { bus in
                        if bus.trip != nil, let eventTime = bus.eventTime, viewModel.isValid(eventTime) {
                            NavigationLink(value: bus) {
                                BusAtStopView(bus: bus, arrivalTime: eventTime,
                                              hasAlert: viewModel.alertedRouteIds.contains(bus.routeId ?? ""))
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
}


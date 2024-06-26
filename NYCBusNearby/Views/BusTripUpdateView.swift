//
//  TripUpdatesView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import SwiftUI
import MapKit

struct BusTripUpdateView: View {
    @EnvironmentObject private var viewModel: ViewModel
    
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
    
    private var stopTimeUpdates: [MTABusStopTimeUpdate] {
        tripUpdate.stopTimeUpdates.filter {
            $0.stopId != nil && viewModel.stopsById[$0.id] != nil && $0.eventTime != nil
        }
    }
    
    var tripUpdate: MTABusTripUpdate
    var stop: MTABusStop
    
    var body: some View {
        VStack {
            if #available(iOS 17.0, *) {
                Map(initialPosition: MapCameraPosition.region(region.wrappedValue), bounds: MapCameraBounds(centerCoordinateBounds: region.wrappedValue), interactionModes: .zoom) {
                    UserAnnotation()
                    
                    ForEach(stopTimeUpdates) { stopTimeUpdate in
                        if let stop = viewModel.stopsById[stopTimeUpdate.id], let eventTime = stopTimeUpdate.eventTime {
                            Annotation("", coordinate: stop.getCLLocationCoordinate2D()) {
                                annotationLabel(stop.name, at: eventTime)
                            }
                        }
                    }
                }
                .aspectRatio(CGSize(width: 1.0, height: 1.0), contentMode: .fit)
            } else {
                Map(coordinateRegion: region, interactionModes: .zoom, showsUserLocation: true, annotationItems: stopTimeUpdates) { stopTimeUpdate in
                    MapAnnotation(coordinate: viewModel.stopsById[stopTimeUpdate.id]!.getCLLocationCoordinate2D()) {
                        annotationLabel(viewModel.stopsById[stopTimeUpdate.id]!.name, at: stopTimeUpdate.eventTime!)
                    }
                }
                .aspectRatio(CGSize(width: 1.0, height: 1.0), contentMode: .fit)
            }
            
            List {
                ForEach(stopTimeUpdates) { stopTimeUpdate in
                    if let name = viewModel.stopsById[stopTimeUpdate.id]?.name,
                        let eventTime = stopTimeUpdate.eventTime {
                        stopTimeView(name, eventTime: eventTime)
                    }
                }
            }
        }
    }
    
    private func stopTimeView(_ name: String, eventTime: Date) -> some View {
        HStack {
            Text("\(name)")
            
            Spacer()
            
            Text(eventTime, style: .time)
        }
        .foregroundColor(eventTime < Date() ? .secondary : .primary)
        .background {
            if name == stop.name && eventTime > Date() {
                RoundedRectangle(cornerRadius: 1.0)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func annotationLabel(_ name: String, at eventTime: Date) -> some View {
        Text(eventTime, style: .time)
            .padding(2.0)
            .font(.caption)
            .foregroundColor(.black)
            .background {
                if name == stop.name {
                    RoundedRectangle(cornerRadius: 4.0)
                        .foregroundColor(.orange)
                } else {
                    RoundedRectangle(cornerRadius: 4.0)
                        .foregroundColor(.teal)
                }
            }
    }
    
}

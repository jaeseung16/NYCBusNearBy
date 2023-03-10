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
    
    var body: some View {
        VStack {
            Map(coordinateRegion: region, interactionModes: .zoom, showsUserLocation: true, annotationItems: stopTimeUpdates) { stopTimeUpdate in
                MapAnnotation(coordinate: viewModel.stopsById[stopTimeUpdate.id]!.getCLLocationCoordinate2D()) {
                    Text(stopTimeUpdate.eventTime!, style: .time)
                        .padding(2.0)
                        .font(.caption)
                        .foregroundColor(.black)
                        .background(RoundedRectangle(cornerRadius: 4.0).foregroundColor(.teal))
                }
            }
            .aspectRatio(CGSize(width: 1.0, height: 1.0), contentMode: .fit)
            
            List {
                ForEach(stopTimeUpdates) { stopTimeUpdate in
                    HStack {
                        Text("\(viewModel.stopsById[stopTimeUpdate.id]?.name ?? stopTimeUpdate.id)")
                        
                        Spacer()
                        
                        if let eventTime = stopTimeUpdate.eventTime {
                            Text(eventTime, style: .time)
                                .foregroundColor(eventTime < Date() ? .secondary : .primary)
                        }
                    }
                }
            }
        }
        
    }
}

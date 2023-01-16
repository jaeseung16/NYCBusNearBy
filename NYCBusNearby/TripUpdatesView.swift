//
//  TripUpdatesView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import SwiftUI

struct TripUpdatesView: View {
    var tripUpdate: MTATripUpdate
    
    var body: some View {
        List {
            ForEach(tripUpdate.stopTimeUpdates) { stopTimeUpdate in
                HStack {
                    Text("\(ViewModel.stopsById[stopTimeUpdate.id]?.name ?? stopTimeUpdate.id)")
                    
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

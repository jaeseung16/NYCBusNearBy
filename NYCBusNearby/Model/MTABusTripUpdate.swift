//
//  MTABusTripUpdate.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/28/23.
//

import Foundation

struct MTABusTripUpdate: Identifiable, Hashable {
    var id: String {
        return tripId ?? UUID().uuidString
    }
    
    let tripId: String?
    let stopTimeUpdates: [MTABusStopTimeUpdate]
}

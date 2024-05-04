//
//  MTABus.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import Foundation
import MTAFeed

struct MTABus: Hashable, Identifiable {
    var id: Self { self }
    
    let trip: MTATrip?
    let status: MTAVehicleStatus?
    
    let stopId: String?
    let arrivalTime: Date?
    let departureTime: Date?
    
    let headsign: String?
    
    var eventTime: Date? {
        return arrivalTime ?? departureTime
    }
    
    var routeId: String? {
        return trip?.routeId ?? ""
    }
    
    var tripId: String? {
        return trip?.tripId ?? ""
    }
}

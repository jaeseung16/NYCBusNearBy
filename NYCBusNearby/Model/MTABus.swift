//
//  MTABus.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import Foundation
import MTAFeed

struct MTABus: Hashable {
    let trip: MTATrip?
    let status: MTAVehicleStatus?
    
    let stopId: String?
    let arrivalTime: Date?
    let departureTime: Date?
    
    let headsign: String?
    
    var eventTime: Date? {
        return arrivalTime ?? departureTime
    }
    
    func getDirection() -> MTADirection? {
        if let trip = trip, let direction = trip.getDirection() {
             return direction
        } else if let last = stopId?.last {
            if last == "N" {
                return .north
            } else if last == "S" {
                return .south
            }
        }
        return nil
    }
}

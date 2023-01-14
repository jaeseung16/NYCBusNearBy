//
//  MTAStopTimeUpdate.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

struct MTAStopTimeUpdate: Identifiable {
    var id: String {
        return stopId ?? UUID().uuidString
    }
    
    let stopId: String?
    let arrivalTime: Date?
    let departureTime: Date?
    let scheduledTrack: String?
    let actualTrack: String?
    
    var eventTime: Date? {
        return arrivalTime ?? departureTime
    }
}

//
//  RestTripUpdate.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation

struct RestTripUpdate: Codable {
    let trip: RestTrip?
    let stopTimeUpdates: [RestStopTimeUpdate]
    
    private enum CodingKeys: String, CodingKey {
        case trip = "trip"
        case stopTimeUpdates = "stopTimeUpdateList"
    }
}

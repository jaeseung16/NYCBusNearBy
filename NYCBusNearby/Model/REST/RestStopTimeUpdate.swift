//
//  RestStopTimeUpdate.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation

struct RestStopTimeUpdate: Codable {
    let stopId: String?
    let arrivalTime: Date?
    let departureTime: Date?
    let scheduledTrack: String?
    let actualTrack: String?
}

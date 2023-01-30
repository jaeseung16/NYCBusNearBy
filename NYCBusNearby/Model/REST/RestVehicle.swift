//
//  RestVehicle.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation

struct RestVehicle: Codable {
    let status: RestVehicleStatus
    let stopId: String?
    let stopSequence: UInt?
    let timestamp: Date?
    let trip: RestTrip?
}

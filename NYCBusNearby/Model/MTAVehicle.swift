//
//  MTAVehicle.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

struct MTAVehicle: Hashable {
    let status: MTAVehicleStatus
    let stopId: String?
    let stopSequence: UInt?
    let timestamp: Date?
    let trip: MTATrip?
}

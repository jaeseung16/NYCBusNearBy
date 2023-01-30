//
//  RestResponseWrapper.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation

struct RestResponseWrapper: Codable {
    let vehiclesByTripId: [String: RestVehicle]?
    let tripUpdatesByTripId: [String: RestTripUpdate]?
}

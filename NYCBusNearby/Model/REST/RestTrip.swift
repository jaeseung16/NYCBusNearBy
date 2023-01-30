//
//  RestTrip.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation

struct RestTrip: Codable {
    let tripId: String?
    let routeId: String?
    let start: Date?
    let assigned: Bool?
    let trainId: String?
    let direction: RestDirection?
}

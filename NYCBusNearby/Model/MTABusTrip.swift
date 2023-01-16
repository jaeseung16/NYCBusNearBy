//
//  MTABusTrip.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import Foundation

struct MTABusTrip: Identifiable, Codable, Hashable {
    var id: String {
        tripId
    }
    
    var routeId: String
    var serviceId: String
    var tripId: String
    var tripHeadsign: String
    var directionId: String
    var blockId: String
    var shapeId: String
    
    enum CodingKeys: Int, CodingKey {
        case routeId = 0
        case serviceId = 1
        case tripId = 2
        case tripHeadsign = 3
        case directionId = 4
        case blockId = 5
        case shapeId = 6
    }
}


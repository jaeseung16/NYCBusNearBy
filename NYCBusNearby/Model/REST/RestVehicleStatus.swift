//
//  RestVehicleStatus.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation
import MTAFeed

enum RestVehicleStatus: String, Codable {
    case incomingAt = "INCOMING_AT"
    case stoppedAt = "STOPPED_AT"
    case inTransitTo = "IN_TRANSIT_TO"
    
    func getMTAVehicleStatus() -> MTAVehicleStatus {
        switch self {
        case .incomingAt:
            return .incomingAt
        case .stoppedAt:
            return .stoppedAt
        case .inTransitTo:
            return .inTransitTo
        }
    }
}

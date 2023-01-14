//
//  MTAVehicleStatus.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

enum MTAVehicleStatus: String {
    case incomingAt
    case stoppedAt
    case inTransitTo
    
    init(from direction: TransitRealtime_VehiclePosition.VehicleStopStatus) {
        switch direction {
        case .incomingAt:
            self = .incomingAt
        case .stoppedAt:
            self = .stoppedAt
        case .inTransitTo:
            self = .inTransitTo
        }
    }
    
    /*
    init(from direction: RestVehicleStatus) {
        switch direction {
        case .incomingAt:
            self = .incomingAt
        case .stoppedAt:
            self = .stoppedAt
        case .inTransitTo:
            self = .inTransitTo
        }
    }
    */
}

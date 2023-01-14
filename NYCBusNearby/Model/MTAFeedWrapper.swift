//
//  MTAFeedWrapper.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

struct MTAFeedWrapper {
    var vehiclesByStopId = [String: [MTAVehicle]]()
    var tripUpdatesByTripId = [String: [MTATripUpdate]]()
}

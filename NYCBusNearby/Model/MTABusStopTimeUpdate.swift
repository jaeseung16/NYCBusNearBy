//
//  MTABusStopTimeUpdate.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/28/23.
//

import Foundation

struct MTABusStopTimeUpdate: Identifiable, Hashable {
    var id: String {
        return stopId ?? UUID().uuidString
    }
    
    let stopId: String?
    let eventTime: Date?
}

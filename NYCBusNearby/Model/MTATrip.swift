//
//  MTATrip.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

struct MTATrip: CustomStringConvertible, Hashable {
    var tripId: String?
    var routeId: String?
    var start: Date?
    var assigned: Bool?
    var trainId: String?
    var direction: MTADirection?
    
    var description: String {
        return "MTATrip[tripId=\(String(describing: tripId)), routeId=\(String(describing: routeId)), start=\(String(describing: start)), assigned=\(String(describing: assigned)) trainId=\(String(describing: trainId)), direction=\(String(describing: direction))]"
    }
    
    func getDirection() -> MTADirection? {
        if let direction = direction {
            return direction
        } else if let tripId = tripId {
            let routeAndDirection = String(tripId.split(separator: "_")[1])
            let direction = routeAndDirection.split(separator: ".").last ?? ""
            return MTADirection(rawValue: String(direction))
        } else {
            return nil
        }
    }
    
    /*
    func getRouteId() -> MTARouteId? {
        if let tripId = tripId {
            let routeAndDirection = String(tripId.split(separator: "_")[1])
            let route = routeAndDirection.split(separator: ".")[0]
            return MTARouteId(rawValue: String(route))
        } else {
            return nil
        }
    }
    */
    
    func getOriginTime() -> Date {
        if let tripId = tripId, let timecode = Double(tripId.split(separator: "_")[0]) {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            return Date(timeInterval: timecode / 100.0 * 60.0, since: startOfDay)
        } else {
            return Date()
        }
    }
}

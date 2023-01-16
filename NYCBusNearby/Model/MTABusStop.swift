//
//  MTAStop.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/14/23.
//

import Foundation
import CoreLocation

struct MTABusStop: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var desc: String
    var latitude: Double
    var longitude: Double
    
    enum CodingKeys: Int, CodingKey {
        case id = 0
        case name = 1
        case desc = 2
        case latitude = 3
        case longitude = 4
    }
    
    func getCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func getCLLocation() -> CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
}

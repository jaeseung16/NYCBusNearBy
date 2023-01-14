//
//  MTADirection.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

enum MTADirection: String, Codable {
    case east = "E"
    case west = "W"
    case south = "S"
    case north = "N"
    
    init(from direction: NyctTripDescriptor.Direction) {
        switch direction {
        case .north:
            self = .north
        case .south:
            self = .south
        case .east:
            self = .east
        case .west:
            self = .west
        }
    }
    
    var systemName: String {
        switch self {
        case .north:
            return "arrow.up"
        case .south:
            return "arrow.down"
        case .east:
            return "arrow.right"
        case .west:
            return "arrow.left"
        }
    }
}

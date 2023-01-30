//
//  RestDirection.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/26/22.
//

import Foundation
import MTAFeed

enum RestDirection: String, Codable {
    case east = "EAST"
    case west = "WEST"
    case south = "SOUTH"
    case north = "NORTH"
    
    func mtaDirection() -> MTADirection {
        switch self {
        case .north:
            return .north
        case .south:
            return .south
        case .east:
            return .east
        case .west:
            return .west
        }
    }
}

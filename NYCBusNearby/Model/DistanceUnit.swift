//
//  DistanceUnit.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/15/23.
//

import Foundation

enum DistanceUnit: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }
    
    case km = 0
    case mile = 1
    
    var unitLength: UnitLength {
        switch self {
        case .km:
            return .kilometers
        case .mile:
            return .miles
        }
    }
}

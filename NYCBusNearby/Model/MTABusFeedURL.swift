//
//  MTABusFeedURL.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

enum MTABusFeedURL: String, CaseIterable {
    private static let urlPrefix = "https://gtfsrt.prod.obanyc.com/"
    
    case tripUpdates = "tripUpdates"
    case vehiclePositions = "vehiclePositions"
    case alerts = "alerts"
    
    func url() -> URL? {
        return URL(string: MTABusFeedURL.urlPrefix + self.rawValue + MTAFeedConstant.apiKey)
    }
}

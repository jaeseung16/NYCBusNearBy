//
//  ViewModel.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation
import os

class ViewModel: NSObject, ObservableObject {
    private static let logger = Logger()
    
    var feedDownloader = MTAFeedDownloader()
    
    
    override init() {
        feedDownloader.download(from: MTABusFeedURL.vehiclePositions) { wrapper, error in
            guard let wrapper = wrapper else {
                ViewModel.logger.log("Failed to download MTA feeds from REST, trying mta.info: error = \(String(describing: error?.localizedDescription), privacy: .public)")
                return
            }
            
            ViewModel.logger.log("url = \(MTABusFeedURL.vehiclePositions.url()?.absoluteString ?? "", privacy: .public)")
            ViewModel.logger.log("tripUpdatesByTripId.count = \(String(describing: wrapper.tripUpdatesByTripId.count), privacy: .public)")
            ViewModel.logger.log("vehicle.count = \(String(describing: wrapper.vehiclesByStopId.count), privacy: .public)")
        }
        
        feedDownloader.download(from: MTABusFeedURL.tripUpdates) { wrapper, error in
            guard let wrapper = wrapper else {
                ViewModel.logger.log("Failed to download MTA feeds from REST, trying mta.info: error = \(String(describing: error?.localizedDescription), privacy: .public)")
                return
            }
            
            ViewModel.logger.log("url = \(MTABusFeedURL.tripUpdates.url()?.absoluteString ?? "", privacy: .public)")
            ViewModel.logger.log("tripUpdatesByTripId.count = \(String(describing: wrapper.tripUpdatesByTripId.count), privacy: .public)")
            ViewModel.logger.log("vehicle.count = \(String(describing: wrapper.vehiclesByStopId.count), privacy: .public)")
        }
        
    }
}

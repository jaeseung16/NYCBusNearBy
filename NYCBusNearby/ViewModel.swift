//
//  ViewModel.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation
import os
import CoreLocation
import MapKit

class ViewModel: NSObject, ObservableObject {
    private static let logger = Logger()
    
    var feedDownloader = MTAFeedDownloader()
    
    @Published var feedAvailable = true
    
    let locationHelper = LocationHelper()
    var userLocality: String = "Unknown"
    @Published var userLocalityUpdated = false
    @Published var locationUpdated = false
    var location: CLLocation?
    var region: MKCoordinateRegion?
    private var rangeFactor = 2.0
    
    var maxAgo: TimeInterval = -1 * 60
    var maxComing: TimeInterval = 30 * 60
    
    var maxDistance = 1000.0 {
        didSet {
            if let coordinate = self.location?.coordinate {
                region = MKCoordinateRegion(center: coordinate,
                                            latitudinalMeters: CLLocationDistance(maxDistance * rangeFactor),
                                            longitudinalMeters: CLLocationDistance(maxDistance * rangeFactor))
            }
        }
    }
    
    var regionSpan: CLLocationDistance {
        return CLLocationDistance(maxDistance * rangeFactor)
    }
    
    func lookUpCurrentLocation() {
        locationHelper.lookUpCurrentLocation() { userLocality in
            self.userLocality = userLocality
            self.userLocalityUpdated.toggle()
        }
    }
    
    override init() {
        super.init()
        
        locationHelper.delegate = self
        
        if let _ = UserDefaults.standard.object(forKey: "maxDistance") {
            self.maxDistance = UserDefaults.standard.double(forKey: "maxDistance")
        }
        
        if let _ = UserDefaults.standard.object(forKey: "maxComing") {
            self.maxComing = UserDefaults.standard.double(forKey: "maxComing")
        }
        
        getAllData() { result in
            switch result {
            case .success(let success):
                self.feedAvailable = success
            case .failure:
                self.feedAvailable = false
            }
        }
        
        
    }
    
    func getAllData(completionHandler: @escaping (Result<Bool, Error>) -> Void) -> Void {
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
    
    func updateRegion(center coordinate: CLLocationCoordinate2D) -> Void {
        region = MKCoordinateRegion(center: coordinate,
                                    latitudinalMeters: CLLocationDistance(maxDistance * rangeFactor),
                                    longitudinalMeters: CLLocationDistance(maxDistance * rangeFactor))
    }
}

extension ViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        self.location = location
        self.locationUpdated.toggle()
        
        if let location = self.location {
            lookUpCurrentLocation()
            updateRegion(center: location.coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        ViewModel.logger.log("didFailWithError: error = \(error.localizedDescription, privacy: .public)")
        location = nil
    }
}

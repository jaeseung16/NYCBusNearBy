//
//  LocationHelper.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/14/23.
//

import Foundation
import CoreLocation
import os

class LocationHelper {
    private static let logger = Logger()
    
    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder()
    
    var delegate: CLLocationManagerDelegate? {
        didSet {
            locationManager.delegate = delegate
            locationManager.startUpdatingLocation()
        }
    }
    
    var coordinate: CLLocationCoordinate2D? {
        return locationManager.location?.coordinate
    }
    
    init() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func lookUpCurrentLocation(completionHandler: @escaping (String) -> Void) -> Void {
        if let lastLocation = locationManager.location {
            geocoder.reverseGeocodeLocation(lastLocation) { (placemarks, error) in
                var userLocality = "Unknown"
                if error == nil, let placemark = placemarks?[0] {
                    userLocality = self.getUserLocality(from: placemark)
                }
                completionHandler(userLocality)
            }
        }
    }
    
    private func getUserLocality(from placemark: CLPlacemark) -> String {
        let subThoroughfare = placemark.subThoroughfare ?? ""
        let thoroughfare = placemark.thoroughfare ?? ""
        let subLocality = placemark.subLocality ?? ""
        return "\(subThoroughfare) \(thoroughfare) \(subLocality)"
    }
    
}

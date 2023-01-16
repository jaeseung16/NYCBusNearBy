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
import CodableCSV

class ViewModel: NSObject, ObservableObject {
    private static let logger = Logger()
    
    static var mtaStops: [MTABusStop] = Array(Set(ViewModel.read(from: "stops", type: MTABusStop.self)))
    
    static var mtaBusTrips: [MTABusTrip] = Array(Set(ViewModel.read(from: "trips", type: MTABusTrip.self)))
    
    private static func read<T>(from resource: String, type: T.Type) -> [T] where T: Decodable {
        guard let stopsURL = Bundle.main.url(forResource: resource, withExtension: "txt") else {
            ViewModel.logger.error("No file named \(resource).txt")
            return [T]()
        }
        
        guard let contents = try? String(contentsOf: stopsURL) else {
            ViewModel.logger.error("The file doesn't contain anything")
            return [T]()
        }
        
        let decoder = CSVDecoder { $0.headerStrategy = .firstLine }
        
        guard let result = try? decoder.decode([T].self, from: contents) else {
            ViewModel.logger.error("Cannot decode \(stopsURL) to Stop")
            return [T]()
        }
        
        return result
    }
    
    static var stopsById: [String: MTABusStop] = Dictionary(uniqueKeysWithValues: mtaStops.map { ($0.id, $0) })
    
    static var headsignByTripId: [String: String] = Dictionary(uniqueKeysWithValues: mtaBusTrips.map { ($0.id, $0.tripHeadsign) })
    
    var feedDownloader = MTAFeedDownloader()
    
    @Published var feedAvailable = true
    
    var vehiclesByStopId = [String: [MTAVehicle]]()
    var tripUpdatesByTripId = [String: [MTATripUpdate]]()
    var tripUpdatesByStopId = [String: [MTATripUpdate]]()
    
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
        
        ViewModel.logger.log("# of stops = \(ViewModel.mtaStops.count)")
    }
    
    func getAllData(completionHandler: @escaping (Result<Bool, Error>) -> Void) -> Void {
        feedDownloader.download(from: MTABusFeedURL.vehiclePositions) { wrapper, error in
            guard let wrapper = wrapper else {
                ViewModel.logger.log("Failed to download MTA feeds from REST, trying mta.info: error = \(String(describing: error?.localizedDescription), privacy: .public)")
                if let error = error {
                    completionHandler(.failure(error))
                } else {
                    completionHandler(.success(false))
                }
                return
            }
            
            ViewModel.logger.log("url = \(MTABusFeedURL.vehiclePositions.url()?.absoluteString ?? "", privacy: .public)")
            ViewModel.logger.log("tripUpdatesByTripId.count = \(String(describing: wrapper.tripUpdatesByTripId.count), privacy: .public)")
            ViewModel.logger.log("vehicle.count = \(String(describing: wrapper.vehiclesByStopId.count), privacy: .public)")
            
            DispatchQueue.main.async {
                if !wrapper.vehiclesByStopId.isEmpty {
                    wrapper.vehiclesByStopId.forEach { key, vehicles in
                        self.vehiclesByStopId[key] = vehicles
                    }
                }
                
                self.feedDownloader.download(from: MTABusFeedURL.tripUpdates) { wrapper, error in
                    guard let wrapper = wrapper else {
                        ViewModel.logger.log("Failed to download MTA feeds from REST, trying mta.info: error = \(String(describing: error?.localizedDescription), privacy: .public)")
                        if let error = error {
                            completionHandler(.failure(error))
                        } else {
                            completionHandler(.success(false))
                        }
                        return
                    }
                    
                    ViewModel.logger.log("url = \(MTABusFeedURL.tripUpdates.url()?.absoluteString ?? "", privacy: .public)")
                    ViewModel.logger.log("tripUpdatesByTripId.count = \(String(describing: wrapper.tripUpdatesByTripId.count), privacy: .public)")
                    ViewModel.logger.log("vehicle.count = \(String(describing: wrapper.vehiclesByStopId.count), privacy: .public)")
                    
                    DispatchQueue.main.async {
                        if !wrapper.tripUpdatesByTripId.isEmpty {
                            wrapper.tripUpdatesByTripId.forEach { key, updates in
                                self.tripUpdatesByTripId[key] = updates
                            }
                        }
                        ViewModel.logger.log("tripUpdatesByTripId.count = \(String(describing: self.tripUpdatesByTripId.count), privacy: .public)")
                        completionHandler(.success(true))
                    }
                }
            }
        }
        
    }
    
    func updateRegion(center coordinate: CLLocationCoordinate2D) -> Void {
        region = MKCoordinateRegion(center: coordinate,
                                    latitudinalMeters: CLLocationDistance(maxDistance * rangeFactor),
                                    longitudinalMeters: CLLocationDistance(maxDistance * rangeFactor))
    }
    
    func stops(within distance: Double, from center: CLLocationCoordinate2D) -> [MTABusStop] {
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let radius = CLLocationDistance(distance)
        let circularRegion = CLCircularRegion(center: center, radius: radius, identifier: "\(center)")
        
        return ViewModel.mtaStops.filter { mtaStop in
            circularRegion.contains(CLLocationCoordinate2D(latitude: mtaStop.latitude, longitude: mtaStop.longitude))
        }.sorted { mtaStop1, mtaStop2 in
            let location1 = CLLocation(latitude: mtaStop1.latitude, longitude: mtaStop1.longitude)
            let location2 = CLLocation(latitude: mtaStop2.latitude, longitude: mtaStop2.longitude)
            
            return location1.distance(from: location) < location2.distance(from: location)
        }
    }
    
    func buses(within distance: Double, from center: CLLocationCoordinate2D) -> [MTABusStop: [MTABus]] {
        var buses = [MTABusStop: [MTABus]]()
        
        let radius = CLLocationDistance(distance)
        let circularRegion = CLCircularRegion(center: center, radius: radius, identifier: "\(center)")
        
        let stopsNearby = ViewModel.mtaStops.filter { mtaStop in
            circularRegion.contains(CLLocationCoordinate2D(latitude: mtaStop.latitude, longitude: mtaStop.longitude))
        }
        
        let stopIds = stopsNearby.map { $0.id }
        //ViewModel.logger.info("stopIds=\(stopIds, privacy: .public)")
        //ViewModel.logger.info("tripUpdatesByTripId=\(self.tripUpdatesByTripId, privacy: .public)")
        for tripId in tripUpdatesByTripId.keys {
            if let tripUpdates = tripUpdatesByTripId[tripId] {
                for tripUpdate in tripUpdates {
                    for stopTimeUpdate in tripUpdate.stopTimeUpdates {
                        if let stopId = stopTimeUpdate.stopId, stopIds.contains(stopId) {
                            let vehiclesAtStop = vehiclesByStopId[stopId]?.first(where: { tripId == $0.trip?.tripId })
                            
                            let mtaBus = MTABus(trip: tripUpdate.trip,
                                                status: vehiclesAtStop?.status,
                                                stopId: stopId,
                                                arrivalTime: stopTimeUpdate.arrivalTime,
                                                departureTime: stopTimeUpdate.departureTime,
                                                headsign: ViewModel.headsignByTripId[tripId])
                            
                            var stopIdWithoutDirection: String
                            if let last = stopId.last, last == "N" || last == "S" {
                                stopIdWithoutDirection = String(stopId.dropLast(1))
                            } else {
                                stopIdWithoutDirection = stopId
                            }
                            
                            if let stop = ViewModel.stopsById[stopIdWithoutDirection], buses[stop] != nil {
                                buses[stop]!.append(mtaBus)
                            } else if let stop = ViewModel.stopsById[stopIdWithoutDirection], buses[stop] == nil {
                                buses[stop] = Array(arrayLiteral: mtaBus)
                            } else {
                                ViewModel.logger.info("Can't find a stop with stopId=\(stopId), privacy: .public)")
                            }
                        }
                    }
                }
            }
            
        }
            
        // ViewModel.logger.info("trains=\(trains, privacy: .public) near (\(center.longitude, privacy: .public), \(center.latitude, privacy: .public))")
        
        return buses
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

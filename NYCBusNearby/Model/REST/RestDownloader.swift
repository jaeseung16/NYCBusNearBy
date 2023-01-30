//
//  RestDownloader.swift
//  MTANearby
//
//  Created by Jae Seung Lee on 12/25/22.
//

import Foundation
import os
import CoreLocation
import MTAFeed

class RestDownloader {
    private static let logger = Logger()
    
    let url: URL
    var urlRequest: URLRequest
    
    init() {
        url = URL(string: MTAFeedConstant.restUrlString)!
        
        urlRequest = URLRequest(url: url)
        urlRequest.setValue(MTAFeedConstant.applicationXWWWFormUrlencoded, forHTTPHeaderField: MTAFeedConstant.contentType)
        urlRequest.setValue(MTAFeedConstant.applicationJson, forHTTPHeaderField: MTAFeedConstant.accept)
        urlRequest.httpMethod = MTAFeedConstant.post
    }
    
    func download(from location: CLLocation?, completionHandler: @escaping (MTAFeedWrapper?, MTAFeedDownloadError?) -> Void) -> Void {
        download(from: location) { result in
            switch result {
            case .success(let feed):
                let mtaFeedWrapper = self.process(feed)
                completionHandler(mtaFeedWrapper, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
    }
    
    private func download(from location: CLLocation?, completionHandler: @escaping (Result<RestResponseWrapper, MTAFeedDownloadError>) -> Void) -> Void {
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            let start = Date()
            //RestDownloader.logger.log("Downloading feeds from mtaSubwayFeedURL = \(url, privacy: .public)")
            //RestDownloader.logger.info("response = \(String(describing: response))")
            //RestDownloader.logger.info("error = \(String(describing: error?.localizedDescription))")
            
            guard let data = data else {
                RestDownloader.logger.log("No data downloaded from mtaSubwayFeedURL = \(self.url, privacy: .public)")
                completionHandler(.failure(.noData))
                return
            }
            
            //RestDownloader.logger.log("data=\(String(describing: data))")
            //let jsonData = try? JSONSerialization.jsonObject(with: data)
            //RestDownloader.logger.log("jsonData=\(String(describing: jsonData))")
            
            var feed: RestResponseWrapper?
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            do {
                feed = try decoder.decode(RestResponseWrapper.self, from: data)
            } catch {
                RestDownloader.logger.error("\(error, privacy: .public)")
            }
            
            guard let feed = feed else {
                RestDownloader.logger.error("Cannot parse feed data from \(self.url, privacy: .public)")
                completionHandler(.failure(.cannotParse))
                return
            }
            
            //RestDownloader.logger.log("feed=\(String(describing: feed), privacy: .public)")
            
            completionHandler(.success(feed))
            RestDownloader.logger.log("For url=\(self.url.absoluteString), it took \(DateInterval(start: start, end: Date()).duration) sec")
        }
        
        task.resume()
        
    }
    
    private func getHttpBodyForRequest(from location: CLLocation) -> Data {
        let bodyString = "longitude=\(location.coordinate.longitude)&latitude=\(location.coordinate.latitude)&device=\(ProcessInfo().operatingSystemVersionString)"
        return bodyString.data(using: .utf8)!
    }
    
    private func process(_ feed: RestResponseWrapper) -> MTAFeedWrapper {
        var vehiclesByStopId = [String: [MTAVehicle]]()
        var tripUpdatesByTripId = [String: [MTATripUpdate]]()
        
        if let vehicles = feed.vehiclesByTripId {
            vehicles.forEach { tripId, vehicle in
                if let stopId = vehicle.stopId {
                    let mtaVehicle = MTAVehicle(status: vehicle.status.getMTAVehicleStatus(),
                                                stopId: stopId,
                                                stopSequence: vehicle.stopSequence,
                                                timestamp: vehicle.timestamp,
                                                trip: convert(vehicle.trip))
                    
                    if vehiclesByStopId.keys.contains(stopId) {
                        vehiclesByStopId[stopId]?.append(mtaVehicle)
                    } else {
                        vehiclesByStopId[stopId] = [mtaVehicle]
                    }
                    //RestDownloader.logger.log("stopId=\(stopId, privacy: .public)")
                }
            }
        }
        
        if let tripUpdates = feed.tripUpdatesByTripId {
            tripUpdates.forEach { tripId, tripUpdate in
                let mtaTrip = convert(tripUpdate.trip)
                let mtaStopTimeUpdates = convert(tripUpdate.stopTimeUpdates)
                tripUpdatesByTripId[tripId] = [MTATripUpdate(trip: mtaTrip, stopTimeUpdates: mtaStopTimeUpdates)]
            }
        }
        
        return MTAFeedWrapper(vehiclesByStopId: vehiclesByStopId, tripUpdatesByTripId: tripUpdatesByTripId)
    }
    
    private func convert(_ trip: RestTrip?) -> MTATrip? {
        var mtaTrip: MTATrip?
        if let trip = trip {
            let direction = trip.direction?.mtaDirection()
            mtaTrip = MTATrip(tripId: trip.tripId,
                              routeId: trip.routeId,
                              start: trip.start,
                              assigned: trip.assigned,
                              trainId: trip.trainId,
                              direction: direction ?? .north)
        }
        return mtaTrip
    }
    
    private func convert(_ stopTimeUpdates: [RestStopTimeUpdate]) -> [MTAStopTimeUpdate] {
        var mtaStopTimeUpdates = [MTAStopTimeUpdate]()
        stopTimeUpdates.forEach { stopTimeUpdate in
            mtaStopTimeUpdates.append(convert(stopTimeUpdate))
        }
        return mtaStopTimeUpdates
    }
    
    private func convert(_ stopTimeUpdate: RestStopTimeUpdate) -> MTAStopTimeUpdate {
        return MTAStopTimeUpdate(stopId: stopTimeUpdate.stopId,
                                 arrivalTime: stopTimeUpdate.arrivalTime,
                                 departureTime: stopTimeUpdate.departureTime,
                                 scheduledTrack: stopTimeUpdate.scheduledTrack,
                                 actualTrack: stopTimeUpdate.actualTrack)
    }
}

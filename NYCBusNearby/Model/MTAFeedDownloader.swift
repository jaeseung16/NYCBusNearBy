//
//  MTAFeedDownloader.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

import os

class MTAFeedDownloader {
    private static let logger = Logger()
    
    private var feedDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }
    
    func download(from mtaBusFeedURL: MTABusFeedURL, completionHandler: @escaping (MTAFeedWrapper?, MTAFeedDownloadError?) -> Void) -> Void {
        
        download(from: mtaBusFeedURL) { result in
            switch result {
            case .success(let feed):
                let mtaFeedWrapper = self.process(feed)
                completionHandler(mtaFeedWrapper, nil)
            case .failure(let error):
                completionHandler(nil, error)
            }
        }
        
    }
    
    private func download(from mtaBusFeedURL: MTABusFeedURL, completionHandler: @escaping (Result<TransitRealtime_FeedMessage, MTAFeedDownloadError>) -> Void) -> Void {
        
        guard let url = mtaBusFeedURL.url() else {
            MTAFeedDownloader.logger.log("url is nil for mtaSubwayFeedURL = \(mtaBusFeedURL.rawValue, privacy: .public)")
            completionHandler(.failure(.noURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
            let start = Date()
            MTAFeedDownloader.logger.log("Downloading feeds from mtaSubwayFeedURL = \(mtaBusFeedURL.rawValue, privacy: .public)")
            //MTAFeedDownloader.logger.info("response = \(String(describing: response))")
            //MTAFeedDownloader.logger.info("error = \(String(describing: error?.localizedDescription))")
            
            guard let data = data else {
                MTAFeedDownloader.logger.log("No data downloaded from mtaSubwayFeedURL = \(url, privacy: .public)")
                completionHandler(.failure(.noData))
                return
            }
            
            //MTAFeedDownloader.logger.log("data = \(String(describing: data))")
            
            let feed = try? TransitRealtime_FeedMessage(serializedData: data, extensions: Nyct_u45Subway_Extensions)
            guard let feed = feed else {
                MTAFeedDownloader.logger.error("Cannot parse feed data from \(url, privacy: .public)")
                completionHandler(.failure(.cannotParse))
                return
            }
            
            completionHandler(.success(feed))
            MTAFeedDownloader.logger.log("For url=\(url.absoluteString), it took \(DateInterval(start: start, end: Date()).duration) sec")
        }
        
        task.resume()
    }
    
    private func process(_ feedMessage: TransitRealtime_FeedMessage) -> MTAFeedWrapper {
        var mtaFeedWrapper = MTAFeedWrapper()
        
        let date = getFeedDate(from: feedMessage)
        
        MTAFeedDownloader.logger.log("date = \(self.feedDateFormatter.string(from: date))")
        
        var vehicles = [MTAVehicle]()
        var tripUpdates = [MTATripUpdate]()
        
        feedMessage.entity.forEach { entity in
            let _ = getAlert(from: entity, at: date)
            
            if let mtaVehicle = getVehicle(from: entity) {
                vehicles.append(mtaVehicle)
            }
            
            if let tripUpdate = getTripUpdate(from: entity) {
                tripUpdates.append(tripUpdate)
            }
            
        }
        
        // MTAFeedDownloader.logger.info("vehicles.count = \(String(describing: vehicles.count), privacy: .public)")
        
        var vehiclesByStopId = [String: [MTAVehicle]]()
        if !vehicles.isEmpty {
            for vehicle in vehicles {
                //ViewModel.logger.info("vehicle = \(String(describing: vehicle), privacy: .public)")
                if let stopId = vehicle.stopId {
                    if vehiclesByStopId.keys.contains(stopId) {
                        vehiclesByStopId[stopId]?.append(vehicle)
                    } else {
                        vehiclesByStopId[stopId] = [vehicle]
                    }
                }
            }
        }
        mtaFeedWrapper.vehiclesByStopId = vehiclesByStopId
        
        var tripUpdatesByTripId = [String: [MTATripUpdate]]()
        if !tripUpdates.isEmpty {
            for tripUpdate in tripUpdates {
                if let tripId = tripUpdate.trip?.tripId {
                    if tripUpdatesByTripId.keys.contains(tripId) {
                        tripUpdatesByTripId[tripId]?.append(tripUpdate)
                    } else {
                        tripUpdatesByTripId[tripId] = [tripUpdate]
                    }
                }
            }
        }
        mtaFeedWrapper.tripUpdatesByTripId = tripUpdatesByTripId
        return mtaFeedWrapper
    }
    
    private func getFeedDate(from feedMessage: TransitRealtime_FeedMessage) -> Date {
        return feedMessage.hasHeader ? Date(timeIntervalSince1970: TimeInterval(feedMessage.header.timestamp)) : Date()
    }
    
    private func getTripReplacementPeriods(from feedMessage: TransitRealtime_FeedMessage) -> [MTATripReplacementPeriod] {
        var mtaTripReplacementPeriods = [MTATripReplacementPeriod]()
        
        if feedMessage.hasHeader {
            let header = feedMessage.header
            if header.hasNyctFeedHeader {
                let nyctFeedHeader = header.nyctFeedHeader
                MTAFeedDownloader.logger.log("\(String(describing: nyctFeedHeader), privacy: .public)")
                
                nyctFeedHeader.tripReplacementPeriod.forEach { period in
                    let routeId = period.hasRouteID ? period.routeID : nil
                    let replacementPeriod = period.hasReplacementPeriod ? period.replacementPeriod : nil
                    
                    let endTime = (replacementPeriod?.hasEnd ?? false) ? Date(timeIntervalSince1970: TimeInterval(replacementPeriod!.end)) : nil
                    
                    let mtaTripReplacementPeriod = MTATripReplacementPeriod(routeId: routeId, endTime: endTime)
                    
                    mtaTripReplacementPeriods.append(mtaTripReplacementPeriod)
                }
                
            }
            MTAFeedDownloader.logger.log("\(String(describing: mtaTripReplacementPeriods), privacy: .public)")
        }
        
        return mtaTripReplacementPeriods
    }
    
    private func getAlert(from entity: TransitRealtime_FeedEntity, at date: Date) -> MTAAlert? {
        var mtaAlert: MTAAlert?
        if entity.hasAlert {
            let headerText = entity.alert.headerText.translation.first?.text ?? "No Header Text"
            mtaAlert = MTAAlert(delayedTrips: process(alert: entity.alert), headerText: headerText, date: date)
            MTAFeedDownloader.logger.log("mtaAlert = \(String(describing: mtaAlert), privacy: .public)")
        }
        return mtaAlert
    }
    
    private func getVehicle(from entity: TransitRealtime_FeedEntity) -> MTAVehicle? {
        var mtaVehicle: MTAVehicle?
        if entity.hasVehicle {
            let vehicle = entity.vehicle
            //let measured = Date(timeIntervalSince1970: TimeInterval(vehicle.timestamp))
            //MTAFeedDownloader.logger.info("vehicle = \(String(describing: vehicle), privacy: .public)")
            //MTAFeedDownloader.logger.info("date = \(dateFormatter.string(from: measured))")
            
            // https://developers.google.com/transit/gtfs-realtime/reference#message-vehicleposition
            let status = vehicle.hasCurrentStatus ? MTAVehicleStatus(from: vehicle.currentStatus) : .inTransitTo
            let stopSequence = vehicle.hasCurrentStopSequence ? UInt(vehicle.currentStopSequence) : nil
            let stopId = vehicle.hasStopID ? vehicle.stopID : nil
            let trip = vehicle.hasTrip ? getMTATrip(from: vehicle.trip) : nil
            let date = vehicle.hasTimestamp ? Date(timeIntervalSince1970: TimeInterval(vehicle.timestamp)) : Date()
            
            mtaVehicle = MTAVehicle(status: status,
                                    stopId: stopId,
                                    stopSequence: stopSequence,
                                    timestamp: date,
                                    trip: trip)
        }
        //MTAFeedDownloader.logger.info("mtaVehicle = \(String(describing: mtaVehicle), privacy: .public)")
        return mtaVehicle
    }
    
    private func getTripUpdate(from entity: TransitRealtime_FeedEntity) -> MTATripUpdate? {
        var mtaTripUpdate: MTATripUpdate?
        if entity.hasTripUpdate {
            let tripUpdate = entity.tripUpdate
            //MTAFeedDownloader.logger.info("tripUpdate = \(String(describing: tripUpdate), privacy: .public)")
            
            let trip = tripUpdate.hasTrip ? getMTATrip(from: tripUpdate.trip) : nil
            
            var mtaStopTimeUpdates = [MTAStopTimeUpdate]()
            
            tripUpdate.stopTimeUpdate.forEach { update in
                
                let stopId = update.hasStopID ? update.stopID : nil
                let arrivalTime = update.hasArrival ? Date(timeIntervalSince1970: TimeInterval(update.arrival.time)) : nil
                let departureTime = update.hasDeparture ? Date(timeIntervalSince1970: TimeInterval(update.departure.time)) : nil
                
                let nyctStopTimeUpdate = update.hasNyctStopTimeUpdate ? update.nyctStopTimeUpdate : nil
                
                let scheduledTrack = (nyctStopTimeUpdate?.hasScheduledTrack ?? false) ? nyctStopTimeUpdate?.scheduledTrack : nil
                let actualTrack = (nyctStopTimeUpdate?.hasActualTrack ?? false) ? nyctStopTimeUpdate?.actualTrack : nil
                
                let mtaStopTimeUpdate = MTAStopTimeUpdate(stopId: stopId,
                                                          arrivalTime: arrivalTime,
                                                          departureTime: departureTime,
                                                          scheduledTrack: scheduledTrack,
                                                          actualTrack: actualTrack)
                
                mtaStopTimeUpdates.append(mtaStopTimeUpdate)
                
            }
            
            mtaTripUpdate = MTATripUpdate(trip: trip, stopTimeUpdates: mtaStopTimeUpdates)
        }
        //MTAFeedDownloader.logger.info("mtaTripUpdate = \(String(describing: mtaTripUpdate), privacy: .public)")
        return mtaTripUpdate
    }
    
    private func process(alert: TransitRealtime_Alert) -> [MTATrip] {
        //MTAFeedDownloader.logger.log("alert = \(alert.debugDescription, privacy: .public)")
        
        var trips = [MTATrip]()
        alert.informedEntity.forEach { entity in
            if entity.hasTrip {
                let trip = entity.trip
                
                if trip.hasNyctTripDescriptor {
                    //MTAFeedDownloader.logger.log("nyctTripDescriptor = \(trip.nyctTripDescriptor.debugDescription, privacy: .public)")
                    
                    let nyctTrip = trip.nyctTripDescriptor
                    
                    let mtaTrip = MTATrip(tripId: trip.tripID,
                                          routeId: trip.routeID,
                                          trainId: nyctTrip.trainID,
                                          direction: MTADirection(from: nyctTrip.direction))
                    
                    trips.append(mtaTrip)
                }
                
            }
        }
        
        return trips
    }
    
    private func getMTATrip(from trip: TransitRealtime_TripDescriptor) -> MTATrip {
        let nyctTrip = trip.nyctTripDescriptor
        
        let tripId = trip.hasTripID ? trip.tripID : nil
        let routeId = trip.hasRouteID ? trip.routeID : nil
        let trainId = nyctTrip.hasTrainID ? nyctTrip.trainID : nil
        let direction = nyctTrip.hasDirection ? MTADirection(from: nyctTrip.direction) : nil
        let assigned = nyctTrip.hasIsAssigned ? nyctTrip.isAssigned : nil
        
        let startDate = trip.hasStartDate ? trip.startDate : nil
        let startTime = trip.hasStartTime ? trip.startTime : nil
        
        let dateFormatter = DateFormatter()
        //dateFormatter.locale = Locale(identifier: "en_US")
        //dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMdd HH:mm:ss")
        dateFormatter.dateFormat = "yyyyMMdd HH:mm:ss"
        
        var start: Date?
        if startDate != nil && startTime != nil {
            start = dateFormatter.date(from: "\(startDate!) \(startTime!)")
            // ViewModel.logger.info("start = \(String(describing: start), privacy: .public) from \(startDate!) \(startTime!)")
        } else if startDate != nil {
            // TODO: start time from tripId?
            
        }
        
        return MTATrip(tripId: tripId,
                       routeId: routeId,
                       start: start,
                       assigned: assigned,
                       trainId: trainId,
                       direction: direction)
    }
}

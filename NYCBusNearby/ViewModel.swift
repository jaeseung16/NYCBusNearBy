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
import CoreData
import Persistence
import MTAFeed

@MainActor
class ViewModel: NSObject, ObservableObject {
    nonisolated private static let logger = Logger()
    
    var mtaStops = [MTABusStop]()
    
    nonisolated private static func read<T>(from resource: String, type: T.Type) -> [T] where T: Decodable {
        guard let stopsURL = Bundle.main.url(forResource: resource, withExtension: "txt") else {
            ViewModel.logger.error("No file named \(resource).txt")
            return [T]()
        }
        
        guard let contents = try? String(contentsOf: stopsURL, encoding: .utf8) else {
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
    
    var stopsById = [String: MTABusStop]()
    
    /// Keyed by `MTABusRouteHeadsign.key(routeId:directionId:)`.
    var headsignByRouteDirection = [String: String]()
    
    var feedDownloader = MTAFeedDownloader<BusFeedURL>(apiKey: MTAFeedConstant.apiKey)
    
    @Published var feedAvailable = true
    
    var alerts = [MTAAlert]()
    var vehiclesByStopId = [String: [MTAVehicle]]()
    var tripUpdatesByTripId = [String: [MTATripUpdate]]()
    
    func resetData() {
        alerts = [MTAAlert]()
        vehiclesByStopId = [String: [MTAVehicle]]()
        tripUpdatesByTripId = [String: [MTATripUpdate]]()
    }
    
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
    
    func lookUpCurrentLocation() async {
        self.userLocality = await locationHelper.lookUpCurrentLocation()
        self.userLocalityUpdated.toggle()
    }
    
    private static let stopsDataVersionKey = "stopsDataVersion"
    
    /// Identifies the bundled `stops.txt`. Written by `scripts/update_gtfs.py`.
    private nonisolated static var bundledStopsDataVersion: String? {
        guard let url = Bundle.main.url(forResource: "gtfs_version", withExtension: "txt"),
              let version = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return version.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private let persistenceContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NYCBusNearby")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        ViewModel.logger.log("container=\(container.persistentStoreDescriptions.first?.url?.absoluteString ?? "")")
        return container
    }()
    
    /// Toggled when `mtaStops` has been loaded.
    @Published var stopsLoaded = false
    
    override init() {
        super.init()
        
        locationHelper.delegate = self
        
        if let _ = UserDefaults.standard.object(forKey: "maxDistance") {
            self.maxDistance = UserDefaults.standard.double(forKey: "maxDistance")
        }
        
        if let _ = UserDefaults.standard.object(forKey: "maxComing") {
            self.maxComing = UserDefaults.standard.double(forKey: "maxComing")
        }
        
        // Replaced by `stopsDataVersion`.
        UserDefaults.standard.removeObject(forKey: "launchedBefore")
        
        populateHeadsigns()
        
        Task {
            await populateBusStops()
        }
        
        Task {
            self.feedAvailable = await getAllDataAsync()
        }
    }
    
    /// Loads stops from Core Data, first re-importing the bundled `stops.txt` if it changed since the last import.
    func populateBusStops() async {
        let bundledVersion = ViewModel.bundledStopsDataVersion
        let importedVersion = UserDefaults.standard.string(forKey: ViewModel.stopsDataVersionKey)
        
        if bundledVersion == nil || bundledVersion != importedVersion {
            do {
                let count = try await ViewModel.importBundledStops(into: persistenceContainer)
                ViewModel.logger.log("Imported \(count) stops, version=\(bundledVersion ?? "nil", privacy: .public)")
                if let bundledVersion {
                    UserDefaults.standard.set(bundledVersion, forKey: ViewModel.stopsDataVersionKey)
                }
            } catch {
                ViewModel.logger.error("Failed to import stops: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        let fetchRequest = NSFetchRequest<MTABusStopEntity>(entityName: "MTABusStopEntity")
        do {
            mtaStops = getMTABusStops(from: try persistenceContainer.viewContext.fetch(fetchRequest))
        } catch {
            ViewModel.logger.error("Failed to fetch: \(error.localizedDescription)")
        }
        
        if mtaStops.isEmpty {
            // The store is unusable; fall back to the bundled file so the app still works.
            mtaStops = ViewModel.read(from: "stops", type: MTABusStop.self)
        }
        
        stopsById = Dictionary(mtaStops.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        ViewModel.logger.log("# of stops = \(self.mtaStops.count)")
        stopsLoaded.toggle()
    }
    
    /// Replaces every stop in the store with the bundled `stops.txt`, in one background batch delete and one batch insert.
    private nonisolated static func importBundledStops(into container: NSPersistentContainer) async throws -> Int {
        try await container.performBackgroundTask { context in
            let stops = ViewModel.read(from: "stops", type: MTABusStop.self)
            guard !stops.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            
            let delete = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "MTABusStopEntity"))
            try context.execute(delete)
            
            let objects: [[String: Any]] = stops.map {
                ["stop_id": $0.id, "name": $0.name, "desc": $0.desc, "latitude": $0.latitude, "longitude": $0.longitude]
            }
            let insert = NSBatchInsertRequest(entityName: "MTABusStopEntity", objects: objects)
            insert.resultType = .count
            let result = try context.execute(insert) as? NSBatchInsertResult
            return result?.result as? Int ?? stops.count
        }
    }
    
    func getMTABusStops(from entities: [MTABusStopEntity]) -> [MTABusStop] {
        let mtaBusStops = entities.compactMap { entity -> MTABusStop? in
            guard let id = entity.stop_id else { return nil }
            return MTABusStop(id: id,
                              name: entity.name ?? "",
                              desc: entity.desc ?? "",
                              latitude: entity.latitude,
                              longitude: entity.longitude)
        }
        ViewModel.logger.log("Loaded \(mtaBusStops.count) entities")
        return mtaBusStops
    }
    
    func populateHeadsigns() -> Void {
        let headsigns = ViewModel.read(from: "route_headsigns", type: MTABusRouteHeadsign.self)
        headsignByRouteDirection = Dictionary(headsigns.map { ($0.key, $0.headsign) },
                                              uniquingKeysWith: { first, _ in first })
        ViewModel.logger.log("Loaded \(self.headsignByRouteDirection.count) route headsigns")
    }
    
    /// The trip's headsign: the most common one for its route and direction,
    /// or the name of the last stop in its trip update if the route or direction is unknown.
    func headsign(for tripUpdate: MTATripUpdate) -> String? {
        if let routeId = tripUpdate.trip?.routeId, let directionId = tripUpdate.trip?.directionId,
           let headsign = headsignByRouteDirection[MTABusRouteHeadsign.key(routeId: routeId, directionId: String(directionId))] {
            return headsign
        }
        if let lastStopId = tripUpdate.stopTimeUpdates.last?.stopId {
            return stopsById[lastStopId]?.name
        }
        return nil
    }
    
    func getAllDataAsync() async -> Bool {
        resetData()
        
        let result = await downloadFromMTAInfo()
        
        ViewModel.logger.log("result=\(result, privacy: .public)")
        
        return result.count == BusFeedURL.allCases.count
    }
    
    private func downloadFromMTAInfo() async -> [Bool] {
        let start = Date()
        var success = [Bool]()
        
        let wrappers = await withTaskGroup(of: MTAFeedWrapper.self) { group in
            for busFeedURL in BusFeedURL.allCases {
                group.addTask {
                    let wrapper: MTAFeedWrapper
                    do {
                        wrapper = try await self.feedDownloader.download(from: busFeedURL) ?? MTAFeedWrapper()
                    } catch {
                        wrapper = MTAFeedWrapper()
                        Task { @MainActor in
                            ViewModel.logger.log("Failed to download MTA feeds from \(busFeedURL.rawValue): error = \(String(describing: error.localizedDescription), privacy: .public)")
                        }
                    }
                    return wrapper
                }
            }
            
            var wrappers = [MTAFeedWrapper]()
            for await result in group {
                wrappers.append(result)
            }
            return wrappers
        }
        
        for wrapper in wrappers {
            if !wrapper.alerts.isEmpty {
                self.alerts.append(contentsOf: wrapper.alerts)
            }
            if !wrapper.tripUpdatesByTripId.isEmpty {
                wrapper.tripUpdatesByTripId.forEach { key, updates in
                    self.tripUpdatesByTripId[key] = updates
                }
            }
            if !wrapper.vehiclesByStopId.isEmpty {
                wrapper.vehiclesByStopId.forEach { key, vehicles in
                    self.vehiclesByStopId[key] = vehicles
                }
            }
            
            success.append(true)
        }
        
        ViewModel.logger.log("It took \(DateInterval(start: start, end: Date()).duration) sec to finish all feed downloads")
        return success
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
        
        return mtaStops.filter { mtaStop in
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
        
        let stopsNearby = mtaStops.filter { mtaStop in
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
                                                headsign: headsign(for: tripUpdate))
                            
                            var stopIdWithoutDirection: String
                            if let last = stopId.last, last == "N" || last == "S" {
                                stopIdWithoutDirection = String(stopId.dropLast(1))
                            } else {
                                stopIdWithoutDirection = stopId
                            }
                            
                            if let stop = self.stopsById[stopIdWithoutDirection], buses[stop] != nil {
                                buses[stop]!.append(mtaBus)
                            } else if let stop = self.stopsById[stopIdWithoutDirection], buses[stop] == nil {
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
    
    func getTripUpdateByTripId(from buses: [MTABus]) -> [String: MTABusTripUpdate] {
        var result = [String: MTABusTripUpdate]()
        for bus in buses {
            if let trip = bus.trip, let tripId = trip.tripId, let tripUpdates = tripUpdatesByTripId[tripId], !tripUpdates.isEmpty {
                let stopTimeUpdates = tripUpdates[0].stopTimeUpdates.filter { $0.stopId != nil }
                    .map {
                        MTABusStopTimeUpdate(stopId: $0.stopId, eventTime: $0.eventTime)
                    }
                result[tripId] = MTABusTripUpdate(tripId: tripId, stopTimeUpdates: stopTimeUpdates)
            }
        }
        return result
    }
    
    func isValid(_ eventTime: Date) -> Bool {
        return eventTime.timeIntervalSinceNow > maxAgo && eventTime.timeIntervalSinceNow < maxComing
    }
}

extension ViewModel: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        self.location = location
        self.locationUpdated.toggle()
        
        if let location = self.location {
            Task {
                await lookUpCurrentLocation()
                updateRegion(center: location.coordinate)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        ViewModel.logger.log("didFailWithError: error = \(error.localizedDescription, privacy: .public)")
        location = nil
    }
}

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

class ViewModel: NSObject, ObservableObject {
    private static let logger = Logger()
    
    var mtaStops = [MTABusStop]()
    
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
    
    var stopsById = [String: MTABusStop]()
    
    var headsignByTripId = [String: String]()
    
    var feedDownloader = MTAFeedDownloader<BusFeedURL>(apiKey: MTAFeedConstant.apiKey)
    var restDownloader = RestDownloader()
    
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
    
    func lookUpCurrentLocation() {
        locationHelper.lookUpCurrentLocation() { userLocality in
            self.userLocality = userLocality
            self.userLocalityUpdated.toggle()
        }
    }
    
    //private let persistence = Persistence(name: "NYCBusNearby", identifier: "com.resonance.jlee.NYCBusNearby", isCloud: false)
    
    private lazy var persistenceContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NYCBusNearby")
            
        if !self.launchedBefore {
            if let storeUrl = container.persistentStoreDescriptions.first?.url,
               let seededDataUrl = Bundle.main.url(forResource: "NYCBusNearby", withExtension: "sqlite") {
                do {
                    try container.persistentStoreCoordinator.replacePersistentStore(at: storeUrl,
                                                                                    destinationOptions: nil,
                                                                                    withPersistentStoreFrom: seededDataUrl,
                                                                                    sourceOptions: nil,
                                                                                    type: .sqlite)
                    
                    UserDefaults.standard.setValue(true, forKey: "launchedBefore")
                } catch {
                    ViewModel.logger.error("Couln't replace: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                ViewModel.logger.log("persistenceStore=\(container.persistentStoreDescriptions.first?.url?.absoluteString ?? "")")
                ViewModel.logger.log("bundle=\(Bundle.main.url(forResource: "NYCBusNearby", withExtension: "sqlite")?.absoluteString ?? "")")
                //fatalError("Cannot unwrap URLs!")
            }
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        ViewModel.logger.log("container=\(container.persistentStoreDescriptions.first?.url?.absoluteString ?? "")")
        return container
    }()

    private var launchedBefore = false
    
    override init() {
        super.init()
        
        locationHelper.delegate = self
        
        launchedBefore = UserDefaults.standard.bool(forKey: "launchedBefore")
        
        if let _ = UserDefaults.standard.object(forKey: "maxDistance") {
            self.maxDistance = UserDefaults.standard.double(forKey: "maxDistance")
        }
        
        if let _ = UserDefaults.standard.object(forKey: "maxComing") {
            self.maxComing = UserDefaults.standard.double(forKey: "maxComing")
        }
        
        populateBusStops()
        populateHeadsignByTripId()
        
        getAllData() { result in
            switch result {
            case .success(let success):
                self.feedAvailable = success
            case .failure:
                self.feedAvailable = false
            }
        }
        
        ViewModel.logger.log("# of stops = \(self.mtaStops.count)")
    }
    
    func populateBusStops() -> Void {
        let fetchRequest = NSFetchRequest<MTABusStopEntity>(entityName: "MTABusStopEntity")
        
        var fetchedEntities = [MTABusStopEntity]()
        do {
            fetchedEntities = try persistenceContainer.viewContext.fetch(fetchRequest)
        } catch {
            ViewModel.logger.error("Failed to fetch: \(error.localizedDescription)")
        }
        
        if fetchedEntities.isEmpty {
            var count = 0
            let viewContext = persistenceContainer.viewContext
            
            mtaStops = Array(Set(ViewModel.read(from: "stops", type: MTABusStop.self)))
            
            mtaStops.forEach { stop in
                let entity = MTABusStopEntity(context: viewContext)
                entity.stop_id = stop.id
                entity.name = stop.name
                entity.desc = stop.desc
                entity.latitude = stop.latitude
                entity.longitude = stop.longitude
                
                count += 1
                
                do {
                    try viewContext.save()
                } catch {
                    ViewModel.logger.error("Failed to save \(entity): \(error.localizedDescription)")
                }
            }
            
        } else {
            mtaStops = getMTABusStops(from: fetchedEntities)
        }
        
        stopsById = Dictionary(uniqueKeysWithValues: mtaStops.map { ($0.id, $0) })
    }
    
    
    func getMTABusStops(from entities: [MTABusStopEntity]) -> [MTABusStop] {
        var count = 0

        var mtaBusStops = [MTABusStop]()
        
        entities.forEach { entity in
            if let id = entity.stop_id {
                let mtaBusTrip = MTABusStop(id: id,
                                            name: entity.name ?? "",
                                            desc: entity.desc ?? "",
                                            latitude: entity.latitude,
                                            longitude: entity.longitude)
                
                mtaBusStops.append(mtaBusTrip)
                
                count += 1
            }
        }
        
        ViewModel.logger.log("Loaded \(count) entities")
        
        return Array(Set(mtaBusStops))
    }
    
    
    func populateHeadsignByTripId() -> Void {
        let fetchRequest = NSFetchRequest<MTABusTripEntity>(entityName: "MTABusTripEntity")
        
        var fetchedEntities = [MTABusTripEntity]()
        do {
            fetchedEntities = try persistenceContainer.viewContext.fetch(fetchRequest)
        } catch {
            ViewModel.logger.error("Failed to fetch: \(error.localizedDescription)")
        }
        
        
        var mtaBusTrips = [MTABusTrip]()
        if fetchedEntities.isEmpty {
            let viewContext = persistenceContainer.viewContext
            
            mtaBusTrips = Array(Set(ViewModel.read(from: "trips", type: MTABusTrip.self)))
            
            mtaBusTrips.forEach { trip in
                let entity = MTABusTripEntity(context: viewContext)
                entity.route_id = trip.routeId
                entity.service_id = trip.serviceId
                entity.trip_id = trip.tripId
                entity.trip_headsign = trip.tripHeadsign
                entity.direction_id = trip.directionId
                entity.block_id = trip.blockId
                entity.shape_id = trip.shapeId
                
                do {
                    try viewContext.save()
                } catch {
                    ViewModel.logger.error("Failed to save \(entity): \(error.localizedDescription)")
                }
                
            }
            
        } else {
            mtaBusTrips = getMTABusTrips(from: fetchedEntities)
        }
        
        self.headsignByTripId = Dictionary(uniqueKeysWithValues: mtaBusTrips.map { ($0.id, $0.tripHeadsign) })
    }
    
    /*
    func populatePersistenceStore() -> [MTABusTrip] {
        
        
        ViewModel.logger.log("Save \(count) entities")
        
        return mtaBusTrips
    }
    */
    
    func getMTABusTrips(from entities: [MTABusTripEntity]) -> [MTABusTrip] {
        var count = 0

        var mtaBusTrips = [MTABusTrip]()
        
        entities.forEach { entity in
            if let tripId = entity.trip_id {
                let mtaBusTrip = MTABusTrip(routeId: entity.route_id ?? "",
                                            serviceId: entity.service_id ?? "",
                                            tripId: tripId,
                                            tripHeadsign: entity.trip_headsign ?? "",
                                            directionId: entity.direction_id ?? "",
                                            blockId: entity.block_id ?? "",
                                            shapeId: entity.shape_id ?? "")
                
                mtaBusTrips.append(mtaBusTrip)
                
                count += 1
            }
        }
        
        ViewModel.logger.log("Loaded \(count) entities")
        
        return Array(Set(mtaBusTrips))
    }
    
    func getAllData(completionHandler: @escaping (Result<Bool, Error>) -> Void) -> Void {
        resetData()
        //let start = Date()
        
        downloadFromMTAInfo() { result in
            completionHandler(result)
        }
        
        /*
        restDownloader.download(from: location) { wrapper, error in
            guard let wrapper = wrapper else {
                ViewModel.logger.log("Failed to download Bus feeds from REST, trying mta.info: error = \(String(describing: error?.localizedDescription), privacy: .public)")
                self.downloadFromMTAInfo() { result in
                    completionHandler(result)
                }
                return
            }
            
            //ViewModel.logger.log("wrapper=\(String(describing: wrapper), privacy: .public)")
            
            DispatchQueue.main.async {
                //ViewModel.logger.log("wrapper.tripUpdatesByTripId.count = \(wrapper.tripUpdatesByTripId.count, privacy: .public)")
                if !wrapper.tripUpdatesByTripId.isEmpty {
                    wrapper.tripUpdatesByTripId.forEach { key, updates in
                        self.tripUpdatesByTripId[key] = updates
                        //ViewModel.logger.log("tripUpdatesByTripId.key = \(key, privacy: .public)")
                    }
                }
                //ViewModel.logger.log("wrapper.vehiclesByStopId.count = \(wrapper.vehiclesByStopId.count, privacy: .public)")
                if !wrapper.vehiclesByStopId.isEmpty {
                    wrapper.vehiclesByStopId.forEach { key, vehicles in
                        self.vehiclesByStopId[key] = vehicles
                        //ViewModel.logger.log("vehiclesByStopId.key = \(key, privacy: .public)")
                    }
                }
                ViewModel.logger.log("It took \(DateInterval(start: start, end: Date()).duration) sec to finish a bus feed download")
                
                completionHandler(.success(true))
            }
        }
        */
        
    }
    
    private func downloadFromMTAInfo(completionHandler: @escaping (Result<Bool, Error>) -> Void) -> Void {
        let start = Date()
        let dispatchGroup = DispatchGroup()
        var errors = [Error]()
        var success = [Bool]()
        
        for busFeedURL in BusFeedURL.allCases {
            dispatchGroup.enter()
            feedDownloader.download(from: busFeedURL) { wrapper, error in
                guard let wrapper = wrapper else {
                    ViewModel.logger.log("Failed to download for \(busFeedURL.rawValue, privacy: .public): error = \(String(describing: error?.localizedDescription), privacy: .public)")
                    DispatchQueue.main.async {
                        if let error = error {
                            errors.append(error)
                        } else {
                            success.append(false)
                        }
                    }
                    dispatchGroup.leave()
                    return
                }
                
                ViewModel.logger.log("BusFeedURL=\(busFeedURL.rawValue, privacy: .public)")
                //ViewModel.logger.log("alerts.count = \(String(describing: wrapper.alerts.count), privacy: .public)")
                //ViewModel.logger.log("tripUpdatesByTripId.count = \(String(describing: wrapper.tripUpdatesByTripId.count), privacy: .public)")
                //ViewModel.logger.log("vehicle.count = \(String(describing: wrapper.vehiclesByStopId.count), privacy: .public)")
                
                DispatchQueue.main.async {
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
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if !errors.isEmpty {
                completionHandler(.failure(errors[0]))
            } else if success.filter({$0}).count != BusFeedURL.allCases.count {
                completionHandler(.success(false))
            } else {
                completionHandler(.success(true))
            }
            ViewModel.logger.log("It took \(DateInterval(start: start, end: Date()).duration) sec to finish all feed downloads")
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
                                                headsign: headsignByTripId[tripId])
                            
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

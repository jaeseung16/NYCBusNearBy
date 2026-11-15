//
//  BusStopEntity.swift
//  NYCBusNearby
//

import AppIntents

/// A bus stop as App Intents see it: a parameter of the stop intents, in Siri phrases and the Shortcuts picker.
///
/// A `Sendable` copy of a `FavoriteStop` or an `MTABusStop`, made on the main actor.
struct BusStopEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bus Stop"
    static var defaultQuery: BusStopQuery { BusStopQuery() }

    /// The stop code printed on the sign, which is the GTFS stop_id.
    let id: String
    let name: String
    let nickname: String?

    var displayName: String {
        nickname ?? name
    }

    var displayRepresentation: DisplayRepresentation {
        if nickname != nil {
            DisplayRepresentation(title: "\(displayName)", subtitle: "\(name) · Stop #\(id)")
        } else {
            DisplayRepresentation(title: "\(name)", subtitle: "Stop #\(id)")
        }
    }

    init(favorite: FavoriteStop) {
        self.id = favorite.id
        self.name = favorite.name
        self.nickname = favorite.nickname
    }

    init(stop: MTABusStop, nickname: String? = nil) {
        self.id = stop.id
        self.name = stop.name
        self.nickname = nickname
    }
}

/// Finds stops for the stop intents. Favorites come first: they're the suggestions,
/// and a nickname such as "Home" is what the user will say.
struct BusStopQuery: EntityStringQuery {
    @Dependency private var viewModel: ViewModel

    private static let maxResults = 20

    @MainActor
    func entities(for identifiers: [BusStopEntity.ID]) async throws -> [BusStopEntity] {
        await viewModel.ensureStopsLoaded()
        return identifiers.compactMap { id in
            if let favorite = viewModel.favorite(forStopId: id) {
                return BusStopEntity(favorite: favorite)
            }
            return viewModel.stopsById[id].map { BusStopEntity(stop: $0) }
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [BusStopEntity] {
        viewModel.favoriteStops.map(BusStopEntity.init(favorite:))
    }

    /// Favorites by nickname or name, then stops by code, then stops by name.
    @MainActor
    func entities(matching string: String) async throws -> [BusStopEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return try await suggestedEntities()
        }
        await viewModel.ensureStopsLoaded()

        var results = viewModel.favoriteStops
            .filter { ($0.nickname?.localizedStandardContains(query) ?? false) || $0.name.localizedStandardContains(query) }
            .map(BusStopEntity.init(favorite:))
        var seen = Set(results.map(\.id))

        func append(_ stops: [MTABusStop]) {
            for stop in stops where results.count < Self.maxResults && !seen.contains(stop.id) {
                seen.insert(stop.id)
                results.append(BusStopEntity(stop: stop))
            }
        }

        if query.allSatisfy(\.isNumber) {
            if let stop = viewModel.stopsById[query] {
                append([stop])
            }
            append(viewModel.mtaStops.filter { $0.id.hasPrefix(query) }.sorted { $0.id < $1.id })
        }
        if results.count < Self.maxResults {
            append(viewModel.mtaStops.filter { $0.name.localizedStandardContains(query) }.sorted { $0.name < $1.name })
        }

        return Array(results.prefix(Self.maxResults))
    }
}

//
//  FavoriteStop.swift
//  NYCBusNearby
//

import Foundation

/// A bus stop the user starred.
///
/// It keeps a snapshot of the stop's name and coordinate, so it survives a GTFS update that
/// drops or renumbers the stop. Don't embed `MTABusStop`: its coding keys are CSV column
/// positions. Add new properties as optionals so favorites saved by older versions still decode.
struct FavoriteStop: Codable, Hashable, Identifiable, Sendable {
    /// The stop ID, which is the code printed on the bus stop sign.
    let id: String
    var name: String
    var latitude: Double
    var longitude: Double
    /// A name the user chose, such as "Home". Shown instead of `name` when set.
    var nickname: String?
    let addedAt: Date

    static let maxNicknameLength = 40

    init(stop: MTABusStop, nickname: String? = nil, addedAt: Date = .now) {
        self.id = stop.id
        self.name = stop.name
        self.latitude = stop.latitude
        self.longitude = stop.longitude
        self.nickname = FavoriteStop.normalizedNickname(nickname)
        self.addedAt = addedAt
    }

    var displayName: String {
        nickname ?? name
    }

    /// Trims whitespace, treats an empty name as no nickname, and limits the length.
    static func normalizedNickname(_ nickname: String?) -> String? {
        guard let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return String(trimmed.prefix(maxNicknameLength))
    }

    /// Updates the snapshot from the current stop data. Returns whether anything changed.
    mutating func refresh(from stop: MTABusStop) -> Bool {
        guard stop.id == id,
              name != stop.name || latitude != stop.latitude || longitude != stop.longitude else {
            return false
        }
        name = stop.name
        latitude = stop.latitude
        longitude = stop.longitude
        return true
    }
}

//
//  FavoriteStopsStore.swift
//  NYCBusNearby
//

import Foundation
import os

/// Saves the favorite stops on the device, as a JSON string in UserDefaults.
///
/// A string (not `Data`) so it can be read and edited while testing:
/// `xcrun simctl spawn booted defaults read com.resonance.NYCBusNearby favoriteStops`.
/// An App Group (`UserDefaults(suiteName:)`) or iCloud sync can later go behind this type.
struct FavoriteStopsStore {
    private static let logger = Logger()

    private let defaults: UserDefaults
    private let key: String

    /// Where an undecodable value is copied, so it's never silently lost.
    private var unreadableKey: String {
        "\(key).unreadable"
    }

    init(defaults: UserDefaults = .standard, key: String = "favoriteStops") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [FavoriteStop] {
        guard let json = defaults.string(forKey: key) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([FavoriteStop].self, from: Data(json.utf8))
        } catch {
            FavoriteStopsStore.logger.error("Can't decode favorite stops: \(error.localizedDescription, privacy: .public)")
            defaults.set(json, forKey: unreadableKey)
            return []
        }
    }

    func save(_ favorites: [FavoriteStop]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(favorites)
            defaults.set(String(decoding: data, as: UTF8.self), forKey: key)
        } catch {
            FavoriteStopsStore.logger.error("Can't encode favorite stops: \(error.localizedDescription, privacy: .public)")
        }
    }
}

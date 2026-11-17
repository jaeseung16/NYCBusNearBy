//
//  FavoriteStopsStore.swift
//  NYCBusNearby
//

import Foundation
import os

/// Saves the favorite stops on the device, as a JSON string in the App Group's UserDefaults.
///
/// A string (not `Data`) so it can be read and edited while testing. In the simulator, read the
/// App Group plist by path:
/// `xcrun simctl spawn booted defaults read "$(xcrun simctl get_app_container booted com.resonance.NYCBusNearby groups | awk '$1 == "group.com.resonance.NYCBusNearby" {print $2}')/Library/Preferences/group.com.resonance.NYCBusNearby.plist" favoriteStops`.
/// Favorites saved by older versions in `UserDefaults.standard` are moved here on the first `load()`.
struct FavoriteStopsStore {
    private static let logger = Logger()

    static let appGroupId = "group.com.resonance.NYCBusNearby"

    /// The App Group's defaults, or `.standard` if the suite can't be opened.
    static var sharedDefaults: UserDefaults {
        if let defaults = UserDefaults(suiteName: appGroupId) {
            return defaults
        }
        logger.error("Can't open the App Group defaults \(appGroupId, privacy: .public); using the standard defaults")
        return .standard
    }

    private let defaults: UserDefaults
    private let key: String

    /// Where an undecodable value is copied, so it's never silently lost.
    private var unreadableKey: String {
        "\(key).unreadable"
    }

    /// The stop IDs in iCloud after the last merge or upload.
    private let syncedIdsKey = "favoriteSyncedIds"

    init(defaults: UserDefaults = FavoriteStopsStore.sharedDefaults, key: String = "favoriteStops") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [FavoriteStop] {
        migrateFromStandardDefaults()

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

    func loadSyncedIds() -> Set<String> {
        Set(defaults.stringArray(forKey: syncedIdsKey) ?? [])
    }

    func saveSyncedIds(_ ids: Set<String>) {
        defaults.set(ids.sorted(), forKey: syncedIdsKey)
    }

    /// Moves favorites saved by older versions from `UserDefaults.standard` to this store's
    /// defaults, once. Does nothing if this store already has favorites or uses `.standard`.
    private func migrateFromStandardDefaults() {
        let standard = UserDefaults.standard
        guard defaults !== standard,
              defaults.object(forKey: key) == nil,
              let json = standard.string(forKey: key) else {
            return
        }

        defaults.set(json, forKey: key)
        if let unreadable = standard.string(forKey: unreadableKey) {
            defaults.set(unreadable, forKey: unreadableKey)
        }
        standard.removeObject(forKey: key)
        standard.removeObject(forKey: unreadableKey)
        FavoriteStopsStore.logger.notice("Moved favorites to the App Group")
    }
}

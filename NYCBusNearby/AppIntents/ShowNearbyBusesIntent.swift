//
//  ShowNearbyBusesIntent.swift
//  NYCBusNearby
//

import AppIntents

/// Opens the app, which shows the bus stops near the user.
///
/// It takes no parameters, so it works from Siri, Shortcuts, Spotlight, and the Action button
/// without the user having to know a stop name.
struct ShowNearbyBusesIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Nearby Buses"
    static let description = IntentDescription("Opens NYC Buses Near Me to the bus stops near you.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        // Opening the app is the whole job. A cold launch downloads the feeds in `ViewModel.init`.
        return .result()
    }
}

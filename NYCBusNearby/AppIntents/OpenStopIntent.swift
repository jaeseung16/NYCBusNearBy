//
//  OpenStopIntent.swift
//  NYCBusNearby
//

import AppIntents

/// Opens the app to a stop's arrivals.
struct OpenStopIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Bus Stop"
    static let description = IntentDescription("Opens NYC Buses Near Me to the buses arriving at a stop.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Stop")
    var stop: BusStopEntity

    @Dependency private var viewModel: ViewModel

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$stop)")
    }

    init() {}

    init(stop: BusStopEntity) {
        self.stop = stop
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // ContentView selects the stop, waiting for the stops to load after a cold launch.
        viewModel.requestedStopId = stop.id
        return .result()
    }
}

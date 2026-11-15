//
//  NextBusesAtStopIntent.swift
//  NYCBusNearby
//

import AppIntents
import os

/// Says when the next buses arrive at a stop, without opening the app.
struct NextBusesAtStopIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Buses at Stop"
    static let description = IntentDescription("Tells you when the next buses arrive at a stop.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Stop")
    var stop: BusStopEntity

    @Dependency private var viewModel: ViewModel

    /// How many arrivals the dialog reads out. The returned value has all of them.
    private static let spokenCount = 3
    private static let logger = Logger()

    static var parameterSummary: some ParameterSummary {
        Summary("Next buses at \(\.$stop)")
    }

    init() {}

    init(stop: BusStopEntity) {
        self.stop = stop
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<[BusArrival]> & ProvidesDialog {
        await viewModel.ensureStopsLoaded()
        guard let mtaStop = viewModel.stopsById[stop.id] else {
            return .result(value: [], dialog: "\(stop.displayName) is no longer served.")
        }

        let start = Date()
        await viewModel.ensureFreshFeed(maxAge: 60)
        NextBusesAtStopIntent.logger.log("Feed ready after \(Date().timeIntervalSince(start), format: .fixed(precision: 1)) s")

        guard viewModel.feedAvailable else {
            return .result(value: [], dialog: "Can't reach the MTA bus feed. Try again later.")
        }

        let now = Date()
        let arrivals = viewModel.upcomingBuses(at: mtaStop).compactMap { bus -> BusArrival? in
            guard let eventTime = bus.eventTime, eventTime >= now || bus.isCanceled else { return nil }
            return BusArrival(route: bus.routeId ?? "", headsign: bus.headsign ?? "",
                              arrivalTime: eventTime, isCanceled: bus.isCanceled, now: now)
        }

        guard !arrivals.isEmpty else {
            let minutes = Int(viewModel.maxComing / 60)
            return .result(value: [], dialog: "No buses are expected at \(stop.displayName) in the next \(minutes) minutes.")
        }

        let spoken = arrivals.prefix(Self.spokenCount).map { $0.sentence + "." }.joined(separator: " ")
        return .result(value: arrivals, dialog: "\(spoken)")
    }
}

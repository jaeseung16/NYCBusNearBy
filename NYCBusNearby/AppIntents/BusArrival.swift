//
//  BusArrival.swift
//  NYCBusNearby
//

import AppIntents
import Foundation

/// One bus arriving at a stop, as returned by `NextBusesAtStopIntent`.
///
/// A transient entity: Shortcuts can read its properties, but it can't be looked up later.
struct BusArrival: TransientAppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bus Arrival"

    @Property(title: "Route")
    var route: String

    @Property(title: "Headsign")
    var headsign: String

    @Property(title: "Arrival Time")
    var arrivalTime: Date

    @Property(title: "Minutes Away")
    var minutesAway: Int

    @Property(title: "Canceled")
    var isCanceled: Bool

    var id = UUID()

    init() {
        route = ""
        headsign = ""
        arrivalTime = .now
        minutesAway = 0
        isCanceled = false
    }

    init(route: String, headsign: String, arrivalTime: Date, isCanceled: Bool, now: Date = .now) {
        self.init()
        self.route = route
        self.headsign = headsign
        self.arrivalTime = arrivalTime
        self.minutesAway = max(0, Int((arrivalTime.timeIntervalSince(now) / 60).rounded()))
        self.isCanceled = isCanceled
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(route) to \(headsign)", subtitle: "\(summary)")
    }

    /// "in 4 minutes", "now", or "canceled".
    var summary: String {
        if isCanceled {
            return "canceled"
        }
        switch minutesAway {
        case 0: return "now"
        case 1: return "in 1 minute"
        default: return "in \(minutesAway) minutes"
        }
    }

    /// "M15 to South Ferry in 4 minutes" or "B44 to Sheepshead Bay is canceled".
    var sentence: String {
        let bus = headsign.isEmpty ? route : "\(route) to \(headsign)"
        return isCanceled ? "\(bus) is canceled" : "\(bus) \(summary)"
    }
}

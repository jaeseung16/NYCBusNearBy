//
//  NYCBusShortcuts.swift
//  NYCBusNearby
//

import AppIntents

/// The App Shortcuts that are available as soon as the app is installed, with their Siri phrases.
///
/// To add one: write the intent in this folder, then add an `AppShortcut` here.
/// Every phrase must contain `\(.applicationName)` ("NYC Buses Near Me").
/// The app can declare at most 10 App Shortcuts.
struct NYCBusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ShowNearbyBusesIntent(),
                    phrases: ["Show nearby buses in \(.applicationName)",
                              "Show buses near me in \(.applicationName)",
                              "Find bus stops near me in \(.applicationName)"],
                    shortTitle: "Nearby Buses",
                    systemImageName: "bus")
        // The stop phrases suggest the favorites; call updateAppShortcutParameters() when they change.
        AppShortcut(intent: NextBusesAtStopIntent(),
                    phrases: ["When is the next bus at \(\.$stop) in \(.applicationName)",
                              "Next buses at \(\.$stop) in \(.applicationName)",
                              "Next buses at a stop in \(.applicationName)"],
                    shortTitle: "Next Buses",
                    systemImageName: "clock")
        AppShortcut(intent: OpenStopIntent(),
                    phrases: ["Show \(\.$stop) in \(.applicationName)",
                              "Open \(\.$stop) in \(.applicationName)",
                              "Open a bus stop in \(.applicationName)"],
                    shortTitle: "Open Stop",
                    systemImageName: "star")
    }
}

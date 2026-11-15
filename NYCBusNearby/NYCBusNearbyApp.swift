//
//  NYCBusNearbyApp.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import SwiftUI
import AppIntents

@main
struct NYCBusNearbyApp: App {

    private let viewModel: ViewModel

    init() {
        let viewModel = ViewModel()
        self.viewModel = viewModel
        // Lets App Intents reach the shared view model with `@Dependency var viewModel: ViewModel`.
        AppDependencyManager.shared.add(dependency: viewModel)
        // The stop phrases offer the favorites, which were loaded in ViewModel.init.
        NYCBusShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

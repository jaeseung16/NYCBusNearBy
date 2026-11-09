//
//  AdsStarter.swift
//  NYCBusNearby
//

import Foundation
import AppTrackingTransparency
import GoogleMobileAds
import os

/// Asks for App Tracking Transparency permission, then starts the Google Mobile Ads SDK.
///
/// The ATT prompt is only shown while the app is active, so call `appDidBecomeActive()`
/// when the scene becomes active, not from `App.init`. Banners should load only after `adsStarted`.
@MainActor
final class AdsStarter: ObservableObject {
    private static let logger = Logger()

    @Published private(set) var adsStarted = false
    private var isStarting = false

    func appDidBecomeActive() async {
        guard !adsStarted, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        var status = ATTrackingManager.trackingAuthorizationStatus
        if status == .notDetermined {
            status = await ATTrackingManager.requestTrackingAuthorization()
            if status == .notDetermined {
                // The prompt can be skipped when it is requested right as the app becomes active. Retry once.
                try? await Task.sleep(for: .seconds(1))
                status = await ATTrackingManager.requestTrackingAuthorization()
            }
        }
        AdsStarter.logger.log("ATT status=\(status.rawValue, privacy: .public)")

        // Start whatever the answer. Without authorization the SDK serves ads without the IDFA.
        // If the status is still undetermined, the next launch asks again.
        // Wait for the SDK (and any mediation adapters) to finish setting up before the banner loads.
        _ = await MobileAds.shared.start()
        adsStarted = true
    }
}

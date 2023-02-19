//
//  BannerAd.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 2/6/23.
//

import Foundation
import SwiftUI

struct BannerAd: UIViewControllerRepresentable {
    // For testing, check the demo ad unit ID in https://developers.google.com/admob/ios/test-ads
    let adUnitId = "ca-app-pub-6771077591139198/7386863365"
        
    init() {
    }
    
    func makeUIViewController(context: Context) -> BannerAdViewController {
        return BannerAdViewController(adUnitId: adUnitId)
    }

    func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {
        
    }
}

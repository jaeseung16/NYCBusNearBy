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
    let adUnitId = "ca-app-pub-3940256099942544/2934735716"
        
    init() {
    }
    
    func makeUIViewController(context: Context) -> BannerAdViewController {
        return BannerAdViewController(adUnitId: adUnitId)
    }

    func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {
        
    }
}

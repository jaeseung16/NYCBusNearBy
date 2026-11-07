//
//  MTABusFeedConstant.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

struct MTAFeedConstant {
    /// The `?key=` query for the MTA Bus Time feeds.
    ///
    /// The key comes from `MTA_BUS_TIME_API_KEY` in `Config/Secrets.xcconfig` (git-ignored), through the
    /// `MTABusTimeAPIKey` entry in Info.plist. It is empty if the key is missing.
    static let apiKey: String = {
        let key = (Bundle.main.object(forInfoDictionaryKey: "MTABusTimeAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return key.isEmpty ? "" : "?key=\(key)"
    }()
}

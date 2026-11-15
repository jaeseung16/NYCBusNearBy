//
//  MTABusStopRowView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 4/26/24.
//

import SwiftUI
import MapKit

struct BusStopRowView: View {
    
    private let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(width: .abbreviated,
                                                                          usage: .asProvided,
                                                                          numberFormatStyle: .number.precision(.fractionLength(1)))
    
    /// The stop's name, or the favorite's nickname.
    var title: String
    var stopId: String
    /// `nil` when there's no location fix.
    var distance: Measurement<UnitLength>?
    var distanceUnit: DistanceUnit
    var isFavorite = false
    /// A favorite whose stop is no longer in the stop data.
    var isUnavailable = false
    
    var body: some View {
        HStack {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
            
            Text(title)
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text(stopId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isUnavailable {
                    Text("No longer served")
                        .font(.caption)
                } else if let distance {
                    Text(distance.converted(to: distanceUnit.unitLength), format: distanceFormatStyle)
                }
            }
        }
        .foregroundStyle(isUnavailable ? .secondary : .primary)
    }

}

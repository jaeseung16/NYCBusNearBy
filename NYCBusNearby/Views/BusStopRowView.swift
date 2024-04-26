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
    
    var stop: MTABusStop
    var distance: Measurement<UnitLength>
    var distanceUnit: DistanceUnit
    
    var body: some View {
        HStack {
            Text("\(stop.name)")
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text("\(stop.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(distance.converted(to: distanceUnit.unitLength), format: distanceFormatStyle)
            }
        }
    }

}

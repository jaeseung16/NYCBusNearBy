//
//  BusAtStopView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 4/28/24.
//

import SwiftUI

struct BusAtStopView: View {
    
    var bus: MTABus
    var arrivalTime: Date
    var hasAlert = false
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                Text(bus.routeId ?? "")
                
                if hasAlert {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Service alert")
                }
                
                Spacer()
                
                Text(bus.headsign ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            if bus.isCanceled {
                HStack {
                    Text("Canceled")
                        .bold()
                        .foregroundStyle(.red)
                    Text(arrivalTime, style: .time)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
            } else if Date().distance(to: arrivalTime) > 15*60 {
                Text(arrivalTime, style: .time)
                    .foregroundColor(.secondary)
            } else {
                Text(timeInterval(to: arrivalTime))
                    .foregroundColor(arrivalTime < Date() ? .secondary : .primary)
            }
        }
    }
    
    private func timeInterval(to arrivalTime: Date) -> String {
        return RelativeDateTimeFormatter().localizedString(for: arrivalTime, relativeTo: Date())
    }
}

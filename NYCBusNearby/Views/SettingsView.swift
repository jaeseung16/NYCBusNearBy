//
//  Settings.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/16/23.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var distanceUnit: DistanceUnit
    @Binding var distance: Double
    @Binding var maxComing: TimeInterval
    
    private var distanceFormatStyle: Measurement<UnitLength>.FormatStyle {
        .measurement(width: .abbreviated,
                     usage: .asProvided,
                     numberFormatStyle: .number.precision(.fractionLength(1)))
    }
    
    private let minDistance: Double = 100
    private let maxDistance: Double = 3000
    private var kmSelected: Bool {
        distanceUnit == .km
    }
    
    private let minArrivalTimeInMinute: TimeInterval = 1 * 60
    private let maxArrivalTimeInMinute: TimeInterval = 60 * 60
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                distanceSetting
                    .frame(maxWidth: 0.9 * geometry.size.width)
                
                Divider()
                
                arrivalTimeSetting
                    .frame(maxWidth: 0.9 * geometry.size.width)
                
                Divider()
                
                Button("Dismiss") {
                    dismiss()
                }
                
                Spacer()
            }
        }
        
    }
    
    private var distanceSetting: some View {
        VStack {
            HStack {
                Text("Distance Limit: ")
                if kmSelected {
                    distanceText(distance, distanceUnit: .km)
                } else {
                    distanceText(distance, distanceUnit: .mile)
                }
            }
            .font(.title3)
            .frame(maxHeight: 100)
            
            Slider(value: $distance, in: minDistance...maxDistance) {
                Text("Distance Limit")
            } minimumValueLabel: {
                if kmSelected {
                    distanceText(minDistance, distanceUnit: .km)
                } else {
                    distanceText(minDistance, distanceUnit: .mile)
                }
            } maximumValueLabel: {
                if kmSelected {
                    distanceText(maxDistance, distanceUnit: .km)
                } else {
                    distanceText(maxDistance, distanceUnit: .mile)
                }
            }
            
            HStack {
                Spacer()
                List {
                    Picker("Unit", selection: $distanceUnit) {
                        Text("kilometers").tag(DistanceUnit.km)
                        Text("miles").tag(DistanceUnit.mile)
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 100)
                Spacer()
            }
            
        }
    }
    
    private func distanceText(_ distance: Double, distanceUnit: DistanceUnit) -> Text {
        Text(Measurement(value: distance, unit: UnitLength.meters).converted(to: distanceUnit.unitLength), format: distanceFormatStyle)
    }
    
    private var arrivalTimeSetting: some View {
        VStack {
            HStack {
                Text("Time Limit: \(Int(maxComing / 60.0)) minute(s)")
            }
            .font(.title3)
            .frame(maxHeight: 100)
            
            Slider(value: $maxComing, in: minArrivalTimeInMinute...maxArrivalTimeInMinute) {
                Text("Time Limit")
                
            } minimumValueLabel: {
                Text("1 min")
            } maximumValueLabel: {
                Text("1 hour")
            }
        }
    }
}


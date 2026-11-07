//
//  ServiceAlertsView.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 11/7/26.
//

import SwiftUI
import MTAFeed

/// A button that shows the number of service alerts and opens them in a sheet. Shows nothing when there are none.
struct ServiceAlertsButton: View {
    var alerts: [MTAAlert]

    @State private var presentAlerts = false

    var body: some View {
        if !alerts.isEmpty {
            Button {
                presentAlerts = true
            } label: {
                Label(alerts.count == 1 ? "1 service alert" : "\(alerts.count) service alerts",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .sheet(isPresented: $presentAlerts) {
                ServiceAlertsView(alerts: alerts)
            }
        }
    }
}

struct ServiceAlertsView: View {
    @Environment(\.dismiss) private var dismiss

    var alerts: [MTAAlert]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(alert.routeIds.sorted().joined(separator: " · "))
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.orange)

                        Text(alert.plainHeaderText)
                            .font(.headline)

                        if let description = alert.plainDescriptionText {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Service Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

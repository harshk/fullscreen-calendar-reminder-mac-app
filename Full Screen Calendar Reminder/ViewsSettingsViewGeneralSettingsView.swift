//
//  GeneralSettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                
                Stepper(
                    "Events in Menu Bar: \(settings.numberOfEventsInMenuBar)",
                    value: $settings.numberOfEventsInMenuBar,
                    in: 1...50
                )
            } header: {
                Text("General")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pause Behavior")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("When full-screen reminders are paused, alerts are silently skipped rather than queued. Events that would have fired during the pause period will not trigger alerts when you unpause.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Toggle("Enable Pre-Alert", isOn: $settings.preAlertEnabled)

                if settings.preAlertEnabled {
                    Picker("Lead Time", selection: $settings.preAlertLeadTime) {
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                        Text("3 minutes").tag(180.0)
                        Text("5 minutes").tag(300.0)
                    }

                    Picker("Glow Duration", selection: $settings.preAlertGlowDuration) {
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                    }

                    Picker("Banner Duration", selection: $settings.preAlertBannerDuration) {
                        Text("Until event starts").tag(0.0)
                        Text("10 seconds").tag(10.0)
                        Text("20 seconds").tag(20.0)
                        Text("30 seconds").tag(30.0)
                    }

                    Button("Test Pre-Alert") {
                        PreAlertManager.shared.showTestPreAlert()
                    }
                }
            } header: {
                Text("Pre-Alert")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}

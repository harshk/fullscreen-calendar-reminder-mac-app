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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snooze Durations")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Choose which snooze options appear on the full-screen alert.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(snoozeOptions, id: \.value) { option in
                    Toggle(option.label, isOn: Binding(
                        get: { settings.snoozeDurations.contains(option.value) },
                        set: { enabled in
                            if enabled {
                                if !settings.snoozeDurations.contains(option.value) {
                                    settings.snoozeDurations.append(option.value)
                                    settings.snoozeDurations.sort()
                                }
                            } else {
                                settings.snoozeDurations.removeAll { $0 == option.value }
                            }
                        }
                    ))
                }
            } header: {
                Text("Snooze")
                    .font(.headline)
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

                    Picker("Duration", selection: $settings.preAlertDuration) {
                        Text("Until event starts").tag(0.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                    }

                    Button("Show Preview: Pre-Alert") {
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

private let snoozeOptions: [(label: String, value: Double)] = [
    ("1 minute", 60),
    ("5 minutes", 300),
    ("10 minutes", 600),
    ("15 minutes", 900),
    ("30 minutes", 1800),
]

#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}

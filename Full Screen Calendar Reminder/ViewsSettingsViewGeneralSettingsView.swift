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
                
                HStack {
                    Text("Number of Events in Menu Bar")
                    Spacer()
                    TextField("", value: Binding(
                        get: { settings.numberOfEventsInMenuBar },
                        set: { settings.numberOfEventsInMenuBar = max(1, $0) }
                    ), format: .number)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("General")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snooze Durations")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Set the duration in minutes for each snooze button on the full-screen alert.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(0..<3, id: \.self) { index in
                    HStack {
                        Text("Button \(index + 1)")
                        Spacer()
                        TextField("Min", value: Binding(
                            get: { Int(settings.snoozeDurations[index] / 60) },
                            set: { newValue in
                                settings.snoozeDurations[index] = Double(max(1, newValue)) * 60
                            }
                        ), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Snooze")
                    .font(.headline)
            }

            Section {
                Toggle("Enable Pre-Alert", isOn: $settings.preAlertEnabled)

                if settings.preAlertEnabled {
                    HStack {
                        Text("Lead Time")
                        Spacer()
                        TextField("Sec", value: Binding(
                            get: { Int(settings.preAlertLeadTime) },
                            set: { settings.preAlertLeadTime = Double(max(1, $0)) }
                        ), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        Text("sec")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Duration")
                            Text("Set to 0 to persist until event starts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TextField("Sec", value: Binding(
                            get: { Int(settings.preAlertDuration) },
                            set: { settings.preAlertDuration = Double(max(0, $0)) }
                        ), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        Text("sec")
                            .foregroundColor(.secondary)
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


#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}

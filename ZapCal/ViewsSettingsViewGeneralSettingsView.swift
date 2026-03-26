//
//  GeneralSettingsView.swift
//  ZapCal
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
                    Text("Number of Events to display in Menu Bar")
                    Spacer()
                    TextField("", text: Binding(
                        get: { String(settings.numberOfEventsInMenuBar) },
                        set: { newValue in
                            let filtered = String(newValue.filter(\.isNumber).prefix(2))
                            if let num = Int(filtered), num >= 1 {
                                settings.numberOfEventsInMenuBar = min(99, num)
                            }
                        }
                    ))
                    .frame(width: 40)
                    .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("General")
                    .font(.headline)
            }

            Section {
                Toggle("Enable", isOn: $settings.eventAlarmAlertsEnabled)

                if settings.eventAlarmAlertsEnabled {
                    Picker("Alert Type", selection: $settings.eventAlarmAlertStyle) {
                        ForEach(AlertStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }

                    if settings.eventAlarmAlertStyle == .subtle {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Duration")
                                Text("Set to 0 to persist until event starts.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            TextField("Sec", value: Binding(
                                get: { Int(settings.eventAlarmAlertDuration) },
                                set: { settings.eventAlarmAlertDuration = Double(max(0, $0)) }
                            ), format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            Text("sec")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Reminder Alerts")
                        .font(.headline)
                    Text("When enabled, ZapCal will show an alert at the exact time a calendar event's reminder is set to trigger.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                ForEach(0..<3, id: \.self) { index in
                    HStack {
                        Text("Snooze Button \(index + 1)")
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
                Text("Full Screen Alert Snooze Button Durations")
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

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

            alertSection(
                title: "First Alert",
                enabled: $settings.firstAlertEnabled,
                style: $settings.firstAlertStyle,
                leadTime: $settings.firstAlertLeadTime,
                duration: $settings.firstAlertDuration
            )

            alertSection(
                title: "Second Alert",
                enabled: $settings.secondAlertEnabled,
                style: $settings.secondAlertStyle,
                leadTime: $settings.secondAlertLeadTime,
                duration: $settings.secondAlertDuration
            )
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func alertSection(
        title: String,
        enabled: Binding<Bool>,
        style: Binding<AlertStyle>,
        leadTime: Binding<Double>,
        duration: Binding<Double>
    ) -> some View {
        Section {
            Toggle("Enable", isOn: enabled)

            if enabled.wrappedValue {
                Picker("Alert Type", selection: style) {
                    ForEach(AlertStyle.allCases) { alertStyle in
                        Text(alertStyle.label).tag(alertStyle)
                    }
                }

                HStack {
                    Text("Lead Time")
                    Spacer()
                    TextField("Min", value: Binding(
                        get: { Int(leadTime.wrappedValue / 60) },
                        set: { leadTime.wrappedValue = Double(max(0, $0)) * 60 }
                    ), format: .number)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    Text("min")
                        .foregroundColor(.secondary)
                }

                if style.wrappedValue == .subtle {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Duration")
                            Text("Set to 0 to persist until event starts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TextField("Sec", value: Binding(
                            get: { Int(duration.wrappedValue) },
                            set: { duration.wrappedValue = Double(max(0, $0)) }
                        ), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        Text("sec")
                            .foregroundColor(.secondary)
                    }

                    Button("Show Preview: Subtle Alert") {
                        PreAlertManager.shared.showTestPreAlert()
                    }
                }

                if style.wrappedValue == .fullScreen {
                    Button("Show Preview: Full Screen Alert") {
                        AlertCoordinator.shared.showPreviewAlert(theme: ThemeService.shared.getTheme(for: nil))
                    }
                }
            }
        } header: {
            Text(title)
                .font(.headline)
        }
    }
}


#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}

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
            } header: {
                Text("General")
                    .font(.headline)
            }

            ForEach(Array(settings.alertConfigs.enumerated()), id: \.element.id) { index, config in
                Section {
                    HStack {
                        Toggle("Enable", isOn: Binding(
                            get: { config.enabled },
                            set: { settings.alertConfigs[index].enabled = $0 }
                        ))

                        Spacer()

                        if settings.alertConfigs.count > 1 {
                            Button(role: .destructive) {
                                settings.alertConfigs.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if config.enabled {
                        Picker("Alert Type", selection: Binding(
                            get: { config.style },
                            set: { settings.alertConfigs[index].style = $0 }
                        )) {
                            ForEach(AlertStyle.allCases) { style in
                                Text(style.label).tag(style)
                            }
                        }

                        HStack {
                            Text("Lead Time")
                            Spacer()
                            TextField("Min", value: Binding(
                                get: { Int(config.leadTime / 60) },
                                set: { settings.alertConfigs[index].leadTime = Double(max(0, $0)) * 60 }
                            ), format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            Text("min")
                                .foregroundColor(.secondary)
                        }

                        if config.style == .subtle {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Duration")
                                    Text("Set to 0 to persist until event starts.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                TextField("Sec", value: Binding(
                                    get: { Int(config.subtleDuration) },
                                    set: { settings.alertConfigs[index].subtleDuration = Double(max(0, $0)) }
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

                        if config.style == .fullScreen {
                            Button("Show Preview: Full Screen Alert") {
                                AlertCoordinator.shared.showPreviewAlert(theme: ThemeService.shared.getTheme(for: nil))
                            }
                        }
                    }
                } header: {
                    Text("Alert \(index + 1)")
                        .font(.headline)
                }
            }

            Section {
                Button {
                    settings.alertConfigs.append(AlertConfig())
                } label: {
                    Label("Add Alert", systemImage: "plus.circle")
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
                Text("Snooze Durations")
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

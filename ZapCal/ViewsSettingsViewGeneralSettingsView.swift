//
//  GeneralSettingsView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var deleteAlertIndex: Int? = nil
    @State private var editAlertIndex: Int? = nil

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
                    Toggle("Enable", isOn: Binding(
                        get: { config.enabled },
                        set: { settings.alertConfigs[index].enabled = $0 }
                    ))

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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alert Settings")
                                Text(alertSettingsSummary(for: config))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                editAlertIndex = index
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Alert \(index + 1)")
                            .font(.headline)
                        if settings.alertConfigs.count > 1 {
                            Button {
                                deleteAlertIndex = index
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
        .alert("Delete Alert?", isPresented: Binding(
            get: { deleteAlertIndex != nil },
            set: { if !$0 { deleteAlertIndex = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteAlertIndex = nil }
            Button("Delete", role: .destructive) {
                if let index = deleteAlertIndex {
                    settings.alertConfigs.remove(at: index)
                }
                deleteAlertIndex = nil
            }
        } message: {
            if let index = deleteAlertIndex {
                Text("Are you sure you want to delete Alert \(index + 1)?")
            }
        }
        .sheet(isPresented: Binding(
            get: { editAlertIndex != nil },
            set: { if !$0 { editAlertIndex = nil } }
        )) {
            if let index = editAlertIndex {
                AlertSettingsSheet(
                    config: Binding(
                        get: { settings.alertConfigs[index] },
                        set: { settings.alertConfigs[index] = $0 }
                    )
                )
            }
        }
    }

    private func alertSettingsSummary(for config: AlertConfig) -> String {
        let leadMinutes = Int(config.leadTime / 60)
        let leadText = "Lead time: \(leadMinutes) min"
        if config.style == .subtle {
            let durText = config.subtleDuration == 0
                ? "persists until event"
                : "\(Int(config.subtleDuration)) sec"
            return "\(leadText)\nDuration: \(durText)"
        }
        return leadText
    }
}

// MARK: - Alert Settings Sheet

struct AlertSettingsSheet: View {
    @Binding var config: AlertConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(config.style.label) Settings")
                .font(.headline)

            HStack {
                Text("Lead Time")
                Spacer()
                TextField("Min", value: Binding(
                    get: { Int(config.leadTime / 60) },
                    set: { config.leadTime = Double(max(0, $0)) * 60 }
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
                        set: { config.subtleDuration = Double(max(0, $0)) }
                    ), format: .number)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    Text("sec")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if config.style == .subtle {
                Button("Show Preview: Subtle Alert") {
                    PreAlertManager.shared.showTestPreAlert()
                }
            } else {
                Button("Show Preview: Full Screen Alert") {
                    AlertCoordinator.shared.showPreviewAlert(theme: ThemeService.shared.getTheme(for: nil))
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350)
    }
}


#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}

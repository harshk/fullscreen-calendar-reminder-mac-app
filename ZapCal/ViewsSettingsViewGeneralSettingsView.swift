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
                        AlertStylePicker(selection: Binding(
                            get: { config.style },
                            set: { settings.alertConfigs[index].style = $0 }
                        ))

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


// MARK: - Alert Style Picker

struct AlertStylePicker: View {
    @Binding var selection: AlertStyle

    var body: some View {
        HStack(spacing: 12) {
            alertStyleCard(style: .subtle)
            alertStyleCard(style: .fullScreen)
        }
        .padding(.vertical, 4)
    }

    private func alertStyleCard(style: AlertStyle) -> some View {
        let isSelected = selection == style

        return Button {
            selection = style
        } label: {
            VStack(spacing: 8) {
                // Mini preview
                if style == .subtle {
                    subtlePreview
                } else {
                    fullScreenPreview
                }

                Text(style.label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // Mini subtle alert banner preview
    private var subtlePreview: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 14, height: 14)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.5))
                    .frame(width: 70, height: 5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 45, height: 4)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
        .frame(height: 40)
    }

    // Mini full screen alert preview
    private var fullScreenPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 50, height: 5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 30, height: 4)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 20, height: 8)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(height: 40)
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 800, height: 600)
}

//
//  MenuBarPresetSettingsView.swift
//  ZapCal
//

import SwiftUI

struct MenuBarPresetSettingsView: View {
    @ObservedObject private var presetManager = PreAlertPresetManager.shared
    @ObservedObject private var settings = AppSettings.shared

    private var theme: PreAlertTheme {
        PreAlertPresetManager.shared.theme(named: settings.menuBarPresetName)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Preset list
            VStack(alignment: .leading, spacing: 0) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                List(selection: $settings.menuBarPresetName) {
                    Section("Built-in Presets") {
                        ForEach(presetManager.presets.filter { presetManager.isBuiltIn($0.name) }) { preset in
                            presetRow(preset)
                        }
                    }

                    let customPresets = presetManager.presets.filter { !presetManager.isBuiltIn($0.name) }
                    if !customPresets.isEmpty {
                        Section("Custom Presets") {
                            ForEach(customPresets) { preset in
                                presetRow(preset)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            .frame(width: 220)

            Divider()

            // Preview
            VStack(spacing: 0) {
                Text("Preview")
                    .font(.headline)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                menuBarPreview
                    .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preset Row

    private func presetRow(_ preset: PreAlertPresetTheme) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(preset.theme.backgroundColor.color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text(preset.name)
                .lineLimit(1)

            Spacer()

            if preset.name == settings.menuBarPresetName {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .tag(preset.name)
    }

    // MARK: - Menu Bar Preview

    private var menuBarPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuBarDateHeader(title: "Today — Mar 25", theme: theme)

            MenuBarEventContent(
                time: "10:00 AM",
                title: "Team Standup",
                location: "Conference Room B",
                calendarColor: .blue,
                theme: theme
            )

            MenuBarEventContent(
                time: "1:30 PM",
                title: "Design Review",
                hasVideoCall: true,
                calendarColor: .purple,
                theme: theme
            )

            MenuBarDateHeader(title: "Tomorrow — Mar 26", theme: theme)

            MenuBarSubtitleRow(
                time: "9:00 AM",
                title: "Review pull requests",
                subtitle: "Reminders",
                icon: "checklist",
                theme: theme
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

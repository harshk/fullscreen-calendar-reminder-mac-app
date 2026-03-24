//
//  RemindersSettingsView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/24/26.
//

import SwiftUI
import EventKit

struct RemindersSettingsView: View {
    @ObservedObject var remindersService = AppleRemindersService.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var themeService = ThemeService.shared
    @ObservedObject var presetManager = PresetManager.shared
    @ObservedObject var preAlertPresetManager = PreAlertPresetManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle("Enable Apple Reminders", isOn: $settings.appleRemindersEnabled)
                .padding()
                .onChange(of: settings.appleRemindersEnabled) { _, enabled in
                    if enabled && !remindersService.hasAccess {
                        Task { try? await remindersService.requestAccess() }
                    } else if enabled && remindersService.hasAccess {
                        Task {
                            await remindersService.loadReminderLists()
                            remindersService.startPolling()
                        }
                    } else if !enabled {
                        remindersService.stopPolling()
                    }
                }

            Divider()

            if settings.appleRemindersEnabled {
                if remindersService.permissionDenied {
                    noAccessView
                } else if !remindersService.hasAccess {
                    requestAccessView
                } else if remindersService.availableReminderLists.isEmpty {
                    noListsView
                } else {
                    reminderListsView
                }
            } else {
                disabledView
            }
        }
        .padding()
    }

    // MARK: - State Views

    private var disabledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Apple Reminders Disabled")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Enable the toggle above to receive full-screen alerts for your Apple Reminders.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist.unchecked")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Reminders Access Required")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Grant reminders access in System Settings to select reminder lists.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                openSystemSettingsRemindersPrivacy()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var requestAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Reminders Access Required")
                .font(.title3)
                .fontWeight(.semibold)

            Text("ZapCal needs access to your reminders to display full-screen alerts when they're due.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Reminders Access") {
                Task { try? await remindersService.requestAccess() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noListsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Reminder Lists Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Create reminder lists in the Reminders app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Reminder Lists View

    private var reminderListsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if settings.selectedReminderListIdentifiers.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No reminder lists selected. You won't receive alerts for Apple Reminders.")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedLists, id: \.source) { group in
                        reminderListGroup(group)
                    }
                }
            }
        }
    }

    // MARK: - List Group

    @ViewBuilder
    private func reminderListGroup(_ group: (source: String, lists: [EKCalendar])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(group.source)
                    .font(.headline)

                Spacer()

                Button(allSelected(group.lists) ? "Deselect All" : "Select All") {
                    toggleAll(group.lists)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))

            ForEach(group.lists, id: \.calendarIdentifier) { list in
                reminderListRow(list)
            }

            Divider()
                .padding(.top, 8)
        }
    }

    // MARK: - List Row

    @ViewBuilder
    private func reminderListRow(_ list: EKCalendar) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { settings.selectedReminderListIdentifiers.contains(list.calendarIdentifier) },
                set: { isSelected in
                    if isSelected {
                        settings.selectedReminderListIdentifiers.insert(list.calendarIdentifier)
                    } else {
                        settings.selectedReminderListIdentifiers.remove(list.calendarIdentifier)
                    }
                }
            ))
            .labelsHidden()

            if let cgColor = list.cgColor {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(cgColor: cgColor))
                    .frame(width: 20, height: 20)
            }

            Text(list.title)
                .font(.subheadline)

            Spacer()

            if settings.selectedReminderListIdentifiers.contains(list.calendarIdentifier) {
                Text("Preset:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Preset", selection: Binding(
                    get: { themeService.assignedPresetName(for: list.calendarIdentifier) },
                    set: { themeService.setPreset($0, for: list.calendarIdentifier) }
                )) {
                    ForEach(presetManager.presets) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                }
                .frame(width: 150)
                .labelsHidden()

                Text("Pre-Alert:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Pre-Alert", selection: Binding(
                    get: { themeService.assignedPreAlertPresetName(for: list.calendarIdentifier) },
                    set: { themeService.setPreAlertPreset($0, for: list.calendarIdentifier) }
                )) {
                    ForEach(preAlertPresetManager.presets) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                }
                .frame(width: 150)
                .labelsHidden()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var groupedLists: [(source: String, lists: [EKCalendar])] {
        let grouped = Dictionary(grouping: remindersService.availableReminderLists) { $0.source.title }
        return grouped.sorted { $0.key < $1.key }.map { (source: $0.key, lists: $0.value) }
    }

    private func allSelected(_ lists: [EKCalendar]) -> Bool {
        lists.allSatisfy { settings.selectedReminderListIdentifiers.contains($0.calendarIdentifier) }
    }

    private func toggleAll(_ lists: [EKCalendar]) {
        if allSelected(lists) {
            for list in lists {
                settings.selectedReminderListIdentifiers.remove(list.calendarIdentifier)
            }
        } else {
            for list in lists {
                settings.selectedReminderListIdentifiers.insert(list.calendarIdentifier)
            }
        }
    }

    private func openSystemSettingsRemindersPrivacy() {
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Reminders") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }
}

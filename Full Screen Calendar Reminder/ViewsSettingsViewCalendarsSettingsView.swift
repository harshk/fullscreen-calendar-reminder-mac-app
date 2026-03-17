//
//  CalendarsSettingsView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import EventKit

struct CalendarsSettingsView: View {
    @ObservedObject var calendarService = CalendarService.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var themeService = ThemeService.shared
    @ObservedObject var presetManager = PresetManager.shared
    @ObservedObject var preAlertPresetManager = PreAlertPresetManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !calendarService.hasAccess {
                noAccessView
            } else if calendarService.availableCalendars.isEmpty {
                noCalendarsView
            } else {
                calendarsListView
            }
        }
        .padding()
    }
    
    // MARK: - No Access View
    
    private var noAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Calendar Access Required")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Grant calendar access to select calendars for full-screen alerts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open System Settings") {
                openSystemSettingsCalendarPrivacy()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Calendars View
    
    private var noCalendarsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Calendars Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Add calendars in System Settings → Internet Accounts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Calendars List View
    
    private var calendarsListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if settings.selectedCalendarIdentifiers.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No calendars selected. You won't receive any full-screen alerts.")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedCalendars, id: \.source) { group in
                        calendarGroup(group)
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar Group
    
    @ViewBuilder
    private func calendarGroup(_ group: (source: String, calendars: [EKCalendar])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source header
            HStack {
                Text(group.source)
                    .font(.headline)
                
                Spacer()
                
                Button(allSelected(group.calendars) ? "Deselect All" : "Select All") {
                    toggleAll(group.calendars)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            
            // Calendars
            ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                calendarRow(calendar)
            }
            
            Divider()
                .padding(.top, 8)
        }
    }
    
    // MARK: - Calendar Row
    
    @ViewBuilder
    private func calendarRow(_ calendar: EKCalendar) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { settings.selectedCalendarIdentifiers.contains(calendar.calendarIdentifier) },
                set: { isSelected in
                    if isSelected {
                        settings.selectedCalendarIdentifiers.insert(calendar.calendarIdentifier)
                    } else {
                        settings.selectedCalendarIdentifiers.remove(calendar.calendarIdentifier)
                    }
                }
            ))
            .labelsHidden()
            
            // Color swatch
            if let cgColor = calendar.cgColor {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(cgColor: cgColor))
                    .frame(width: 20, height: 20)
            }
            
            Text(calendar.title)
                .font(.subheadline)

            Spacer()

            if settings.selectedCalendarIdentifiers.contains(calendar.calendarIdentifier) {
                Text("Preset:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Preset", selection: Binding(
                    get: { themeService.assignedPresetName(for: calendar.calendarIdentifier) },
                    set: { themeService.setPreset($0, for: calendar.calendarIdentifier) }
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
                    get: { themeService.assignedPreAlertPresetName(for: calendar.calendarIdentifier) },
                    set: { themeService.setPreAlertPreset($0, for: calendar.calendarIdentifier) }
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
    
    // MARK: - Helper Functions
    
    private var groupedCalendars: [(source: String, calendars: [EKCalendar])] {
        let grouped = Dictionary(grouping: calendarService.availableCalendars) { calendar in
            calendar.source.title
        }
        
        return grouped.sorted { $0.key < $1.key }.map { (source: $0.key, calendars: $0.value) }
    }
    
    private func allSelected(_ calendars: [EKCalendar]) -> Bool {
        calendars.allSatisfy { settings.selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
    }
    
    private func toggleAll(_ calendars: [EKCalendar]) {
        if allSelected(calendars) {
            for calendar in calendars {
                settings.selectedCalendarIdentifiers.remove(calendar.calendarIdentifier)
            }
        } else {
            for calendar in calendars {
                settings.selectedCalendarIdentifiers.insert(calendar.calendarIdentifier)
            }
        }
    }
    
    private func openSystemSettingsCalendarPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    CalendarsSettingsView()
        .frame(width: 800, height: 600)
}

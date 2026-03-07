//
//  MenuBarView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var calendarService = CalendarService.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var showingAddReminder = false
    @State private var showingManageReminders = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !calendarService.hasAccess {
                noAccessView
            } else if settings.selectedCalendarIdentifiers.isEmpty {
                noCalendarsSelectedView
            } else {
                upcomingEventsSection
            }
            
            Divider()
            
            menuActions
        }
        .frame(width: 350)
    }
    
    // MARK: - No Access View
    
    private var noAccessView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Calendar Access Required")
                .font(.headline)
            
            Text("Grant calendar access to receive full-screen alerts for your events.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Request Calendar Access") {
                // Show immediate alert to prove button works
                let alert = NSAlert()
                alert.messageText = "Button Clicked!"
                alert.informativeText = "The button is working. Now requesting calendar access..."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                print("Button clicked!")
                Task { @MainActor in
                    print("Task started on MainActor")
                    do {
                        print("About to call requestAccess()")
                        try await CalendarService.shared.requestAccess()
                        print("requestAccess() completed successfully")
                        
                        // Show success alert
                        let successAlert = NSAlert()
                        successAlert.messageText = "Access Granted!"
                        successAlert.informativeText = "Calendar access was granted successfully."
                        successAlert.alertStyle = .informational
                        successAlert.addButton(withTitle: "OK")
                        successAlert.runModal()
                    } catch {
                        print("Error in button handler: \(error)")
                        
                        // Show error alert
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "Error"
                        errorAlert.informativeText = "Failed to request access: \(error.localizedDescription)"
                        errorAlert.alertStyle = .critical
                        errorAlert.addButton(withTitle: "OK")
                        errorAlert.runModal()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Open System Settings") {
                openSystemSettingsCalendarPrivacy()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - No Calendars Selected View
    
    private var noCalendarsSelectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Calendars Selected")
                .font(.headline)
            
            Text("Select calendars in Settings to receive alerts.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Upcoming Events Section
    
    private var upcomingEventsSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if calendarService.upcomingEvents.isEmpty {
                    noUpcomingEventsView
                } else {
                    eventsList
                }
            }
        }
        .frame(maxHeight: 400)
    }
    
    private var noUpcomingEventsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            
            Text("No Upcoming Events")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var eventsList: some View {
        ForEach(groupedEvents, id: \.date) { group in
            VStack(alignment: .leading, spacing: 0) {
                // Date Header
                Text(formatDateHeader(group.date))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                
                // Events for this date
                ForEach(group.events) { event in
                    EventRow(event: event)
                }
            }
        }
    }
    
    // MARK: - Menu Actions
    
    private var menuActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Add Full Screen Reminder") {
                showingAddReminder = true
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }
            
            Button("Manage Reminders") {
                showingManageReminders = true
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $showingManageReminders) {
                ManageRemindersView()
            }
            
            Divider()
            
            Button(settings.isPaused ? "Unpause Full Screen Reminders" : "Pause Full Screen Reminders") {
                settings.isPaused.toggle()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            Button("Settings") {
                showingSettings = true
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            
            Button("Quit Full Screen Calendar Reminder") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Helper Functions
    
    private var groupedEvents: [(date: Date, events: [CalendarEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: calendarService.upcomingEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
        
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, events: $0.value) }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today — \(formatDate(date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow — \(formatDate(date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }
    
    private func openSystemSettingsCalendarPrivacy() {
        // Try modern macOS Ventura+ URL scheme first
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // Fallback to older URL schemes
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        
        for urlString in urlStrings {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 8) {
            // Time
            Text(formatTime(event.startDate))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .lineLimit(2)
                
                if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                if event.videoConferenceURL != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                        Text("Video Call")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Join button for video calls
            if let url = event.videoConferenceURL {
                Button("Join") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(event.calendar.color.opacity(0.1))
        .contentShape(Rectangle())
        .onTapGesture {
            CalendarService.shared.openEventInCalendarApp(event)
        }
        .contextMenu {
            Button("Preview Full Screen Alert") {
                AlertCoordinator.shared.showPreviewAlert(for: event)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
}

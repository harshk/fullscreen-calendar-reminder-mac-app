//
//  MenuBarView.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit

// MARK: - Menu Bar List Item

enum MenuBarListItem: Identifiable {
    case calendarEvent(CalendarEvent)
    case customReminder(CustomReminder)

    var id: String {
        switch self {
        case .calendarEvent(let e): return "event-\(e.id)"
        case .customReminder(let r): return "reminder-\(r.id.uuidString)"
        }
    }

    var startDate: Date {
        switch self {
        case .calendarEvent(let e): return e.startDate
        case .customReminder(let r): return r.scheduledDate
        }
    }

    var title: String {
        switch self {
        case .calendarEvent(let e): return e.title
        case .customReminder(let r): return r.title
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var calendarService = CalendarService.shared
    @ObservedObject var reminderService = ReminderService.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var showingAddReminder = false
    @State private var showingAddReminderInfo = false
    @State private var showingManageReminders = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App name and settings gear
            HStack {
                Text("Full Screen Calendar Reminder")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.leading, 12)
                Spacer()
                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
            .frame(height: 32)

            if !calendarService.hasAccess {
                noAccessView
            } else if settings.selectedCalendarIdentifiers.isEmpty {
                noCalendarsSelectedView
            } else {
                upcomingEventsSection
            }

            Divider()
                .padding(.horizontal, 10)

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
                openSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Upcoming Events Section
    
    private var upcomingEventsSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if groupedItems.isEmpty {
                    noUpcomingEventsView
                } else {
                    itemsList
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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
    
    private var itemsList: some View {
        ForEach(groupedItems, id: \.date) { group in
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

                // Items for this date
                ForEach(group.items) { item in
                    switch item {
                    case .calendarEvent(let event):
                        EventRow(event: event)
                    case .customReminder(let reminder):
                        MenuBarReminderRow(reminder: reminder)
                    }
                }
            }
        }
    }
    
    // MARK: - Menu Actions
    
    private var menuActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Add Full Screen Reminder") {
                    showingAddReminder = true
                }
                .buttonStyle(.plain)

                Button(action: { showingAddReminderInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingAddReminderInfo) {
                    Text("Adds a Full Screen reminder without having to add an event to your calendar.")
                        .font(.caption)
                        .padding(8)
                        .frame(width: 200)
                }
            }
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
                .padding(.horizontal, 10)

            Button(settings.isPaused ? "Unpause Full Screen Reminders" : "Pause Full Screen Reminders") {
                settings.isPaused.toggle()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .padding(.horizontal, 10)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Helper Functions
    
    private var groupedItems: [(date: Date, items: [MenuBarListItem])] {
        let cal = Calendar.current
        var allItems: [MenuBarListItem] = calendarService.upcomingEvents.map { .calendarEvent($0) }
        allItems += reminderService.upcomingReminders.map { .customReminder($0) }
        allItems.sort { $0.startDate < $1.startDate }

        let grouped = Dictionary(grouping: allItems) { item in
            cal.startOfDay(for: item.startDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, items: $0.value) }
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

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
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
    @ObservedObject private var calendarService = CalendarService.shared
    @State private var showingDisabledPopover = false

    private var isDisabled: Bool {
        calendarService.isEventDisabled(event.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Disabled indicator
            if isDisabled {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
                    .popover(isPresented: $showingDisabledPopover) {
                        VStack(spacing: 8) {
                            Text("Alerts for this event have been disabled.")
                                .font(.caption)
                            Button(AppStrings.reEnableAlertsForEvent) {
                                CalendarService.shared.reEnableEvent(event.id)
                                showingDisabledPopover = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(10)
                    }
                    .onTapGesture {
                        showingDisabledPopover.toggle()
                    }
            }

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
            Button("Show Preview: Full Screen Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                AlertCoordinator.shared.showPreviewAlert(for: event)
            }
            Button("Show Preview: Pre-Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                PreAlertManager.shared.showTestPreAlert(for: event)
            }
            Divider()
            if isDisabled {
                Button(AppStrings.reEnableAlertsForEvent) {
                    CalendarService.shared.reEnableEvent(event.id)
                }
            } else {
                Button(AppStrings.disableAlertsForEvent) {
                    CalendarService.shared.markEventAsFired(event.id)
                    PreAlertManager.shared.markAsPreAlerted(event.id)
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Menu Bar Reminder Row

struct MenuBarReminderRow: View {
    let reminder: CustomReminder

    var body: some View {
        HStack(spacing: 8) {
            Text(formatTime(reminder.scheduledDate))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                    Text("Reminder")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Show Preview: Full Screen Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                AlertCoordinator.shared.showPreviewAlert(for: reminder)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dismissPopover = Notification.Name("DismissPopover")
    static let openSettings = Notification.Name("OpenSettings")
}

// MARK: - Preview

#Preview {
    MenuBarView()
}

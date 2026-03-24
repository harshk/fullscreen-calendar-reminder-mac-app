//
//  MenuBarView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Menu Bar List Item

enum MenuBarListItem: Identifiable {
    case calendarEvent(CalendarEvent)
    case customReminder(CustomReminder)
    case appleReminder(AppleReminder)

    var id: String {
        switch self {
        case .calendarEvent(let e): return "event-\(e.id)"
        case .customReminder(let r): return "reminder-\(r.id.uuidString)"
        case .appleReminder(let r): return "apple-reminder-\(r.id)"
        }
    }

    var startDate: Date {
        switch self {
        case .calendarEvent(let e): return e.startDate
        case .customReminder(let r): return r.scheduledDate
        case .appleReminder(let r): return r.dueDate
        }
    }

    var title: String {
        switch self {
        case .calendarEvent(let e): return e.title
        case .customReminder(let r): return r.title
        case .appleReminder(let r): return r.title
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var calendarService = CalendarService.shared
    @ObservedObject var reminderService = ReminderService.shared
    @ObservedObject var appleRemindersService = AppleRemindersService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var showingAddReminder = false
    @State private var showingAddReminderInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App name and settings gear
            HStack {
                Text("ZapCal")
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

            if calendarService.permissionDenied {
                Button("Open System Settings") {
                    openSystemSettingsCalendarPrivacy()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Grant Calendar Access") {
                    NotificationCenter.default.post(name: .showWelcomeScreen, object: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        EventRow(event: event, isDisabled: calendarService.isEventDisabled(event.id))
                    case .customReminder(let reminder):
                        MenuBarReminderRow(reminder: reminder)
                    case .appleReminder(let reminder):
                        AppleReminderRow(reminder: reminder)
                    }
                }
            }
        }
    }
    
    // MARK: - Menu Actions
    
    private var menuActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 5)

            Button(action: { showingAddReminder = true }) {
                HStack {
                    Text("Add Full Screen Reminder")
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
            }
            .buttonStyle(MenuRowButtonStyle())
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }

            Button("Manage Reminders") {
                NotificationCenter.default.post(name: .openManageReminders, object: nil)
            }
            .buttonStyle(MenuRowButtonStyle())

            Divider()
                .padding(.horizontal, 10)

            Button(settings.isPaused ? "Unpause Full Screen Reminders" : "Pause Full Screen Reminders") {
                settings.isPaused.toggle()
            }
            .buttonStyle(MenuRowButtonStyle())

            Divider()
                .padding(.horizontal, 10)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(MenuRowButtonStyle())

            Spacer().frame(height: 5)
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarPanelDidClose)) { _ in
            showingAddReminder = false
        }
    }

    // MARK: - Helper Functions
    
    private var groupedItems: [(date: Date, items: [MenuBarListItem])] {
        let cal = Calendar.current
        var allItems: [MenuBarListItem] = settings.calendarAlertsEnabled
            ? calendarService.upcomingEvents.map { .calendarEvent($0) }
            : []
        allItems += reminderService.upcomingReminders.map { .customReminder($0) }
        if settings.appleRemindersEnabled {
            allItems += appleRemindersService.upcomingReminders.map { .appleReminder($0) }
        }
        allItems.sort { $0.startDate < $1.startDate }

        let grouped = Dictionary(grouping: allItems) { item in
            cal.startOfDay(for: item.startDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, items: $0.value) }
    }
    
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f
    }()

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today — \(Self.monthDayFormatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow — \(Self.monthDayFormatter.string(from: date))"
        } else {
            return Self.dayFormatter.string(from: date)
        }
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
    let isDisabled: Bool
    @State private var showingDisabledPopover = false

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
        .nativeContextMenu {
            let menu = NSMenu()
            menu.addItem(ClosureMenuItem("Show Preview: Full Screen Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                AlertCoordinator.shared.showPreviewAlert(for: event)
            })
            menu.addItem(ClosureMenuItem("Show Preview: Pre-Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                PreAlertManager.shared.showTestPreAlert(for: event)
            })
            menu.addItem(NSMenuItem.separator())
            if isDisabled {
                menu.addItem(ClosureMenuItem(AppStrings.reEnableAlertsForEvent) {
                    CalendarService.shared.reEnableEvent(event.id)
                })
            } else {
                menu.addItem(ClosureMenuItem(AppStrings.disableAlertsForEvent) {
                    CalendarService.shared.markEventAsFired(event.id)
                    PreAlertManager.shared.markAsPreAlerted(event.id)
                })
            }
            return menu
        }
    }
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
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
        .nativeContextMenu {
            let menu = NSMenu()
            menu.addItem(ClosureMenuItem("Show Preview: Full Screen Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                AlertCoordinator.shared.showPreviewAlert(for: reminder)
            })
            return menu
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Apple Reminder Row

struct AppleReminderRow: View {
    let reminder: AppleReminder

    var body: some View {
        HStack(spacing: 8) {
            Text(formatTime(reminder.dueDate))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                    Text(reminder.reminderList.title)
                        .font(.caption)
                }
                .foregroundColor(.green)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(reminder.reminderList.color.opacity(0.1))
        .contentShape(Rectangle())
        .nativeContextMenu {
            let menu = NSMenu()
            menu.addItem(ClosureMenuItem("Show Preview: Full Screen Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                AlertCoordinator.shared.showPreviewAlert(for: reminder)
            })
            menu.addItem(ClosureMenuItem("Show Preview: Pre-Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                PreAlertManager.shared.showPreAlert(for: reminder)
            })
            return menu
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Menu Row Button Style

struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.3) :
                          isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dismissPopover = Notification.Name("DismissPopover")
    static let openSettings = Notification.Name("OpenSettings")
    static let openManageReminders = Notification.Name("OpenManageReminders")
    static let showWelcomeScreen = Notification.Name("ShowWelcomeScreen")
}

// MARK: - Preview

#Preview {
    MenuBarView()
}

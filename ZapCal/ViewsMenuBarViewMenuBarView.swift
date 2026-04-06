//
//  MenuBarView.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import SwiftUI
import AppKit
import Combine
import StoreKit

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
    @ObservedObject var trialManager = TrialManager.shared
    @ObservedObject var storeManager = StoreManager.shared
    @State private var showingAddReminderInfo = false

    private var menuBarTheme: PreAlertTheme {
        PreAlertPresetManager.shared.theme(named: settings.menuBarPresetName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App name and settings gear
            HStack {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("ZapCal")
                        .font(.custom("SF Pro Rounded", size: 18).weight(.bold))
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("v\(version)")
                            .font(.custom("SF Pro Rounded", size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 12)
                Spacer()
                if trialManager.trialState != .expired {
                    Button(action: { openSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }
            .frame(height: 38)

            if storeManager.justPurchased {
                purchaseSuccessView
            } else if trialManager.trialState == .expired {
                trialExpiredView
            } else {
                if case .active(let days) = trialManager.trialState {
                    trialBannerView(daysRemaining: days)
                }

                if !calendarService.hasAccess {
                    noAccessView
                } else if settings.selectedCalendarIdentifiers.isEmpty {
                    noCalendarsSelectedView
                } else {
                    upcomingEventsSection
                }

                menuActions.padding(.vertical, 4)
            }
        }
        .frame(width: 350)
    }

    // MARK: - Trial Expired View

    @ViewBuilder
    private var trialExpiredView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Free Trial Expired")
                .font(.system(size: 18, weight: .semibold))

            Text("Purchase the full version to continue using ZapCal.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let product = storeManager.product {
                Button(action: {
                    Task { await storeManager.purchase() }
                }) {
                    Text("Purchase Full Version — \(product.displayPrice)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(storeManager.purchaseInProgress)
            }

            if storeManager.purchaseInProgress {
                ProgressView()
                    .controlSize(.small)
            }

            if let error = storeManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            Button("Restore Purchase") {
                Task { await storeManager.restorePurchases() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.accentColor)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)

        Divider().padding(.horizontal, 10)

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(MenuRowButtonStyle())

        Spacer().frame(height: 5)
    }

    // MARK: - Purchase Success View

    private var purchaseSuccessView: some View {
        VStack(spacing: 16) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            Text("Thank You!")
                .font(.system(size: 22, weight: .bold))

            Text("You've unlocked ZapCal forever.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Continue") {
                storeManager.justPurchased = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
    }

    // MARK: - Trial Banner

    private static let beeStingAccent = Color(red: 0.83, green: 0.08, blue: 0.70)
    private static let beeStingBg = Color(red: 1.0, green: 0.82, blue: 0.0)

    private func trialBannerView(daysRemaining: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Self.beeStingAccent)
                Text("in your free trial")
                    .font(.system(size: 12))
                    .foregroundColor(Self.beeStingAccent.opacity(0.7))
            }
            Spacer()
            Button(action: {
                Task { await storeManager.purchase() }
            }) {
                Text("Upgrade")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Self.beeStingBg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Self.beeStingAccent)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Self.beeStingBg.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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
                    NotificationCenter.default.post(name: .dismissPopover, object: nil)
                    Task { try? await calendarService.requestAccess() }
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
        }
        .scrollContentBackground(.hidden)
        .frame(maxHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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
                MenuBarDateHeader(title: formatDateHeader(group.date), theme: menuBarTheme)

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

            Button(action: {
                NotificationCenter.default.post(name: .openAddReminder, object: nil)
            }) {
                HStack {
                    Text("Add ZapCal Reminder")
                    Button(action: { showingAddReminderInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingAddReminderInfo) {
                        Text("Adds a custom reminder without having to add an event to your calendar.")
                            .font(.caption)
                            .padding(8)
                            .frame(width: 200)
                    }
                }
            }
            .buttonStyle(MenuRowButtonStyle())

            Button("Manage ZapCal Reminders") {
                NotificationCenter.default.post(name: .openManageReminders, object: nil)
            }
            .buttonStyle(MenuRowButtonStyle())

            Divider()
                .padding(.horizontal, 10)

            Button(settings.isPaused ? "Resume ZapCal Alerts" : "Pause all ZapCal Alerts") {
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

// MARK: - Shared Menu Bar Presentation Components

struct MenuBarDateHeader: View {
    let title: String
    let theme: PreAlertTheme

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(theme.titleColor.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.backgroundColor.color.opacity(theme.backgroundOpacity))
    }
}

struct MenuBarEventContent: View {
    let time: String
    let title: String
    var location: String? = nil
    var hasVideoCall: Bool = false
    var calendarColor: Color? = nil
    var joinAction: (() -> Void)? = nil
    let theme: PreAlertTheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(time)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.countdownColor.color)
                .frame(width: 70, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 6) {
                    if let calendarColor {
                        Circle()
                            .fill(calendarColor)
                            .frame(width: 10, height: 10)
                            .offset(y: 3)
                    }
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.titleColor.color)
                        .lineLimit(2)
                }

                if let location, !location.lowercased().hasPrefix("http") {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                            .offset(y: 2)
                        Text(location)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(theme.titleColor.color)
                }

                if hasVideoCall {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Video Call")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(theme.joinButtonBackgroundColor.color)
                }
            }

            Spacer()

            if hasVideoCall {
                if let joinAction {
                    Button("Join") { joinAction() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.joinButtonTextColor.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.joinButtonBackgroundColor.color)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Text("Join")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.joinButtonTextColor.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.joinButtonBackgroundColor.color)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.backgroundColor.color.opacity(theme.backgroundOpacity))
    }
}

struct MenuBarSubtitleRow: View {
    let time: String
    let title: String
    let subtitle: String
    let icon: String
    let theme: PreAlertTheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(time)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.countdownColor.color)
                .frame(width: 70, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .stroke(theme.titleColor.color, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                        .offset(y: 4)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.titleColor.color)
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(theme.titleColor.color)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.backgroundColor.color.opacity(theme.backgroundOpacity))
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CalendarEvent
    let isDisabled: Bool
    @ObservedObject private var settings = AppSettings.shared

    private var preAlertTheme: PreAlertTheme {
        PreAlertPresetManager.shared.theme(named: settings.menuBarPresetName)
    }

    var body: some View {
        MenuBarEventContent(
            time: formatTime(event.startDate),
            title: event.title,
            location: event.location,
            hasVideoCall: event.videoConferenceURL != nil,
            calendarColor: event.calendar.color,
            joinAction: event.videoConferenceURL.map { url in { NSWorkspace.shared.open(url) } },
            theme: preAlertTheme
        )
        .opacity(isDisabled ? 0.4 : 1.0)
        .background(preAlertTheme.backgroundColor.color.opacity(preAlertTheme.backgroundOpacity))
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
            menu.addItem(ClosureMenuItem("Show Preview: Mini Alert") {
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
    @ObservedObject private var settings = AppSettings.shared

    private var theme: PreAlertTheme {
        PreAlertPresetManager.shared.theme(named: settings.menuBarPresetName)
    }

    var body: some View {
        MenuBarSubtitleRow(
            time: formatTime(reminder.scheduledDate),
            title: reminder.title,
            subtitle: "Reminder",
            icon: "bell.fill",
            theme: theme
        )
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
    @ObservedObject private var settings = AppSettings.shared

    private var theme: PreAlertTheme {
        PreAlertPresetManager.shared.theme(named: settings.menuBarPresetName)
    }

    var body: some View {
        MenuBarSubtitleRow(
            time: formatTime(reminder.dueDate),
            title: reminder.title,
            subtitle: reminder.reminderList.title,
            icon: "checklist",
            theme: theme
        )
        .contentShape(Rectangle())
        .nativeContextMenu {
            let menu = NSMenu()
            menu.addItem(ClosureMenuItem("Show Preview: Full Screen Alert") {
                NotificationCenter.default.post(name: .dismissPopover, object: nil)
                AlertCoordinator.shared.showPreviewAlert(for: reminder)
            })
            menu.addItem(ClosureMenuItem("Show Preview: Mini Alert") {
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
    static let openAddReminder = Notification.Name("OpenAddReminder")
    static let welcomeSetupComplete = Notification.Name("WelcomeSetupComplete")
    static let openPanel = Notification.Name("OpenPanel")
}

// MARK: - Preview

#Preview {
    MenuBarView()
}

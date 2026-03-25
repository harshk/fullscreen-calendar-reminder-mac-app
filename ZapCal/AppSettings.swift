//
//  AppSettings.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import Combine
import ServiceManagement

enum AppStrings {
    static let disableAlertsForEvent = "Disable alerts for this event"
    static let reEnableAlertsForEvent = "Re-enable alerts for this event"
}

/// The kind of alert to show: a subtle banner or a full-screen overlay.
enum AlertStyle: String, Codable, CaseIterable, Identifiable {
    case subtle = "subtle"
    case fullScreen = "fullScreen"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .subtle: return "Subtle Alert"
        case .fullScreen: return "Full Screen Alert"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItemStatus()
        }
    }
    
    @Published var numberOfEventsInMenuBar: Int {
        didSet {
            UserDefaults.standard.set(numberOfEventsInMenuBar, forKey: "numberOfEventsInMenuBar")
        }
    }
    
    @Published var selectedCalendarIdentifiers: Set<String> {
        didSet {
            if let encoded = try? JSONEncoder().encode(Array(selectedCalendarIdentifiers)) {
                UserDefaults.standard.set(encoded, forKey: "selectedCalendarIdentifiers")
            }
        }
    }
    
    @Published var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: "isPaused")
            NotificationCenter.default.post(name: NSNotification.Name("PauseStateChanged"), object: nil)
        }
    }

    /// Whether calendar alerts are enabled.
    @Published var calendarAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarAlertsEnabled, forKey: "calendarAlertsEnabled") }
    }

    // MARK: - First Alert

    @Published var firstAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(firstAlertEnabled, forKey: "firstAlertEnabled") }
    }

    @Published var firstAlertStyle: AlertStyle {
        didSet { UserDefaults.standard.set(firstAlertStyle.rawValue, forKey: "firstAlertStyle") }
    }

    /// Lead time in seconds before the event the first alert fires (default 60).
    @Published var firstAlertLeadTime: Double {
        didSet { UserDefaults.standard.set(firstAlertLeadTime, forKey: "firstAlertLeadTime") }
    }

    /// Duration in seconds for the first alert banner. 0 = persist until event starts. Only used for subtle alerts.
    @Published var firstAlertDuration: Double {
        didSet { UserDefaults.standard.set(firstAlertDuration, forKey: "firstAlertDuration") }
    }

    // MARK: - Second Alert

    @Published var secondAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(secondAlertEnabled, forKey: "secondAlertEnabled") }
    }

    @Published var secondAlertStyle: AlertStyle {
        didSet { UserDefaults.standard.set(secondAlertStyle.rawValue, forKey: "secondAlertStyle") }
    }

    /// Lead time in seconds before the event the second alert fires (default 0 = at event start).
    @Published var secondAlertLeadTime: Double {
        didSet { UserDefaults.standard.set(secondAlertLeadTime, forKey: "secondAlertLeadTime") }
    }

    /// Duration in seconds for the second alert banner. 0 = persist until event starts. Only used for subtle alerts.
    @Published var secondAlertDuration: Double {
        didSet { UserDefaults.standard.set(secondAlertDuration, forKey: "secondAlertDuration") }
    }

    /// Snooze durations in seconds offered on the full-screen alert (default: 1m, 5m, 15m).
    @Published var snoozeDurations: [Double] {
        didSet { UserDefaults.standard.set(snoozeDurations, forKey: "snoozeDurations") }
    }

    /// The Subtle Alert preset name used for menu bar event/reminder rows.
    @Published var menuBarPresetName: String {
        didSet { UserDefaults.standard.set(menuBarPresetName, forKey: "menuBarPresetName") }
    }

    /// Whether Apple Reminders integration is enabled.
    @Published var appleRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(appleRemindersEnabled, forKey: "appleRemindersEnabled") }
    }

    /// Selected reminder list identifiers for Apple Reminders.
    @Published var selectedReminderListIdentifiers: Set<String> {
        didSet {
            if let encoded = try? JSONEncoder().encode(Array(selectedReminderListIdentifiers)) {
                UserDefaults.standard.set(encoded, forKey: "selectedReminderListIdentifiers")
            }
        }
    }

    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let storedEventCount = UserDefaults.standard.integer(forKey: "numberOfEventsInMenuBar")
        self.numberOfEventsInMenuBar = storedEventCount == 0 ? 10 : storedEventCount
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")

        // Calendar alerts (default true)
        if UserDefaults.standard.object(forKey: "calendarAlertsEnabled") != nil {
            self.calendarAlertsEnabled = UserDefaults.standard.bool(forKey: "calendarAlertsEnabled")
        } else {
            self.calendarAlertsEnabled = true
        }

        // First Alert defaults (migrate from old preAlert settings if present)
        let migrated = UserDefaults.standard.object(forKey: "firstAlertEnabled") != nil
        if migrated {
            self.firstAlertEnabled = UserDefaults.standard.bool(forKey: "firstAlertEnabled")
        } else if UserDefaults.standard.object(forKey: "preAlertEnabled") != nil {
            // Migrate: old preAlert → first alert
            self.firstAlertEnabled = UserDefaults.standard.bool(forKey: "preAlertEnabled")
        } else {
            self.firstAlertEnabled = true
        }
        self.firstAlertStyle = AlertStyle(rawValue: UserDefaults.standard.string(forKey: "firstAlertStyle") ?? "") ?? .subtle
        let storedFirstLeadTime = UserDefaults.standard.double(forKey: "firstAlertLeadTime")
        if storedFirstLeadTime > 0 {
            self.firstAlertLeadTime = storedFirstLeadTime
        } else if !migrated {
            let oldLeadTime = UserDefaults.standard.double(forKey: "preAlertLeadTime")
            self.firstAlertLeadTime = oldLeadTime > 0 ? oldLeadTime : 60
        } else {
            self.firstAlertLeadTime = 60
        }
        if let storedFirstDuration = UserDefaults.standard.object(forKey: "firstAlertDuration") as? Double {
            self.firstAlertDuration = storedFirstDuration
        } else if !migrated, let oldDuration = UserDefaults.standard.object(forKey: "preAlertDuration") as? Double {
            self.firstAlertDuration = oldDuration
        } else {
            self.firstAlertDuration = 15
        }

        // Second Alert defaults
        if UserDefaults.standard.object(forKey: "secondAlertEnabled") != nil {
            self.secondAlertEnabled = UserDefaults.standard.bool(forKey: "secondAlertEnabled")
        } else {
            self.secondAlertEnabled = true
        }
        self.secondAlertStyle = AlertStyle(rawValue: UserDefaults.standard.string(forKey: "secondAlertStyle") ?? "") ?? .fullScreen
        self.secondAlertLeadTime = UserDefaults.standard.double(forKey: "secondAlertLeadTime") // 0 = at event start
        if let storedSecondDuration = UserDefaults.standard.object(forKey: "secondAlertDuration") as? Double {
            self.secondAlertDuration = storedSecondDuration
        } else {
            self.secondAlertDuration = 15
        }
        let defaultSnooze: [Double] = [60, 300, 900] // 1m, 5m, 15m
        if let storedSnooze = UserDefaults.standard.array(forKey: "snoozeDurations") as? [Double], !storedSnooze.isEmpty {
            var result = storedSnooze
            while result.count < 3 { result.append(defaultSnooze[result.count]) }
            self.snoozeDurations = Array(result.prefix(3))
        } else {
            self.snoozeDurations = defaultSnooze
        }
        
        // Load selected calendar identifiers
        if let data = UserDefaults.standard.data(forKey: "selectedCalendarIdentifiers"),
           let identifiers = try? JSONDecoder().decode([String].self, from: data) {
            self.selectedCalendarIdentifiers = Set(identifiers)
        } else {
            self.selectedCalendarIdentifiers = []
        }

        // Menu bar preset
        self.menuBarPresetName = UserDefaults.standard.string(forKey: "menuBarPresetName") ?? "Coral Paper"

        // Apple Reminders
        self.appleRemindersEnabled = UserDefaults.standard.bool(forKey: "appleRemindersEnabled")
        if let data = UserDefaults.standard.data(forKey: "selectedReminderListIdentifiers"),
           let identifiers = try? JSONDecoder().decode([String].self, from: data) {
            self.selectedReminderListIdentifiers = Set(identifiers)
        } else {
            self.selectedReminderListIdentifiers = []
        }
        
        // Set default launch at login to true on first launch
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            self.launchAtLogin = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        // Ensure login item registration is in sync on every launch
        updateLoginItemStatus()
    }
    
    // MARK: - Launch at Login
    
    private func updateLoginItemStatus() {
        if #available(macOS 13.0, *) {
            Task {
                do {
                    if launchAtLogin {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else {
                        if SMAppService.mainApp.status == .enabled {
                            try await SMAppService.mainApp.unregister()
                        }
                    }
                } catch {
                    print("Failed to update login item status: \(error)")
                }
            }
        }
    }
}

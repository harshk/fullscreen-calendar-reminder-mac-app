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

    /// Whether the pre-alert system (glow + banner) is enabled.
    @Published var preAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(preAlertEnabled, forKey: "preAlertEnabled") }
    }

    /// How many seconds before the event the pre-alert fires (default 60).
    @Published var preAlertLeadTime: Double {
        didSet { UserDefaults.standard.set(preAlertLeadTime, forKey: "preAlertLeadTime") }
    }

    /// How many seconds the pre-alert (glow + banner) stays visible. 0 = persist until event starts.
    @Published var preAlertDuration: Double {
        didSet { UserDefaults.standard.set(preAlertDuration, forKey: "preAlertDuration") }
    }

    /// Snooze durations in seconds offered on the full-screen alert (default: 1m, 5m, 15m).
    @Published var snoozeDurations: [Double] {
        didSet { UserDefaults.standard.set(snoozeDurations, forKey: "snoozeDurations") }
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

        // Pre-alert defaults
        if UserDefaults.standard.object(forKey: "preAlertEnabled") != nil {
            self.preAlertEnabled = UserDefaults.standard.bool(forKey: "preAlertEnabled")
        } else {
            self.preAlertEnabled = true
        }
        let storedLeadTime = UserDefaults.standard.double(forKey: "preAlertLeadTime")
        self.preAlertLeadTime = storedLeadTime > 0 ? storedLeadTime : 60
        if let storedDuration = UserDefaults.standard.object(forKey: "preAlertDuration") as? Double {
            self.preAlertDuration = storedDuration
        } else {
            self.preAlertDuration = 15
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
            updateLoginItemStatus()
        }
    }
    
    // MARK: - Launch at Login
    
    private func updateLoginItemStatus() {
        if #available(macOS 13.0, *) {
            Task {
                do {
                    if launchAtLogin {
                        if SMAppService.mainApp.status == .notRegistered {
                            try await SMAppService.mainApp.register()
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

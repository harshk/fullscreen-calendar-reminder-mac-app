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

/// A single alert configuration in the user's alert list.
struct AlertConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var enabled: Bool
    var style: AlertStyle
    /// Lead time in seconds before the event this alert fires.
    var leadTime: Double
    /// Duration in seconds the subtle alert banner stays visible. 0 = persist until event starts.
    var subtleDuration: Double
    /// Snooze durations in seconds for full-screen alerts.
    var snoozeDurations: [Double]

    init(
        id: UUID = UUID(),
        enabled: Bool = true,
        style: AlertStyle = .subtle,
        leadTime: Double = 60,
        subtleDuration: Double = 15,
        snoozeDurations: [Double] = [60, 300, 900]
    ) {
        self.id = id
        self.enabled = enabled
        self.style = style
        self.leadTime = leadTime
        self.subtleDuration = subtleDuration
        self.snoozeDurations = snoozeDurations
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

    // MARK: - Alert Configs

    @Published var alertConfigs: [AlertConfig] {
        didSet { saveAlertConfigs() }
    }

    private func saveAlertConfigs() {
        if let data = try? JSONEncoder().encode(alertConfigs) {
            UserDefaults.standard.set(data, forKey: "alertConfigs")
        }
    }

    /// Snooze durations in seconds offered on the full-screen alert (default: 1m, 5m, 15m).
    /// Used as a fallback; per-alert snoozeDurations take precedence when available.
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

        // Alert configs
        if let data = UserDefaults.standard.data(forKey: "alertConfigs"),
           let configs = try? JSONDecoder().decode([AlertConfig].self, from: data) {
            self.alertConfigs = configs
        } else {
            // Migrate from old settings
            let subtleLeadTime: Double = {
                if let v = UserDefaults.standard.object(forKey: "subtleAlertLeadTime") as? Double { return v }
                if let v = UserDefaults.standard.object(forKey: "firstAlertLeadTime") as? Double, v > 0 { return v }
                let legacy = UserDefaults.standard.double(forKey: "preAlertLeadTime")
                return legacy > 0 ? legacy : 60
            }()
            let subtleDuration: Double = {
                if let v = UserDefaults.standard.object(forKey: "subtleAlertDuration") as? Double { return v }
                if let v = UserDefaults.standard.object(forKey: "firstAlertDuration") as? Double { return v }
                if let v = UserDefaults.standard.object(forKey: "preAlertDuration") as? Double { return v }
                return 15
            }()
            let fsLeadTime: Double = {
                if let v = UserDefaults.standard.object(forKey: "fullScreenAlertLeadTime") as? Double { return v }
                return UserDefaults.standard.double(forKey: "secondAlertLeadTime")
            }()

            let firstEnabled = UserDefaults.standard.object(forKey: "firstAlertEnabled") != nil
                ? UserDefaults.standard.bool(forKey: "firstAlertEnabled")
                : (UserDefaults.standard.object(forKey: "preAlertEnabled") != nil
                    ? UserDefaults.standard.bool(forKey: "preAlertEnabled")
                    : true)
            let firstStyle = AlertStyle(rawValue: UserDefaults.standard.string(forKey: "firstAlertStyle") ?? "") ?? .subtle
            let secondEnabled = UserDefaults.standard.object(forKey: "secondAlertEnabled") != nil
                ? UserDefaults.standard.bool(forKey: "secondAlertEnabled")
                : true
            let secondStyle = AlertStyle(rawValue: UserDefaults.standard.string(forKey: "secondAlertStyle") ?? "") ?? .fullScreen

            self.alertConfigs = [
                AlertConfig(enabled: firstEnabled, style: firstStyle, leadTime: subtleLeadTime, subtleDuration: subtleDuration),
                AlertConfig(enabled: secondEnabled, style: secondStyle, leadTime: fsLeadTime, subtleDuration: subtleDuration),
            ]
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

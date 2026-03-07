//
//  AppSettings.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import Combine
import ServiceManagement

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
    
    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let storedEventCount = UserDefaults.standard.integer(forKey: "numberOfEventsInMenuBar")
        self.numberOfEventsInMenuBar = storedEventCount == 0 ? 10 : storedEventCount
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        
        // Load selected calendar identifiers
        if let data = UserDefaults.standard.data(forKey: "selectedCalendarIdentifiers"),
           let identifiers = try? JSONDecoder().decode([String].self, from: data) {
            self.selectedCalendarIdentifiers = Set(identifiers)
        } else {
            self.selectedCalendarIdentifiers = []
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

# URGENT: Manual File Creation Required

## Problem

Xcode is not recognizing the model files I created. You need to manually create them in Xcode.

## Step-by-Step Instructions

### 1. Create AppSettings.swift (CRITICAL - BUILD BLOCKER)

1. In Xcode, right-click on your project in the Navigator
2. Select **New File...** (or press ⌘+N)
3. Choose **Swift File**
4. Name it: `AppSettings.swift`
5. Make sure it's added to the **ZapCal** target (check the box)
6. Click **Create**
7. **DELETE ALL DEFAULT CONTENT** and paste this EXACT code:

```swift
//
//  AppSettings.swift
//  ZapCal
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
        self.numberOfEventsInMenuBar = UserDefaults.standard.integer(forKey: "numberOfEventsInMenuBar")
        self.isPaused = UserDefaults.standard.bool(forKey: "isPaused")
        
        // Default to 10 events if not set
        if self.numberOfEventsInMenuBar == 0 {
            self.numberOfEventsInMenuBar = 10
        }
        
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
```

### 2. Create CalendarEvent.swift (CRITICAL - BUILD BLOCKER)

Same process:
1. New File → Swift File
2. Name: `CalendarEvent.swift`
3. Add to target
4. Paste this code:

```swift
//
//  CalendarEvent.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import EventKit
import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let participationStatus: EKParticipantStatus
    let calendar: EventCalendarInfo
    let videoConferenceURL: URL?
    
    struct EventCalendarInfo: Equatable {
        let identifier: String
        let title: String
        let color: Color
    }
    
    init(from ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.isAllDay = ekEvent.isAllDay
        self.participationStatus = ekEvent.participationStatus
        
        self.calendar = EventCalendarInfo(
            identifier: ekEvent.calendar.calendarIdentifier,
            title: ekEvent.calendar.title,
            color: Color(ekEvent.calendar.cgColor)
        )
        
        self.videoConferenceURL = Self.extractVideoConferenceURL(from: ekEvent)
    }
    
    // Mock initializer for previews and testing
    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false,
        participationStatus: EKParticipantStatus = .accepted,
        calendarTitle: String = "Calendar",
        calendarColor: Color = .blue,
        videoConferenceURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate ?? startDate.addingTimeInterval(3600)
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
        self.participationStatus = participationStatus
        self.calendar = EventCalendarInfo(
            identifier: "mock",
            title: calendarTitle,
            color: calendarColor
        )
        self.videoConferenceURL = videoConferenceURL
    }
    
    // MARK: - Computed Properties
    
    var shouldTriggerAlert: Bool {
        // Don't trigger for all-day events
        guard !isAllDay else { return false }
        
        // Don't trigger for declined events
        guard participationStatus != .declined else { return false }
        
        return true
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: startDate)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }
    
    // MARK: - Video Conference URL Extraction
    
    private static func extractVideoConferenceURL(from event: EKEvent) -> URL? {
        // First check if EventKit provides structured video conference data
        if #available(macOS 12.0, *) {
            if let structuredLocation = event.structuredLocation,
               let url = structuredLocation.geoLocation as? URL {
                return url
            }
        }
        
        // Check URL property
        if let url = event.url, isVideoConferenceURL(url) {
            return url
        }
        
        // Parse from notes
        if let notes = event.notes,
           let url = findVideoConferenceURL(in: notes) {
            return url
        }
        
        // Parse from location
        if let location = event.location,
           let url = findVideoConferenceURL(in: location) {
            return url
        }
        
        return nil
    }
    
    private static func findVideoConferenceURL(in text: String) -> URL? {
        let patterns = [
            "https?://[^\\s]*zoom\\.us/[^\\s]+",
            "https?://[^\\s]*meet\\.google\\.com/[^\\s]+",
            "https?://[^\\s]*teams\\.microsoft\\.com/[^\\s]+",
            "https?://[^\\s]*webex\\.com/[^\\s]+",
            "facetime://[^\\s]+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                return URL(string: urlString)
            }
        }
        
        return nil
    }
    
    private static func isVideoConferenceURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("zoom.us") ||
               host.contains("meet.google.com") ||
               host.contains("teams.microsoft.com") ||
               host.contains("webex.com") ||
               url.scheme == "facetime"
    }
    
    // MARK: - Equatable
    
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Mock Factory
    
    static func mock() -> CalendarEvent {
        CalendarEvent(
            id: "mock-event-1",
            title: "Team Meeting",
            startDate: Date().addingTimeInterval(3600),
            location: "Conference Room A",
            notes: "Discuss Q2 planning",
            videoConferenceURL: URL(string: "https://zoom.us/j/123456789")
        )
    }
}

// MARK: - Color from CGColor Extension

extension Color {
    init(_ cgColor: CGColor) {
        #if canImport(AppKit)
        self.init(nsColor: NSColor(cgColor: cgColor) ?? NSColor.gray)
        #else
        self.init(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
        #endif
    }
}
```

### 3. Create CustomReminder.swift (CRITICAL - BUILD BLOCKER)

Same process:
1. New File → Swift File
2. Name: `CustomReminder.swift`
3. Add to target
4. Paste:

```swift
//
//  CustomReminder.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftData

@Model
final class CustomReminder {
    var id: UUID
    var title: String
    var scheduledDate: Date
    var hasFired: Bool
    var createdAt: Date
    
    init(title: String, scheduledDate: Date) {
        self.id = UUID()
        self.title = title
        self.scheduledDate = scheduledDate
        self.hasFired = false
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var isPast: Bool {
        scheduledDate < Date()
    }
    
    var isUpcoming: Bool {
        !isPast
    }
    
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDate)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: scheduledDate)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDate)
    }
}
```

### 4. Create ThemeService.swift (CRITICAL - BUILD BLOCKER)

Same process:
1. New File → Swift File
2. Name: `ThemeService.swift`
3. Add to target
4. Paste:

```swift
//
//  ThemeService.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftUI

class ThemeService: ObservableObject {
    static let shared = ThemeService()
    
    @Published private(set) var themes: [String: AlertTheme] = [:]
    
    private let themesKey = "alertThemes"
    
    private init() {
        loadThemes()
    }
    
    // MARK: - Theme Management
    
    func getTheme(for calendarIdentifier: String?) -> AlertTheme {
        let id = calendarIdentifier ?? "default"
        
        if let theme = themes[id] {
            return theme
        }
        
        // Return default theme if not found
        return themes["default"] ?? AlertTheme.defaultTheme()
    }
    
    func setTheme(_ theme: AlertTheme, for calendarIdentifier: String) {
        themes[calendarIdentifier] = theme
        saveThemes()
    }
    
    func resetTheme(for calendarIdentifier: String) {
        if calendarIdentifier == "default" {
            themes["default"] = AlertTheme.defaultTheme()
        } else {
            themes.removeValue(forKey: calendarIdentifier)
        }
        saveThemes()
    }
    
    func duplicateTheme(from sourceIdentifier: String, to targetIdentifier: String) {
        guard let sourceTheme = themes[sourceIdentifier] else { return }
        
        var newTheme = sourceTheme
        newTheme.id = targetIdentifier
        themes[targetIdentifier] = newTheme
        saveThemes()
    }
    
    func ensureDefaultTheme() {
        if themes["default"] == nil {
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
        }
    }
    
    // MARK: - Persistence
    
    private func loadThemes() {
        guard let data = UserDefaults.standard.data(forKey: themesKey),
              let decoded = try? JSONDecoder().decode([String: AlertTheme].self, from: data) else {
            // Create default theme if none exists
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
            return
        }
        
        themes = decoded
        
        // Ensure default theme exists
        if themes["default"] == nil {
            themes["default"] = AlertTheme.defaultTheme()
            saveThemes()
        }
    }
    
    func saveThemes() {
        if let encoded = try? JSONEncoder().encode(themes) {
            UserDefaults.standard.set(encoded, forKey: themesKey)
        }
    }
}
```

## After Creating All 4 Files

1. **Clean Build**: ⌘ + Shift + K
2. **Build**: ⌘ + B
3. **Should compile successfully!**

## Organize Files (Optional but Recommended)

After creating the files, organize them in Xcode:

1. Create a **Models** group in Navigator
2. Drag `AppSettings.swift`, `CalendarEvent.swift`, `CustomReminder.swift` into it

3. Create a **Services** group
4. Drag `ThemeService.swift` into it

---

## Why This Happened

The AI assistant (me) can create files, but sometimes Xcode doesn't immediately recognize them in its file system. Manual creation in Xcode ensures they're properly added to the target and build system.

## Next Error?

If you still get errors after this, they should be:
- Configuration issues (Info.plist) - See QUICKSTART.md
- Or very minor fixes I can help with immediately

**Create these 4 files now and the build should succeed!** 🚀

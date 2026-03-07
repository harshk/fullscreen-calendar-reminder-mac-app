//
//  Full_Screen_Calendar_ReminderTests.swift
//  Full Screen Calendar ReminderTests
//
//  Created by Harsh Kalra on 3/5/26.
//

import Testing
import Foundation
import SwiftUI
import EventKit
@testable import Full_Screen_Calendar_Reminder

@Suite("Alert Theme Tests")
struct AlertThemeTests {
    
    @Test("Default theme has all elements")
    func defaultThemeHasAllElements() {
        let theme = AlertTheme.defaultTheme()
        
        #expect(theme.id == "default")
        #expect(theme.backgroundType == .solidColor)
        #expect(theme.elementStyles.count == AlertElementIdentifier.allCases.count)
        
        for element in AlertElementIdentifier.allCases {
            #expect(theme.elementStyles[element] != nil, "Missing style for \(element)")
        }
    }
    
    @Test("Theme is codable")
    func themeIsCodable() throws {
        let theme = AlertTheme.defaultTheme()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(theme)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AlertTheme.self, from: data)
        
        #expect(decoded.id == theme.id)
        #expect(decoded.elementStyles.count == theme.elementStyles.count)
    }
    
    @Test("CodableColor preserves color values")
    func codableColorPreservesValues() {
        let color = CodableColor(.red)
        
        #expect(color.red > 0.9)
        #expect(color.green < 0.1)
        #expect(color.blue < 0.1)
        #expect(color.opacity == 1.0)
    }
}

@Suite("Custom Reminder Tests")
struct CustomReminderTests {
    
    @Test("Reminder initialization")
    func reminderInitialization() {
        let title = "Test Reminder"
        let date = Date().addingTimeInterval(3600) // 1 hour from now
        let reminder = CustomReminder(title: title, scheduledDate: date)
        
        #expect(reminder.title == title)
        #expect(reminder.scheduledDate == date)
        #expect(reminder.hasFired == false)
        #expect(!reminder.isPast)
        #expect(reminder.isUpcoming)
    }
    
    @Test("Past reminder detection")
    func pastReminderDetection() {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let reminder = CustomReminder(title: "Past", scheduledDate: pastDate)
        
        #expect(reminder.isPast)
        #expect(!reminder.isUpcoming)
    }
    
    @Test("Fired reminder is not upcoming")
    func firedReminderIsNotUpcoming() {
        let futureDate = Date().addingTimeInterval(3600)
        let reminder = CustomReminder(title: "Test", scheduledDate: futureDate)
        reminder.hasFired = true
        
        #expect(!reminder.isUpcoming)
    }
}

@Suite("Calendar Event Tests")
struct CalendarEventTests {
    
    @Test("Mock event creation")
    func mockEventCreation() {
        let event = CalendarEvent(
            title: "Test Event",
            startDate: Date().addingTimeInterval(3600),
            calendarTitle: "Work"
        )
        
        #expect(event.title == "Test Event")
        #expect(event.calendar.title == "Work")
        #expect(!event.isAllDay)
        #expect(event.participationStatus == .accepted)
    }
    
    @Test("Should trigger alert for accepted events")
    func shouldTriggerAlertForAcceptedEvents() {
        let event = CalendarEvent(
            title: "Meeting",
            startDate: Date().addingTimeInterval(3600)
        )
        #expect(event.shouldTriggerAlert)
    }
    
    @Test("Video conference URL extraction patterns")
    func videoConferenceURLPatterns() {
        // Test that event with zoom URL is recognized
        let event = CalendarEvent(
            title: "Zoom Meeting",
            startDate: Date().addingTimeInterval(3600),
            videoConferenceURL: URL(string: "https://zoom.us/j/123456789")
        )
        #expect(event.videoConferenceURL != nil)
    }
}
@Suite("App Settings Tests")
struct AppSettingsTests {
    
    @Test("Default settings values")
    func defaultSettingsValues() {
        let settings = AppSettings.shared
        
        #expect(settings.numberOfEventsInMenuBar >= 1)
        #expect(settings.numberOfEventsInMenuBar <= 50)
    }
}

@Suite("Alert Coordinator Tests")
struct AlertCoordinatorTests {
    
    @Test("Alert item from calendar event")
    func alertItemFromCalendarEvent() {
        let event = CalendarEvent(
            title: "Test Event",
            startDate: Date().addingTimeInterval(3600)
        )
        let item = AlertItem.calendarEvent(event)
        
        #expect(item.title == "Test Event")
        #expect(item.id == event.id)
    }
    
    @Test("Alert item from custom reminder")
    func alertItemFromCustomReminder() {
        let reminder = CustomReminder(
            title: "Test Reminder",
            scheduledDate: Date().addingTimeInterval(3600)
        )
        let item = AlertItem.customReminder(reminder)
        
        #expect(item.title == "Test Reminder")
        #expect(item.id == reminder.id.uuidString)
    }
}

@Suite("Theme Service Tests")
struct ThemeServiceTests {
    
    @Test("Get default theme")
    func getDefaultTheme() async {
        await MainActor.run {
            let service = ThemeService.shared
            let theme = service.getTheme(for: nil)
            
            #expect(theme.id == "default")
        }
    }
    
    @Test("Get theme for calendar")
    func getThemeForCalendar() async {
        await MainActor.run {
            let service = ThemeService.shared
            
            // Set a custom theme
            var customTheme = AlertTheme.defaultTheme(id: "test-calendar", name: "Test")
            customTheme.solidColor = CodableColor(.blue)
            service.setTheme(customTheme, for: "test-calendar")
            
            // Retrieve it
            let retrieved = service.getTheme(for: "test-calendar")
            #expect(retrieved.id == "test-calendar")
        }
    }
}


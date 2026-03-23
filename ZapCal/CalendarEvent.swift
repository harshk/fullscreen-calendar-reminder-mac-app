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
        // eventIdentifier is Optional and can be shared across recurring
        // occurrences.  Combine with startDate for uniqueness, and fall back
        // to a UUID when the identifier is nil.
        let eid = ekEvent.eventIdentifier ?? UUID().uuidString
        self.id = "\(eid)_\(ekEvent.startDate.timeIntervalSinceReferenceDate)"
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.location = ekEvent.location
        self.notes = ekEvent.notes
        self.isAllDay = ekEvent.isAllDay
        self.participationStatus = Self.getParticipationStatus(from: ekEvent)
        
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
    
    static func findVideoConferenceURL(in text: String) -> URL? {
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
    
    static func isVideoConferenceURL(_ url: URL) -> Bool {
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
    // MARK: - Helper: Get User's Participation Status

    private static func getParticipationStatus(from event: EKEvent) -> EKParticipantStatus {
        // Try to find the current user's participation status
        if let attendees = event.attendees {
            // Find the current user (organizer or an attendee matching the calendar's owner)
            if let currentUserAttendee = attendees.first(where: { $0.isCurrentUser }) {
                return currentUserAttendee.participantStatus
            }
        }
        
        // Default to accepted if we can't determine (user is likely the organizer)
        return .accepted
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

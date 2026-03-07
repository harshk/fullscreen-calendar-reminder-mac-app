//
//  CustomReminder.swift
//  Full Screen Calendar Reminder
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

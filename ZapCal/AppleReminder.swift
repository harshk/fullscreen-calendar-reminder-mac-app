//
//  AppleReminder.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/24/26.
//

import Foundation
import EventKit
import SwiftUI

struct AppleReminder: Identifiable, Equatable {
    let id: String
    let calendarItemIdentifier: String
    let title: String
    let dueDate: Date
    let notes: String?
    let isCompleted: Bool
    let priority: Int
    let reminderList: ReminderListInfo

    struct ReminderListInfo: Equatable {
        let identifier: String
        let title: String
        let color: Color
    }

    /// Failable init — returns nil if the reminder has no due date.
    init?(from ekReminder: EKReminder) {
        guard let components = ekReminder.dueDateComponents,
              let dueDate = Calendar.current.date(from: components) else {
            return nil
        }

        self.calendarItemIdentifier = ekReminder.calendarItemIdentifier
        self.id = "\(ekReminder.calendarItemIdentifier)_\(dueDate.timeIntervalSinceReferenceDate)"
        self.title = ekReminder.title ?? "Untitled Reminder"
        self.dueDate = dueDate
        self.notes = ekReminder.notes
        self.isCompleted = ekReminder.isCompleted
        self.priority = ekReminder.priority
        self.reminderList = ReminderListInfo(
            identifier: ekReminder.calendar.calendarIdentifier,
            title: ekReminder.calendar.title,
            color: Color(ekReminder.calendar.cgColor)
        )
    }

    /// Mock initializer for previews and testing.
    init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date,
        notes: String? = nil,
        isCompleted: Bool = false,
        priority: Int = 0,
        listTitle: String = "Reminders",
        listColor: Color = .green
    ) {
        self.calendarItemIdentifier = id
        self.id = "\(id)_\(dueDate.timeIntervalSinceReferenceDate)"
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.reminderList = ReminderListInfo(
            identifier: "mock",
            title: listTitle,
            color: listColor
        )
    }

    static func == (lhs: AppleReminder, rhs: AppleReminder) -> Bool {
        lhs.id == rhs.id
    }

    static func mock() -> AppleReminder {
        AppleReminder(
            title: "Buy groceries",
            dueDate: Date().addingTimeInterval(3600),
            notes: "Milk, eggs, bread"
        )
    }
}

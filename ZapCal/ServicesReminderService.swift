//
//  ReminderService.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
class ReminderService: ObservableObject {
    static let shared = ReminderService()
    
    @Published var upcomingReminders: [CustomReminder] = []
    
    private var modelContext: ModelContext?
    private var firedReminderIDs = Set<UUID>()
    private var alertFiredIDs = [UUID: Set<UUID>]()
    private var lastFireCheckDate = Date()

    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadReminders()
    }
    
    // MARK: - CRUD Operations
    
    func loadReminders() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<CustomReminder>(
            sortBy: [SortDescriptor(\.scheduledDate)]
        )
        
        do {
            let allReminders = try context.fetch(descriptor)
            upcomingReminders = allReminders.filter { $0.isUpcoming }
        } catch {
            print("Failed to load reminders: \(error)")
        }
    }
    
    func addReminder(title: String, scheduledDate: Date) throws {
        guard let context = modelContext else {
            throw NSError(domain: "ReminderService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model context not available"])
        }
        
        let reminder = CustomReminder(title: title, scheduledDate: scheduledDate)
        context.insert(reminder)
        
        try context.save()
        loadReminders()
    }
    
    func updateReminder(_ reminder: CustomReminder, title: String, scheduledDate: Date) throws {
        reminder.title = title
        reminder.scheduledDate = scheduledDate
        reminder.hasFired = false // Reset if rescheduled
        
        try modelContext?.save()
        loadReminders()
    }
    
    func deleteReminder(_ reminder: CustomReminder) throws {
        modelContext?.delete(reminder)
        try modelContext?.save()
        loadReminders()
    }
    
    func deleteReminders(_ reminders: [CustomReminder]) throws {
        for reminder in reminders {
            modelContext?.delete(reminder)
        }
        try modelContext?.save()
        loadReminders()
    }
    
    // MARK: - Alert Triggering
    
    func checkForRemindersToFire() {
        guard !AppSettings.shared.isPaused else { return }
        guard TrialManager.shared.trialState != .expired else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastFireCheckDate)
        lastFireCheckDate = now

        // If more than 2 minutes elapsed since the last check, the system was
        // likely asleep (timer fires every ~60s). Silently mark all past-due
        // reminders as fired and delete them without showing alerts.
        if elapsed > 120 {
            let missedReminders = upcomingReminders.filter { reminder in
                !firedReminderIDs.contains(reminder.id) &&
                reminder.scheduledDate <= now &&
                !reminder.hasFired
            }
            for reminder in missedReminders {
                firedReminderIDs.insert(reminder.id)
                for config in AppSettings.shared.reminderAlertConfigs {
                    alertFiredIDs[config.id, default: []].insert(reminder.id)
                }
                modelContext?.delete(reminder)
            }
            if !missedReminders.isEmpty {
                try? modelContext?.save()
                loadReminders()
            }
            return
        }

        let settings = AppSettings.shared
        var deletedAny = false

        for config in settings.reminderAlertConfigs {
            guard config.enabled else { continue }
            for reminder in upcomingReminders {
                guard !firedReminderIDs.contains(reminder.id) else { continue }
                guard !alertFiredIDs[config.id, default: []].contains(reminder.id) else { continue }
                let timeUntilStart = reminder.scheduledDate.timeIntervalSince(now)
                if timeUntilStart <= config.leadTime && timeUntilStart > -120 {
                    alertFiredIDs[config.id, default: []].insert(reminder.id)
                    fireAlert(config: config, for: reminder, deleteAfterFullScreen: &deletedAny)
                }
            }
        }

        if deletedAny {
            try? modelContext?.save()
            loadReminders()
        }
    }

    private func fireAlert(config: AlertConfig, for reminder: CustomReminder, deleteAfterFullScreen: inout Bool) {
        if config.style == .fullScreen {
            firedReminderIDs.insert(reminder.id)
            modelContext?.delete(reminder)
            deleteAfterFullScreen = true
        }
        AlertMergeBuffer.shared.submit(
            item: .customReminder(reminder),
            style: config.style,
            duration: config.miniDuration
        )
    }
}

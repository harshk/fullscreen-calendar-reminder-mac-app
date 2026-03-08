//
//  ReminderService.swift
//  Full Screen Calendar Reminder
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
    private var pollingTimer: Timer?
    private var firedReminderIDs = Set<UUID>()
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadReminders()
        startPolling()
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
    
    // MARK: - Polling
    
    func startPolling() {
        stopPolling()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForRemindersToFire()
            }
        }
        
        checkForRemindersToFire()
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Alert Triggering
    
    func checkForRemindersToFire() {
        guard !AppSettings.shared.isPaused else { return }
        
        let now = Date()
        let remindersToFire = upcomingReminders.filter { reminder in
            !firedReminderIDs.contains(reminder.id) &&
            reminder.scheduledDate <= now &&
            !reminder.hasFired
        }
        
        for reminder in remindersToFire {
            firedReminderIDs.insert(reminder.id)

            AlertCoordinator.shared.queueAlert(for: reminder)

            modelContext?.delete(reminder)
        }

        if !remindersToFire.isEmpty {
            try? modelContext?.save()
            loadReminders()
        }
    }
}

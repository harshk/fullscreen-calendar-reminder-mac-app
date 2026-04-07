//
//  AppleRemindersService.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/24/26.
//

import Foundation
import EventKit
import AppKit
import Combine

@MainActor
class AppleRemindersService: ObservableObject {
    static let shared = AppleRemindersService()

    /// Shared event store from CalendarService to avoid EventKit conflicts.
    private var eventStore: EKEventStore { CalendarService.shared.eventStore }

    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableReminderLists: [EKCalendar] = []
    @Published var upcomingReminders: [AppleReminder] = []

    private var firedReminderIDs = Set<String>()
    private var alertFiredIDs = [UUID: Set<String>]()
    private var pollingTimer: Timer?
    private var fireCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastFireCheckDate = Date()

    private init() {
        setupNotifications()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestAccess() async throws {
        if #available(macOS 14.0, *) {
            let granted = try await eventStore.requestFullAccessToReminders()
            authorizationStatus = granted ? .fullAccess : .denied
        } else {
            let granted = try await eventStore.requestAccess(to: .reminder)
            authorizationStatus = granted ? .authorized : .denied
        }

        if hasAccess {
            await loadReminderLists()
            startPolling()
        }
    }

    var hasAccess: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .authorized
        } else {
            return authorizationStatus == .authorized
        }
    }

    var permissionDenied: Bool {
        authorizationStatus == .denied
    }

    // MARK: - Reminder List Management

    func loadReminderLists() async {
        guard hasAccess else { return }

        availableReminderLists = eventStore.calendars(for: .reminder)
            .sorted { $0.title < $1.title }

        // Auto-select all lists on first enable if none selected
        if AppSettings.shared.selectedReminderListIdentifiers.isEmpty {
            AppSettings.shared.selectedReminderListIdentifiers = Set(
                availableReminderLists.map { $0.calendarIdentifier }
            )
        }

        await fetchUpcomingReminders()
    }

    // MARK: - Fetching

    func fetchUpcomingReminders() async {
        guard hasAccess else { return }

        let selectedIdentifiers = AppSettings.shared.selectedReminderListIdentifiers
        guard !selectedIdentifiers.isEmpty else {
            upcomingReminders = []
            return
        }

        let selectedLists = availableReminderLists.filter {
            selectedIdentifiers.contains($0.calendarIdentifier)
        }
        guard !selectedLists.isEmpty else {
            upcomingReminders = []
            return
        }

        let store = self.eventStore
        let now = Date()
        let twoWeeks = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: now) ?? now

        // Only fetch incomplete reminders with due dates in the relevant window
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: now,
            ending: twoWeeks,
            calendars: selectedLists
        )

        let ekReminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        upcomingReminders = ekReminders
            .compactMap { AppleReminder(from: $0) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchUpcomingReminders()
            }
        }

        fireCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForRemindersToFire()
            }
        }

        Task {
            await fetchUpcomingReminders()
            checkForRemindersToFire()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        fireCheckTimer?.invalidate()
        fireCheckTimer = nil
    }

    // MARK: - Alert Triggering

    func checkForRemindersToFire() {
        guard !AppSettings.shared.isPaused else { return }
        guard AppSettings.shared.appleRemindersEnabled else { return }
        guard TrialManager.shared.trialState != .expired else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastFireCheckDate)
        lastFireCheckDate = now

        // Sleep detection — silently mark all past reminders as fired
        if elapsed > 10 {
            for reminder in upcomingReminders where reminder.dueDate <= now {
                firedReminderIDs.insert(reminder.id)
                for config in AppSettings.shared.reminderAlertConfigs {
                    alertFiredIDs[config.id, default: []].insert(reminder.id)
                }
            }
            return
        }

        let settings = AppSettings.shared

        for config in settings.reminderAlertConfigs {
            guard config.enabled else { continue }
            for reminder in upcomingReminders {
                guard !firedReminderIDs.contains(reminder.id) else { continue }
                guard !alertFiredIDs[config.id, default: []].contains(reminder.id) else { continue }
                let timeUntilDue = reminder.dueDate.timeIntervalSince(now)
                if timeUntilDue <= config.leadTime && timeUntilDue > -120 {
                    alertFiredIDs[config.id, default: []].insert(reminder.id)
                    fireAlert(config: config, for: reminder)
                }
            }
        }
    }

    private func fireAlert(config: AlertConfig, for reminder: AppleReminder) {
        if config.style == .fullScreen {
            firedReminderIDs.insert(reminder.id)
        }
        AlertMergeBuffer.shared.submit(
            item: .appleReminder(reminder),
            style: config.style,
            duration: config.miniDuration
        )
    }

    func markReminderAsFired(_ reminderID: String) {
        firedReminderIDs.insert(reminderID)
        objectWillChange.send()
    }

    func isReminderDisabled(_ reminderID: String) -> Bool {
        firedReminderIDs.contains(reminderID)
    }

    func reEnableReminder(_ reminderID: String) {
        firedReminderIDs.remove(reminderID)
        for key in alertFiredIDs.keys { alertFiredIDs[key]?.remove(reminderID) }
        PreAlertManager.shared.reEnablePreAlert(reminderID)
        objectWillChange.send()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // EKEventStoreChanged fires for both calendar and reminder changes
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadReminderLists()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("NSSystemClockDidChangeNotification"))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchUpcomingReminders()
                    self?.firedReminderIDs.removeAll()
                    self?.alertFiredIDs.removeAll()
                    PreAlertManager.shared.resetTracking()
                }
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchUpcomingReminders()
                }
            }
            .store(in: &cancellables)
    }
}

//
//  CalendarService.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import EventKit
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []
    @Published var upcomingEvents: [CalendarEvent] = []
    
    private var firedEventIDs = Set<String>()
    /// Tracks which events have fired for each alert config, keyed by AlertConfig.id.
    private var alertFiredIDs = [UUID: Set<String>]()
    /// Tracks which event alarm dates have already triggered, keyed by "eventID_alarmTimestamp".
    private var alarmFiredIDs = Set<String>()
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
        if #available(macOS 14.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    func requestAccess() async throws {
        print("Requesting calendar access...")
        print("Current authorization status: \(String(describing: self.authorizationStatus))")

        if #available(macOS 14.0, *) {
            print("Using macOS 14+ API (requestFullAccessToEvents)")
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                print("Permission granted: \(granted)")

                if granted {
                    authorizationStatus = .fullAccess
                    await loadCalendars()
                    startPolling()
                } else {
                    authorizationStatus = .denied
                    print("User denied access")
                }
            } catch {
                print("Error requesting access: \(error)")
                throw error
            }
        } else {
            print("Using pre-macOS 14 API (requestAccess)")
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                print("Permission granted: \(granted)")

                if granted {
                    authorizationStatus = .authorized
                    await loadCalendars()
                    startPolling()
                } else {
                    authorizationStatus = .denied
                    print("User denied access")
                }
            } catch {
                print("Error requesting access: \(error)")
                throw error
            }
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
    
    // MARK: - Calendar Management
    
    func loadCalendars() async {
        guard hasAccess else { return }
        
        availableCalendars = eventStore.calendars(for: .event)
            .sorted { $0.title < $1.title }
        
        // Auto-select all calendars on first launch if none selected
        if AppSettings.shared.selectedCalendarIdentifiers.isEmpty {
            AppSettings.shared.selectedCalendarIdentifiers = Set(
                availableCalendars.map { $0.calendarIdentifier }
            )
        }
        
        await fetchUpcomingEvents()
    }
    
    func getCalendar(byIdentifier identifier: String) -> EKCalendar? {
        eventStore.calendar(withIdentifier: identifier)
    }
    
    // MARK: - Event Fetching
    
    func fetchUpcomingEvents() async {
        guard hasAccess else { return }

        let selectedIdentifiers = AppSettings.shared.selectedCalendarIdentifiers
        guard !selectedIdentifiers.isEmpty else {
            upcomingEvents = []
            return
        }

        let selectedCalendars = availableCalendars.filter {
            selectedIdentifiers.contains($0.calendarIdentifier)
        }

        guard !selectedCalendars.isEmpty else {
            upcomingEvents = []
            return
        }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        let limit = AppSettings.shared.numberOfEventsInMenuBar
        let store = self.eventStore

        // Run the expensive EventKit query off the main thread so the UI
        // (especially full-screen alert overlays) never freezes.
        let events: [CalendarEvent] = await Task.detached(priority: .userInitiated) {
            let predicate = store.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: selectedCalendars
            )
            let mapped = store.events(matching: predicate)
                .map { CalendarEvent(from: $0) }
                .filter { $0.shouldTriggerAlert }
                .sorted { $0.startDate < $1.startDate }

            // Deduplicate — EventKit can return the same Google Calendar
            // event multiple times. Keep the first occurrence of each ID.
            var seen = Set<String>()
            return mapped.filter { seen.insert($0.id).inserted }
        }.value

        upcomingEvents = Array(events.prefix(limit))
    }
    
    // MARK: - Event Notifications
    
    private func setupNotifications() {
        // Listen for calendar database changes
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadCalendars()
                }
            }
            .store(in: &cancellables)
        
        // Listen for system clock changes
        NotificationCenter.default.publisher(for: NSNotification.Name("NSSystemClockDidChangeNotification"))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleClockChange()
                }
            }
            .store(in: &cancellables)
        
        // Listen for wake from sleep
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleWakeFromSleep()
                }
            }
            .store(in: &cancellables)

        // Re-fetch when number of events setting changes
        AppSettings.shared.$numberOfEventsInMenuBar
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchUpcomingEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Polling
    
    func startPolling() {
        stopPolling()

        // Fetch events from EventKit every 30 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchUpcomingEvents()
            }
        }

        // Check if any events need to fire every 1 second (cheap operation)
        fireCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForEventsToFire()
            }
        }

        Task {
            await fetchUpcomingEvents()
            checkForEventsToFire()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        fireCheckTimer?.invalidate()
        fireCheckTimer = nil
    }
    
    // MARK: - Alert Triggering
    
    func checkForEventsToFire() {
        guard !AppSettings.shared.isPaused else { return }
        guard AppSettings.shared.calendarAlertsEnabled else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastFireCheckDate)
        lastFireCheckDate = now

        // If more than 10 seconds elapsed since the last check, the system was
        // likely asleep (timer fires every 1s). Silently mark all past events
        // as fired so they don't trigger alerts.
        if elapsed > 10 {
            for event in upcomingEvents where event.startDate <= now {
                firedEventIDs.insert(event.id)
                for config in AppSettings.shared.alertConfigs {
                    alertFiredIDs[config.id, default: []].insert(event.id)
                }
                for alarmDate in event.alarmDates {
                    alarmFiredIDs.insert("\(event.id)_\(alarmDate.timeIntervalSinceReferenceDate)")
                }
            }
            return
        }

        let settings = AppSettings.shared

        for config in settings.alertConfigs {
            guard config.enabled else { continue }
            for event in upcomingEvents {
                guard !firedEventIDs.contains(event.id) else { continue }
                guard !alertFiredIDs[config.id, default: []].contains(event.id) else { continue }
                let timeUntilStart = event.startDate.timeIntervalSince(now)
                if timeUntilStart <= config.leadTime && timeUntilStart > -120 {
                    alertFiredIDs[config.id, default: []].insert(event.id)
                    fireAlert(config: config, for: event)
                }
            }
        }

        // Event alarm alerts — fire at the exact time a calendar alarm is set
        if settings.eventAlarmAlertsEnabled {
            for event in upcomingEvents {
                guard !firedEventIDs.contains(event.id) else { continue }
                for alarmDate in event.alarmDates {
                    let alarmKey = "\(event.id)_\(alarmDate.timeIntervalSinceReferenceDate)"
                    guard !alarmFiredIDs.contains(alarmKey) else { continue }
                    let timeUntilAlarm = alarmDate.timeIntervalSince(now)
                    if timeUntilAlarm <= 0 && timeUntilAlarm > -120 {
                        alarmFiredIDs.insert(alarmKey)
                        fireAlarmAlert(for: event)
                    }
                }
            }
        }
    }

    private func fireAlarmAlert(for event: CalendarEvent) {
        let settings = AppSettings.shared
        switch settings.eventAlarmAlertStyle {
        case .subtle:
            PreAlertManager.shared.showPreAlert(for: event, duration: settings.eventAlarmAlertDuration)
        case .fullScreen:
            firedEventIDs.insert(event.id)
            PreAlertManager.shared.dismiss()
            AlertCoordinator.shared.queueAlert(for: event)
        }
    }

    private func fireAlert(config: AlertConfig, for event: CalendarEvent) {
        switch config.style {
        case .subtle:
            PreAlertManager.shared.showPreAlert(for: event, duration: config.subtleDuration)
        case .fullScreen:
            firedEventIDs.insert(event.id)
            PreAlertManager.shared.dismiss()
            AlertCoordinator.shared.queueAlert(for: event)
        }
    }
    
    func markEventAsFired(_ eventID: String) {
        firedEventIDs.insert(eventID)
        objectWillChange.send()
    }

    func isEventDisabled(_ eventID: String) -> Bool {
        firedEventIDs.contains(eventID)
    }

    func reEnableEvent(_ eventID: String) {
        firedEventIDs.remove(eventID)
        for key in alertFiredIDs.keys { alertFiredIDs[key]?.remove(eventID) }
        alarmFiredIDs = alarmFiredIDs.filter { !$0.hasPrefix(eventID) }
        PreAlertManager.shared.reEnablePreAlert(eventID)
        objectWillChange.send()
    }
    
    // MARK: - System Event Handlers
    
    private func handleClockChange() async {
        // Recalculate all upcoming events
        await fetchUpcomingEvents()
        firedEventIDs.removeAll()
        alertFiredIDs.removeAll()
        alarmFiredIDs.removeAll()
        PreAlertManager.shared.resetTracking()
    }
    
    private func handleWakeFromSleep() async {
        // Refresh events from EventKit. The gap detection in
        // checkForEventsToFire() handles suppressing missed alerts.
        await fetchUpcomingEvents()
    }
    
    // MARK: - Calendar App Integration
    
    func openEventInCalendarApp(_ event: CalendarEvent) {
        // Open the user's default calendar app (whatever handles .ics files)
        if let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: .calendarEvent) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: defaultApp, configuration: config)
        } else if let fallback = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: fallback, configuration: config)
        }
    }
}

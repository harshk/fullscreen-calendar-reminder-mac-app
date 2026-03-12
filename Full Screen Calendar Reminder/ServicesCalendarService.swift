//
//  CalendarService.swift
//  Full Screen Calendar Reminder
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

    private let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []
    @Published var upcomingEvents: [CalendarEvent] = []
    
    private var firedEventIDs = Set<String>()
    private var pollingTimer: Timer?
    private var fireCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
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
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: startDate) ?? startDate
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

        let now = Date()

        // Pre-alert check: fire pre-alert for events approaching within lead time
        if AppSettings.shared.preAlertEnabled {
            let leadTime = AppSettings.shared.preAlertLeadTime
            for event in upcomingEvents {
                let timeUntilStart = event.startDate.timeIntervalSince(now)
                // Fire pre-alert when event is within lead time but hasn't started yet
                if timeUntilStart > 0 && timeUntilStart <= leadTime &&
                   !firedEventIDs.contains(event.id) {
                    PreAlertManager.shared.showPreAlert(for: event)
                }
            }
        }

        let eventsToFire = upcomingEvents.filter { event in
            !firedEventIDs.contains(event.id) &&
            event.startDate <= now &&
            event.startDate.timeIntervalSince(now) > -120 // Within 2 minutes
        }

        for event in eventsToFire {
            firedEventIDs.insert(event.id)
            // Dismiss any active pre-alert when the full-screen alert fires
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
        PreAlertManager.shared.reEnablePreAlert(eventID)
        objectWillChange.send()
    }
    
    // MARK: - System Event Handlers
    
    private func handleClockChange() async {
        // Recalculate all upcoming events
        await fetchUpcomingEvents()
        firedEventIDs.removeAll()
        PreAlertManager.shared.resetTracking()
    }
    
    private func handleWakeFromSleep() async {
        await fetchUpcomingEvents()
        
        // Fire events that started less than 2 minutes ago
        let now = Date()
        let twoMinutesAgo = now.addingTimeInterval(-120)
        
        let eventsToFire = upcomingEvents.filter { event in
            !firedEventIDs.contains(event.id) &&
            event.startDate >= twoMinutesAgo &&
            event.startDate <= now
        }
        
        for event in eventsToFire {
            firedEventIDs.insert(event.id)
            AlertCoordinator.shared.queueAlert(for: event)
        }
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

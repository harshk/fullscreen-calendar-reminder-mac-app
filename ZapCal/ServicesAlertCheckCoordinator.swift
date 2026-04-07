//
//  AlertCheckCoordinator.swift
//  ZapCal
//

import Foundation

/// Drives alert checking for all three services from a single timer that
/// fires at the top of each minute, then flushes the merge buffer so
/// alerts present immediately once every service has reported in.
@MainActor
class AlertCheckCoordinator {
    static let shared = AlertCheckCoordinator()

    private var fireCheckTimer: Timer?
    private init() {}

    func start() {
        stop()
        tick()
        scheduleNextMinuteTick()
    }

    func stop() {
        fireCheckTimer?.invalidate()
        fireCheckTimer = nil
    }

    private func scheduleNextMinuteTick() {
        let now = Date()
        let calendar = Calendar.current
        guard let nextMinute = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        let delay = nextMinute.timeIntervalSince(now)
        fireCheckTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
                self?.scheduleNextMinuteTick()
            }
        }
    }

    private func tick() {
        CalendarService.shared.checkForEventsToFire()
        ReminderService.shared.checkForRemindersToFire()
        AppleRemindersService.shared.checkForRemindersToFire()
        AlertMergeBuffer.shared.flush()
    }
}

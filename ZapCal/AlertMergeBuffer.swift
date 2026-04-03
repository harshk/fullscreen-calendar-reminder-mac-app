//
//  AlertMergeBuffer.swift
//  ZapCal
//

import Foundation
import SwiftUI

/// Buffers alerts that fire within a 10-second window and merges them
/// into a single presentation. Full-screen alerts take precedence over
/// mini alerts when mixed.
@MainActor
class AlertMergeBuffer {
    static let shared = AlertMergeBuffer()

    private var pendingItems: [(item: AlertItem, style: AlertStyle, duration: Double)] = []
    private var mergeTimer: Timer?
    private static let mergeWindowSeconds: TimeInterval = 10

    private init() {}

    /// Submit an alert to the buffer. It will be presented (possibly merged
    /// with others) after the merge window expires.
    func submit(item: AlertItem, style: AlertStyle, duration: Double) {
        // Don't add duplicates
        let id = item.id
        guard !pendingItems.contains(where: { $0.item.id == id }) else { return }

        pendingItems.append((item, style, duration))

        if mergeTimer == nil {
            mergeTimer = Timer.scheduledTimer(withTimeInterval: Self.mergeWindowSeconds, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.flush() }
            }
        }
    }

    /// Immediately present all buffered alerts (called when merge window expires).
    private func flush() {
        mergeTimer?.invalidate()
        mergeTimer = nil

        guard !pendingItems.isEmpty else { return }

        let items = pendingItems.map(\.item)
        let hasFullScreen = pendingItems.contains { $0.style == .fullScreen }
        let resolvedStyle: AlertStyle = hasFullScreen ? .fullScreen : .mini
        let earliestStart = items.compactMap(\.startDate).min() ?? Date()
        let duration = pendingItems.first(where: { $0.style == .mini })?.duration ?? 15

        pendingItems.removeAll()

        if items.count == 1 {
            // Single alert — use existing code paths
            let item = items[0]
            switch resolvedStyle {
            case .mini:
                PreAlertManager.shared.showMergedPreAlert(
                    titles: [item.title],
                    startDate: earliestStart,
                    color: item.calendarColor ?? .blue,
                    videoURL: item.videoConferenceURL,
                    eventID: item.id,
                    isMerged: false,
                    duration: duration
                )
            case .fullScreen:
                PreAlertManager.shared.dismiss()
                AlertCoordinator.shared.queueAlert(item: item)
            }
        } else {
            // Merged alert
            let displayTitles = Array(items.prefix(3).map(\.title))
            let overflowCount = max(0, items.count - 3)

            switch resolvedStyle {
            case .mini:
                PreAlertManager.shared.showMergedPreAlert(
                    titles: displayTitles,
                    startDate: earliestStart,
                    color: .blue,
                    videoURL: nil,
                    eventID: items.map(\.id).joined(separator: "_"),
                    isMerged: true,
                    overflowCount: overflowCount,
                    duration: duration
                )
            case .fullScreen:
                PreAlertManager.shared.dismiss()
                let mergedItem = AlertItem.merged(
                    titles: displayTitles,
                    overflowCount: overflowCount,
                    startDate: earliestStart,
                    sourceItems: items
                )
                AlertCoordinator.shared.queueAlert(item: mergedItem)
            }
        }
    }

    /// Clear the buffer (e.g. on clock change or pause).
    func reset() {
        mergeTimer?.invalidate()
        mergeTimer = nil
        pendingItems.removeAll()
    }
}

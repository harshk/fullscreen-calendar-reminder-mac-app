//
//  AlertMergeBuffer.swift
//  ZapCal

import Foundation
import SwiftUI

/// Collects alerts submitted by all three services during a single check cycle,
/// then presents them (merged if needed) when the coordinator calls flush().
@MainActor
class AlertMergeBuffer {
    static let shared = AlertMergeBuffer()

    private var pendingItems: [(item: AlertItem, style: AlertStyle, duration: Double)] = []

    private init() {}

    /// Submit an alert to the buffer. It will be presented when flush() is called.
    func submit(item: AlertItem, style: AlertStyle, duration: Double) {
        // Don't add duplicates
        let id = item.id
        guard !pendingItems.contains(where: { $0.item.id == id }) else { return }

        pendingItems.append((item, style, duration))
    }

    /// Present all buffered alerts (called by AlertCheckCoordinator after all
    /// services have checked in).
    func flush() {
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
        pendingItems.removeAll()
    }
}

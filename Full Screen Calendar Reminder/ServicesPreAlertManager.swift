//
//  PreAlertManager.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/9/26.
//

import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - Pre-Alert Manager

@MainActor
class PreAlertManager: ObservableObject {
    static let shared = PreAlertManager()

    @Published var isShowingPreAlert = false

    private var bannerWindow: NSPanel?
    private var countdownTimer: Timer?
    private var preAlertEventIDs = Set<String>()

    private init() {}

    // MARK: - Public API

    /// Show pre-alert for an upcoming calendar event.
    func showPreAlert(for event: CalendarEvent) {
        guard !preAlertEventIDs.contains(event.id) else { return }
        preAlertEventIDs.insert(event.id)
        isShowingPreAlert = true
        showBanner(eventID: event.id, title: event.title, startDate: event.startDate, color: event.calendar.color, videoURL: event.videoConferenceURL)
    }

    /// Show pre-alert for an upcoming custom reminder.
    func showPreAlert(for reminder: CustomReminder) {
        let id = reminder.id.uuidString
        guard !preAlertEventIDs.contains(id) else { return }
        preAlertEventIDs.insert(id)
        isShowingPreAlert = true
        showBanner(eventID: id, title: reminder.title, startDate: reminder.scheduledDate, color: .orange, videoURL: nil)
    }

    /// Dismiss everything and clean up.
    func dismiss() {
        guard isShowingPreAlert else { return }

        dismissBanner()
        countdownTimer?.invalidate()
        countdownTimer = nil
        isShowingPreAlert = false
    }

    /// Mark an event as already pre-alerted so it won't trigger again.
    func markAsPreAlerted(_ eventID: String) {
        preAlertEventIDs.insert(eventID)
    }

    /// Re-enable pre-alerts for an event.
    func reEnablePreAlert(_ eventID: String) {
        preAlertEventIDs.remove(eventID)
    }

    /// Reset tracking (e.g. on clock change).
    func resetTracking() {
        preAlertEventIDs.removeAll()
    }

    /// Test/preview the pre-alert with a mock event.
    func showTestPreAlert() {
        showTestPreAlert(for: CalendarEvent.mock())
    }

    /// Test/preview the pre-alert with a specific event.
    func showTestPreAlert(for event: CalendarEvent) {
        dismiss()
        isShowingPreAlert = true
        showBanner(eventID: event.id, title: event.title, startDate: event.startDate, color: event.calendar.color, videoURL: event.videoConferenceURL)
    }

    // MARK: - Floating Banner

    private func showBanner(eventID: String, title: String, startDate: Date, color: Color, videoURL: URL?) {
        dismissBanner()

        guard let screen = NSScreen.main else { return }
        let bannerWidth: CGFloat = 460
        let bannerHeight: CGFloat = 108

        let x = screen.frame.midX - bannerWidth / 2
        let menuBarHeight: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let yVisible = screen.frame.maxY - menuBarHeight - bannerHeight - 12

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: yVisible, width: bannerWidth, height: bannerHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true

        let bannerContent = PreAlertBannerView(
            title: title,
            startDate: startDate,
            color: color,
            videoURL: videoURL,
            onDismiss: { [weak self] in
                DispatchQueue.main.async { self?.dismiss() }
            },
            onJoin: { url in
                DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            },
            onDisableAlerts: { [weak self] in
                DispatchQueue.main.async {
                    CalendarService.shared.markEventAsFired(eventID)
                    self?.markAsPreAlerted(eventID)
                    self?.dismiss()
                }
            }
        )

        let hostingView = FirstClickHostingView(rootView: bannerContent)
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: bannerWidth, height: bannerHeight))
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        bannerWindow = panel
        panel.orderFrontRegardless()

        // Auto-dismiss banner if configured
        let bannerDuration = AppSettings.shared.preAlertDuration
        if bannerDuration > 0 {
            // 0 means persist until event starts
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: bannerDuration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.dismiss() }
            }
        }
    }

    private func dismissBanner() {
        guard let panel = bannerWindow else { return }
        bannerWindow = nil
        panel.contentView = nil
        panel.orderOut(nil)
        DispatchQueue.main.async {
            panel.close()
        }
    }
}

// MARK: - SwiftUI Banner View

struct PreAlertBannerView: View {
    let title: String
    let startDate: Date
    let color: Color
    let videoURL: URL?
    let onDismiss: () -> Void
    let onJoin: (URL) -> Void
    let onDisableAlerts: () -> Void

    @State private var countdown: String = ""
    @State private var progress: CGFloat = 1.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let bannerDuration = AppSettings.shared.preAlertDuration

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Dismiss X button with progress ring
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 28, height: 28)

                if bannerDuration > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white.opacity(0.4), lineWidth: 2.5)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .contentShape(Circle())
            .onTapGesture {
                onDismiss()
            }

            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                }

                // Countdown timer
                Text(countdown)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

            // Bottom row: Disable and Join buttons
            HStack(spacing: 8) {
                Text(AppStrings.disableAlertsForEvent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.red.opacity(0.8)))
                    .contentShape(Capsule())
                    .onTapGesture {
                        onDisableAlerts()
                    }

                if let videoURL {
                    Text("Join")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(red: 0.2, green: 0.6, blue: 1.0)))
                        .contentShape(Capsule())
                        .onTapGesture {
                            onJoin(videoURL)
                            onDismiss()
                        }
                }

                Spacer()
            }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.95))
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .onAppear {
            updateCountdown()
            if bannerDuration > 0 {
                withAnimation(.linear(duration: bannerDuration)) {
                    progress = 0.0
                }
            }
        }
        .onReceive(timer) { _ in updateCountdown() }
    }

    private func updateCountdown() {
        let remaining = startDate.timeIntervalSinceNow
        if remaining <= 0 {
            countdown = "Now"
        } else {
            let totalSeconds = Int(remaining)
            let days = totalSeconds / 86400
            let hours = (totalSeconds % 86400) / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if days > 0 {
                countdown = "Starts in \(days)d \(hours)h"
            } else if hours > 0 {
                countdown = "Starts in \(hours)h \(minutes)m"
            } else {
                countdown = "Starts in \(minutes):\(String(format: "%02d", seconds))"
            }
        }
    }
}

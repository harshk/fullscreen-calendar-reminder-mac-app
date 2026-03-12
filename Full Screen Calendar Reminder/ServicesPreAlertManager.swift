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
        showBanner(title: event.title, startDate: event.startDate, color: event.calendar.color, videoURL: event.videoConferenceURL)
    }

    /// Show pre-alert for an upcoming custom reminder.
    func showPreAlert(for reminder: CustomReminder) {
        let id = reminder.id.uuidString
        guard !preAlertEventIDs.contains(id) else { return }
        preAlertEventIDs.insert(id)
        isShowingPreAlert = true
        showBanner(title: reminder.title, startDate: reminder.scheduledDate, color: .orange, videoURL: nil)
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
        showBanner(title: event.title, startDate: event.startDate, color: event.calendar.color, videoURL: event.videoConferenceURL)
    }

    // MARK: - Floating Banner

    private func showBanner(title: String, startDate: Date, color: Color, videoURL: URL?) {
        dismissBanner()

        guard let screen = NSScreen.main else { return }
        let bannerWidth: CGFloat = 460
        let bannerHeight: CGFloat = 72

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

    @State private var countdown: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            // Title
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Countdown timer
            Text(countdown)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.8))

            // Join button (conditional)
            if let videoURL {
                Text("Join")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.2, green: 0.6, blue: 1.0))
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onJoin(videoURL)
                        onDismiss()
                    }
            }

            // Dismiss X button
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 22, height: 22)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .contentShape(Circle())
            .onTapGesture {
                onDismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.16).opacity(0.95))
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .onAppear { updateCountdown() }
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

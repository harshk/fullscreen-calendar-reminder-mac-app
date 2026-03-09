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
import QuartzCore

// MARK: - Pre-Alert Manager

@MainActor
class PreAlertManager: ObservableObject {
    static let shared = PreAlertManager()

    @Published var isShowingPreAlert = false

    private var glowWindows: [NSPanel] = []
    private var bannerWindow: NSPanel?
    private var countdownTimer: Timer?
    private var autoDismissTimer: Timer?
    private var preAlertEventIDs = Set<String>()

    private var currentEvent: CalendarEvent?

    private init() {}

    // MARK: - Public API

    /// Show pre-alert for an upcoming calendar event.
    func showPreAlert(for event: CalendarEvent) {
        guard !preAlertEventIDs.contains(event.id) else { return }
        preAlertEventIDs.insert(event.id)

        currentEvent = event
        isShowingPreAlert = true

        showGlow(for: event)
        showBanner(for: event)
    }

    /// Dismiss everything and clean up.
    func dismiss() {
        guard isShowingPreAlert else { return }

        dismissGlow()
        dismissBanner()
        countdownTimer?.invalidate()
        countdownTimer = nil
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        currentEvent = nil
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
        // Don't track test events so they can be re-triggered
        currentEvent = event
        isShowingPreAlert = true
        showGlow(for: event)
        showBanner(for: event)
    }

    // MARK: - Screen Border Glow

    private func showGlow(for event: CalendarEvent) {
        dismissGlow()

        let glowColor = glowNSColor(for: event)
        let duration = AppSettings.shared.preAlertDuration

        for screen in NSScreen.screens {
            let window = createGlowWindow(for: screen, color: glowColor)
            glowWindows.append(window)
            window.orderFrontRegardless()
        }

        // Auto-dismiss glow after configured duration (0 = persist until event starts)
        if duration > 0 {
            autoDismissTimer?.invalidate()
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.dismissGlow() }
            }
        }
    }

    private func createGlowWindow(for screen: NSScreen, color: NSColor) -> NSPanel {
        // Use NSPanel + .nonactivatingPanel — the same pattern the full-screen
        // alert uses.  Plain NSWindow with .borderless confuses AppKit's event
        // routing in .accessory apps and causes objc_release crashes during
        // mouse hit-testing.
        let panel = NSPanel(
            contentRect: screen.frame,
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
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        let glowView = GlowBorderView(frame: NSRect(origin: .zero, size: screen.frame.size))
        glowView.glowColor = color
        glowView.autoresizingMask = [.width, .height]
        panel.contentView = glowView

        // Start pulsing animation
        glowView.startPulsing()

        return panel
    }

    private func dismissGlow() {
        // Capture windows, then clear the array so nothing references them
        // during the current run loop pass.  Use orderOut (not close) to
        // remove from the screen without triggering deallocation cascades
        // that crash when the window server is still hit-testing for mouse
        // events.  Defer the actual teardown to the next run loop pass.
        let windows = glowWindows
        glowWindows.removeAll()
        for window in windows {
            (window.contentView as? GlowBorderView)?.stopPulsing()
            window.contentView = nil
            window.orderOut(nil)
        }
        DispatchQueue.main.async {
            for window in windows { window.close() }
        }
    }

    private func glowNSColor(for event: CalendarEvent) -> NSColor {
        let theme = ThemeService.shared.getTheme(for: event.calendar.identifier)
        if let glowStyle = theme.elementStyles[.preAlertGlow] {
            let c = glowStyle.fontColor
            return NSColor(red: c.red, green: c.green, blue: c.blue, alpha: c.opacity)
        }
        // Default warm amber
        return NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    }

    // MARK: - Floating Banner

    private func showBanner(for event: CalendarEvent) {
        dismissBanner()

        guard let screen = NSScreen.main else { return }
        let bannerWidth: CGFloat = 460
        let bannerHeight: CGFloat = 72

        let x = screen.frame.midX - bannerWidth / 2
        let menuBarHeight: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let yVisible = screen.frame.maxY - menuBarHeight - bannerHeight - 12

        // NSPanel + .nonactivatingPanel: the same pattern the full-screen alert
        // uses.  Properly integrates with AppKit event routing in .accessory apps.
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
            event: event,
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

// MARK: - Glow Border View (Core Animation)

class GlowBorderView: NSView {
    var glowColor: NSColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    private var borderLayer: CAShapeLayer?
    private var pulseAnimation: CABasicAnimation?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func layout() {
        super.layout()
        updateBorderLayer()
    }

    private func updateBorderLayer() {
        borderLayer?.removeFromSuperlayer()

        let borderWidth: CGFloat = 10
        let inset = borderWidth / 2
        let path = CGPath(
            rect: bounds.insetBy(dx: inset, dy: inset),
            transform: nil
        )

        let shape = CAShapeLayer()
        shape.path = path
        shape.fillColor = nil
        shape.strokeColor = glowColor.cgColor
        shape.lineWidth = borderWidth
        shape.shadowColor = glowColor.cgColor
        shape.shadowRadius = 20
        shape.shadowOpacity = 1.0
        shape.shadowOffset = .zero

        layer?.addSublayer(shape)
        borderLayer = shape
    }

    func startPulsing() {
        updateBorderLayer()

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.4
        anim.toValue = 0.9
        anim.duration = 1.5
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        borderLayer?.add(anim, forKey: "pulse")
        pulseAnimation = anim
    }

    func stopPulsing() {
        borderLayer?.removeAnimation(forKey: "pulse")
    }
}

// MARK: - SwiftUI Banner View

struct PreAlertBannerView: View {
    let event: CalendarEvent
    let onDismiss: () -> Void
    let onJoin: (URL) -> Void

    @State private var countdown: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // Calendar color dot
            Circle()
                .fill(event.calendar.color)
                .frame(width: 10, height: 10)

            // Event title
            Text(event.title)
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
            if let videoURL = event.videoConferenceURL {
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
        let remaining = event.startDate.timeIntervalSinceNow
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

//
//  PreAlertManager.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/9/26.
//

import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - Mini Alert Manager

@MainActor
class PreAlertManager: ObservableObject {
    static let shared = PreAlertManager()

    var isShowingPreAlert = false

    private var bannerWindow: NSPanel?
    private var countdownTimer: Timer?
    private var preAlertEventIDs = Set<String>()

    private init() {}

    // MARK: - Public API

    /// Show mini alert for an upcoming calendar event.
    /// - Parameter dedupKey: Optional key for deduplication. When provided (e.g.
    ///   an alarm-specific key), this key is checked instead of the event ID so
    ///   that multiple alarms on the same event can each show a banner.
    func showPreAlert(for event: CalendarEvent, dedupKey: String? = nil, duration: Double? = nil) {
        let key = dedupKey ?? event.id
        guard !preAlertEventIDs.contains(key) else { return }
        preAlertEventIDs.insert(key)
        isShowingPreAlert = true
        let theme = ThemeService.shared.getPreAlertTheme(for: event.calendar.identifier)
        showBanner(eventID: event.id, title: event.title, startDate: event.startDate, color: event.calendar.color, videoURL: event.videoConferenceURL, preAlertTheme: theme, duration: duration)
    }

    /// Show mini alert for an upcoming Apple Reminder.
    func showPreAlert(for appleReminder: AppleReminder, duration: Double? = nil) {
        guard !preAlertEventIDs.contains(appleReminder.id) else { return }
        preAlertEventIDs.insert(appleReminder.id)
        isShowingPreAlert = true
        let theme = ThemeService.shared.getPreAlertTheme(for: appleReminder.reminderList.identifier)
        showBanner(eventID: appleReminder.id, title: appleReminder.title, startDate: appleReminder.dueDate, color: appleReminder.reminderList.color, videoURL: nil, preAlertTheme: theme, duration: duration)
    }

    /// Show mini alert for an upcoming custom reminder.
    func showPreAlert(for reminder: CustomReminder, duration: Double? = nil) {
        let id = reminder.id.uuidString
        guard !preAlertEventIDs.contains(id) else { return }
        preAlertEventIDs.insert(id)
        isShowingPreAlert = true
        let theme = ThemeService.shared.getPreAlertTheme(for: nil)
        showBanner(eventID: id, title: reminder.title, startDate: reminder.scheduledDate, color: .orange, videoURL: nil, preAlertTheme: theme, duration: duration)
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

    /// Show a merged pre-alert (called by AlertMergeBuffer).
    func showMergedPreAlert(
        titles: [String],
        startDate: Date,
        color: Color,
        videoURL: URL?,
        eventID: String,
        isMerged: Bool,
        overflowCount: Int = 0,
        duration: Double? = nil
    ) {
        guard !preAlertEventIDs.contains(eventID) else { return }
        preAlertEventIDs.insert(eventID)
        isShowingPreAlert = true
        let theme = ThemeService.shared.getPreAlertTheme(for: nil)
        let effectiveDuration = duration ?? firstMiniDuration()

        if isMerged {
            showMergedBanner(eventID: eventID, titles: titles, overflowCount: overflowCount, startDate: startDate, color: color, preAlertTheme: theme, duration: effectiveDuration)
        } else {
            showBanner(eventID: eventID, title: titles.first ?? "", startDate: startDate, color: color, videoURL: videoURL, preAlertTheme: theme, duration: effectiveDuration)
        }
    }

    /// Test/preview the pre-alert with a mock event.
    func showTestPreAlert() {
        showTestPreAlert(for: CalendarEvent.mock())
    }

    /// Test/preview the pre-alert with a specific event.
    func showTestPreAlert(for event: CalendarEvent) {
        dismiss()
        isShowingPreAlert = true
        let theme = ThemeService.shared.getPreAlertTheme(for: event.calendar.identifier)
        showBanner(eventID: event.id, title: event.title, startDate: event.startDate, color: event.calendar.color, videoURL: event.videoConferenceURL, preAlertTheme: theme)
    }

    func showTestPreAlert(theme: PreAlertTheme) {
        dismiss()
        isShowingPreAlert = true
        let mock = CalendarEvent.mock()
        showBanner(eventID: mock.id, title: mock.title, startDate: mock.startDate, color: mock.calendar.color, videoURL: mock.videoConferenceURL, preAlertTheme: theme)
    }

    // MARK: - Floating Banner

    /// Observable state for the reusable banner view.
    private let bannerState = PreAlertBannerState()

    private func showBanner(eventID: String, title: String, startDate: Date, color: Color, videoURL: URL?, preAlertTheme: PreAlertTheme, duration: Double? = nil) {
        dismissBanner()

        guard let screen = NSScreen.main else { return }
        let bannerWidth: CGFloat = 460
        let bannerHeight: CGFloat = 108

        // Pre-render background image
        let blurRadius = (preAlertTheme.imageBlurRadius ?? 0.3) * 30
        let scale = screen.backingScaleFactor
        let bgImage: NSImage? = preAlertTheme.imageFileName.flatMap {
            ImageStore.loadBlurred($0, targetSize: CGSize(width: bannerWidth * scale, height: bannerHeight * scale), blurRadius: blurRadius)
        }

        // Update all state in a single batch — one SwiftUI re-render
        let effectiveDuration = duration ?? firstMiniDuration()
        bannerState.show(eventID: eventID, title: title, startDate: startDate, color: color, videoURL: videoURL, theme: preAlertTheme, backgroundImage: bgImage, duration: effectiveDuration)

        let x = screen.frame.midX - bannerWidth / 2
        let menuBarHeight: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let yVisible = screen.frame.maxY - menuBarHeight - bannerHeight - 12

        if let panel = bannerWindow {
            // Reuse existing window — just reposition and show
            panel.setFrame(NSRect(x: x, y: yVisible, width: bannerWidth, height: bannerHeight), display: false)
            panel.orderFrontRegardless()
        } else {
            // First time — create the window and hosting view
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
            panel.hasShadow = true
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false
            panel.acceptsMouseMovedEvents = true

            let bannerContent = PreAlertBannerView(
                bannerState: bannerState,
                onDismiss: { [weak self] in
                    DispatchQueue.main.async { self?.dismiss() }
                },
                onJoin: { url in
                    DispatchQueue.main.async { NSWorkspace.shared.open(url) }
                },
                onDisableAlerts: { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        let eid = self.bannerState.eventID
                        CalendarService.shared.markEventAsFired(eid)
                        self.markAsPreAlerted(eid)
                        self.dismiss()
                    }
                }
            )

            let hostingView = TransparentHostingView(rootView: bannerContent)
            hostingView.frame = NSRect(origin: .zero, size: NSSize(width: bannerWidth, height: bannerHeight))
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView

            bannerWindow = panel
            panel.orderFrontRegardless()
        }

        // Auto-dismiss banner if configured
        if effectiveDuration > 0 {
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: effectiveDuration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.dismiss() }
            }
        }
    }

    private func showMergedBanner(eventID: String, titles: [String], overflowCount: Int, startDate: Date, color: Color, preAlertTheme: PreAlertTheme, duration: Double) {
        dismissBanner()

        guard let screen = NSScreen.main else { return }
        let bannerWidth: CGFloat = 460
        let extraLines = max(0, titles.count - 1) + (overflowCount > 0 ? 1 : 0)
        let bannerHeight: CGFloat = 108 + CGFloat(extraLines) * 22

        let blurRadius = (preAlertTheme.imageBlurRadius ?? 0.3) * 30
        let scale = screen.backingScaleFactor
        let bgImage: NSImage? = preAlertTheme.imageFileName.flatMap {
            ImageStore.loadBlurred($0, targetSize: CGSize(width: bannerWidth * scale, height: bannerHeight * scale), blurRadius: blurRadius)
        }

        bannerState.showMerged(eventID: eventID, titles: titles, overflowCount: overflowCount, startDate: startDate, color: color, theme: preAlertTheme, backgroundImage: bgImage, duration: duration)

        let x = screen.frame.midX - bannerWidth / 2
        let menuBarHeight: CGFloat = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let yVisible = screen.frame.maxY - menuBarHeight - bannerHeight - 12

        if let panel = bannerWindow {
            panel.setFrame(NSRect(x: x, y: yVisible, width: bannerWidth, height: bannerHeight), display: false)
            panel.orderFrontRegardless()
        } else {
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
            panel.hasShadow = true
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false
            panel.acceptsMouseMovedEvents = true

            let bannerContent = PreAlertBannerView(
                bannerState: bannerState,
                onDismiss: { [weak self] in
                    DispatchQueue.main.async { self?.dismiss() }
                },
                onJoin: { url in
                    DispatchQueue.main.async { NSWorkspace.shared.open(url) }
                },
                onDisableAlerts: { [weak self] in
                    DispatchQueue.main.async { self?.dismiss() }
                }
            )

            let hostingView = TransparentHostingView(rootView: bannerContent)
            hostingView.frame = NSRect(origin: .zero, size: NSSize(width: bannerWidth, height: bannerHeight))
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView

            bannerWindow = panel
            panel.orderFrontRegardless()
        }

        if duration > 0 {
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.dismiss() }
            }
        }
    }

    /// Returns the duration from the first enabled mini alert config, or 15 as fallback.
    private func firstMiniDuration() -> Double {
        AppSettings.shared.alertConfigs.first(where: { $0.enabled && $0.style == .mini })?.miniDuration ?? 15
    }

    private func dismissBanner() {
        bannerState.hide()
        bannerWindow?.orderOut(nil)
    }
}

// MARK: - Mini Alert Banner State

/// Observable state for the reusable banner window. Uses manual
/// objectWillChange to batch all updates into a single re-render.
class PreAlertBannerState: ObservableObject {
    var title: String = ""
    var startDate: Date = Date()
    var color: Color = .blue
    var videoURL: URL? = nil
    var preAlertTheme: PreAlertTheme = PreAlertTheme.defaultTheme()
    var backgroundImage: NSImage? = nil
    var eventID: String = ""
    var isVisible: Bool = false
    var bannerDuration: Double = 15
    var isMerged: Bool = false
    var mergedTitles: [String] = []
    var overflowCount: Int = 0

    func show(eventID: String, title: String, startDate: Date, color: Color, videoURL: URL?, theme: PreAlertTheme, backgroundImage: NSImage?, duration: Double = 15) {
        self.eventID = eventID
        self.title = title
        self.startDate = startDate
        self.color = color
        self.videoURL = videoURL
        self.preAlertTheme = theme
        self.backgroundImage = backgroundImage
        self.bannerDuration = duration
        self.isMerged = false
        self.mergedTitles = []
        self.overflowCount = 0
        self.isVisible = true
        objectWillChange.send()
    }

    func showMerged(eventID: String, titles: [String], overflowCount: Int, startDate: Date, color: Color, theme: PreAlertTheme, backgroundImage: NSImage?, duration: Double = 15) {
        self.eventID = eventID
        self.title = titles.first ?? ""
        self.mergedTitles = titles
        self.overflowCount = overflowCount
        self.isMerged = true
        self.startDate = startDate
        self.color = color
        self.videoURL = nil
        self.preAlertTheme = theme
        self.backgroundImage = backgroundImage
        self.bannerDuration = duration
        self.isVisible = true
        objectWillChange.send()
    }

    func hide() {
        isVisible = false
        backgroundImage = nil
        objectWillChange.send()
    }
}

// MARK: - SwiftUI Banner View

struct PreAlertBannerView: View {
    @ObservedObject private var bannerState: PreAlertBannerState
    let onDismiss: () -> Void
    let onJoin: (URL) -> Void
    let onDisableAlerts: () -> Void

    // Direct-mode overrides (for settings preview)
    private let directTitle: String?
    private let directStartDate: Date?
    private let directColor: Color?
    private let directVideoURL: URL??
    private let directTheme: PreAlertTheme?
    private let directBackgroundImage: NSImage??
    private let directDuration: Double?

    private var title: String { directTitle ?? bannerState.title }
    private var startDate: Date { directStartDate ?? bannerState.startDate }
    private var color: Color { directColor ?? bannerState.color }
    private var videoURL: URL? { directVideoURL ?? bannerState.videoURL }
    private var preAlertTheme: PreAlertTheme { directTheme ?? bannerState.preAlertTheme }
    private var backgroundImage: NSImage? { directBackgroundImage ?? bannerState.backgroundImage }

    @State private var countdown: String = ""
    @State private var progress: CGFloat = 1.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var bannerDuration: Double { directDuration ?? bannerState.bannerDuration }

    /// State-driven init — used by the reusable banner window.
    init(
        bannerState: PreAlertBannerState,
        onDismiss: @escaping () -> Void,
        onJoin: @escaping (URL) -> Void,
        onDisableAlerts: @escaping () -> Void
    ) {
        self.bannerState = bannerState
        self.onDismiss = onDismiss
        self.onJoin = onJoin
        self.onDisableAlerts = onDisableAlerts
        self.directTitle = nil
        self.directStartDate = nil
        self.directColor = nil
        self.directVideoURL = nil
        self.directTheme = nil
        self.directBackgroundImage = nil
        self.directDuration = nil
    }

    /// Direct init — used by settings preview.
    init(
        title: String,
        startDate: Date,
        color: Color,
        videoURL: URL?,
        preAlertTheme: PreAlertTheme,
        backgroundImage: NSImage?,
        duration: Double = 15,
        onDismiss: @escaping () -> Void,
        onJoin: @escaping (URL) -> Void,
        onDisableAlerts: @escaping () -> Void
    ) {
        self.bannerState = PreAlertBannerState()
        self.onDismiss = onDismiss
        self.onJoin = onJoin
        self.onDisableAlerts = onDisableAlerts
        self.directTitle = title
        self.directStartDate = startDate
        self.directColor = color
        self.directVideoURL = .some(videoURL)
        self.directTheme = preAlertTheme
        self.directBackgroundImage = .some(backgroundImage)
        self.directDuration = duration
    }

    private var isStateDriven: Bool { directTitle == nil }

    var body: some View {
        if isStateDriven && !bannerState.isVisible {
            Color.clear.frame(width: 0, height: 0)
        } else {
            bannerContent
        }
    }

    private var bannerContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Dismiss X button with progress ring
            ZStack {
                Circle()
                    .fill(preAlertTheme.dismissButtonColor.color)
                    .frame(width: 28, height: 28)

                if bannerDuration > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(preAlertTheme.progressRingColor.color, lineWidth: 2.5)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(preAlertTheme.dismissIconColor.color)
            }
            .contentShape(Circle())
            .onTapGesture {
                onDismiss()
            }

            VStack(alignment: .leading, spacing: 8) {
                // Title row(s)
                if bannerState.isMerged && isStateDriven {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(bannerState.mergedTitles, id: \.self) { t in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(preAlertTheme.titleColor.color)
                                    .frame(width: 5, height: 5)
                                Text(t)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(preAlertTheme.titleColor.color)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        if bannerState.overflowCount > 0 {
                            Text("and \(bannerState.overflowCount) more")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(preAlertTheme.titleColor.color.opacity(0.6))
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(preAlertTheme.titleColor.color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                    }
                }

                // Countdown timer
                Text(countdown)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(preAlertTheme.countdownColor.color)
                    .frame(maxWidth: .infinity, alignment: .leading)

            // Bottom row: Disable and Join buttons
            if !(bannerState.isMerged && isStateDriven) {
            HStack(spacing: 8) {
                Text(AppStrings.disableAlertsForEvent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(preAlertTheme.disableButtonTextColor.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(preAlertTheme.disableButtonBackgroundColor.color))
                    .contentShape(Capsule())
                    .onTapGesture {
                        onDisableAlerts()
                    }

                if let videoURL {
                    Text("Join")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(preAlertTheme.joinButtonTextColor.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(preAlertTheme.joinButtonBackgroundColor.color))
                        .contentShape(Capsule())
                        .onTapGesture {
                            onJoin(videoURL)
                            onDismiss()
                        }
                }

                Spacer()
            }
            } // if not merged
            } // VStack
        } // HStack
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            bannerBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            updateCountdown()
            if bannerDuration > 0 {
                withAnimation(.linear(duration: bannerDuration)) {
                    progress = 0.0
                }
            }
        }
        .onChange(of: bannerState.isVisible) { visible in
            if visible {
                progress = 1.0
                updateCountdown()
                if bannerDuration > 0 {
                    withAnimation(.linear(duration: bannerDuration)) {
                        progress = 0.0
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            if isStateDriven && !bannerState.isVisible { return }
            updateCountdown()
        }
    }

    @ViewBuilder
    private var bannerBackground: some View {
        switch preAlertTheme.backgroundType {
        case .solidColor:
            RoundedRectangle(cornerRadius: 14)
                .fill(preAlertTheme.backgroundColor.color.opacity(preAlertTheme.backgroundOpacity))
        case .image:
            if let nsImage = backgroundImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        preAlertTheme.overlayColor.color.opacity(preAlertTheme.overlayOpacity)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(preAlertTheme.backgroundColor.color.opacity(preAlertTheme.backgroundOpacity))
            }
        }
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

// MARK: - Transparent Hosting View

class TransparentHostingView<Content: View>: NSHostingView<Content> {
    // Explicit deinit works around a Swift 6.2 compiler crash in the
    // EarlyPerfInliner SIL pass when archiving with optimizations.
    deinit {}

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if window?.isKeyWindow != true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
        super.mouseDown(with: event)
    }
}

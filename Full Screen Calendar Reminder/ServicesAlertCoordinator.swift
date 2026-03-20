//
//  AlertCoordinator.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Foundation
import SwiftUI
import AppKit
import Combine

enum AlertItem: Identifiable {
    case calendarEvent(CalendarEvent)
    case customReminder(CustomReminder)
    
    var id: String {
        switch self {
        case .calendarEvent(let event):
            return event.id
        case .customReminder(let reminder):
            return reminder.id.uuidString
        }
    }
    
    var title: String {
        switch self {
        case .calendarEvent(let event):
            return event.title
        case .customReminder(let reminder):
            return reminder.title
        }
    }
    
    var startDate: Date {
        switch self {
        case .calendarEvent(let event):
            return event.startDate
        case .customReminder(let reminder):
            return reminder.scheduledDate
        }
    }

    var endDate: Date? {
        switch self {
        case .calendarEvent(let event):
            return event.endDate
        case .customReminder:
            return nil
        }
    }

    var calendarIdentifier: String? {
        switch self {
        case .calendarEvent(let event):
            return event.calendar.identifier
        case .customReminder:
            return nil
        }
    }
}

/// NSPanel can receive key + mouse events even when the app is not
/// the active application — unlike NSWindow which silently drops them.
/// This is the critical difference that prevents the "frozen overlay" bug
/// when alerts are triggered from a background timer.
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// NSHostingView subclass that:
/// 1. Accepts the very first mouse-down even when the app is inactive
/// 2. Forces app activation + key window status on any click, so that
///    SwiftUI gesture handlers fire reliably even if macOS didn't
///    activate the app when the overlay first appeared.
class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if window?.isKeyWindow != true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
        super.mouseDown(with: event)
    }
}

@MainActor
class AlertCoordinator: ObservableObject {
    static let shared = AlertCoordinator()
    
    var alertQueue: [AlertItem] = []
    var isShowingAlert = false

    private var alertWindows: [NSWindow] = []
    private var alertHostingViews: [FirstClickHostingView<FullScreenAlertView>] = []
    private var globalKeyMonitor: Any?
    private var snoozeTimers: [Timer] = []

    private var previewLocalMonitor: Any?
    private var previewGlobalMonitor: Any?
    private var isPreviewMode = false

    private init() {
        setupKeyMonitor()
    }
    
    // MARK: - Queue Management
    
    func queueAlert(for event: CalendarEvent) {
        let item = AlertItem.calendarEvent(event)
        
        // Check if already in queue
        guard !alertQueue.contains(where: { $0.id == item.id }) else { return }
        
        alertQueue.append(item)
        alertQueue.sort { $0.startDate < $1.startDate }
        
        if !isShowingAlert {
            showNextAlert()
        }
    }
    
    func queueAlert(for reminder: CustomReminder) {
        let item = AlertItem.customReminder(reminder)
        
        // Check if already in queue
        guard !alertQueue.contains(where: { $0.id == item.id }) else { return }
        
        // Calendar events take priority, so append custom reminders after
        if let lastEventIndex = alertQueue.lastIndex(where: {
            if case .calendarEvent = $0 { return true }
            return false
        }) {
            alertQueue.insert(item, at: lastEventIndex + 1)
        } else {
            alertQueue.append(item)
        }
        
        if !isShowingAlert {
            showNextAlert()
        }
    }
    
    func showNextAlert() {
        guard !alertQueue.isEmpty else {
            isShowingAlert = false
            return
        }
        
        isShowingAlert = true
        let alertItem = alertQueue[0]
        
        displayFullScreenAlert(for: alertItem)
    }
    
    func snoozeCurrentAlert(for duration: TimeInterval) {
        guard !alertQueue.isEmpty else { return }
        let snoozedItem = alertQueue[0]

        hideAlertWindows()
        alertQueue.removeFirst()

        // Schedule the snoozed alert to re-appear after the duration
        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.snoozeTimers.removeAll { $0 === timer }
                // Append (not insert at 0) — the currently displayed alert
                // occupies position 0, and dismissCurrentAlert removes [0].
                // Inserting at 0 would cause dismiss to remove the snoozed
                // item instead of the one being displayed.
                self.alertQueue.append(snoozedItem)
                if !self.isShowingAlert {
                    self.showNextAlert()
                }
            }
        }
        snoozeTimers.append(timer)

        // Show next alert or clean up
        if !alertQueue.isEmpty {
            showNextAlert()
        } else {
            isShowingAlert = false
            removeGlobalKeyMonitor()

            NSApp.setActivationPolicy(.accessory)
        }
    }

    func dismissCurrentAlert() {
        hideAlertWindows()

        // Remove from queue
        if !alertQueue.isEmpty {
            alertQueue.removeFirst()
        }

        // Show next alert or mark as not showing
        if !alertQueue.isEmpty {
            showNextAlert()
        } else {
            isShowingAlert = false
            removeGlobalKeyMonitor()

            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - Alert Display

    private func displayFullScreenAlert(for item: AlertItem) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let theme = ThemeService.shared.getTheme(for: item.calendarIdentifier)
        let largestScreen = screens.max(by: { $0.frame.width < $1.frame.width }) ?? screens[0]
        let scale = largestScreen.backingScaleFactor
        let blurRadius = (theme.imageBlurRadius ?? 0.3) * 50

        let showWindows = { [weak self] (bgImage: NSImage?) in
            guard let self = self else { return }

            self.reconcileAlertWindows(for: screens)
            self.updateAlertContent(item: item, theme: theme, backgroundImage: bgImage, screens: screens)

            for window in self.alertWindows {
                window.orderFrontRegardless()
            }

            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            self.alertWindows.first?.makeKeyAndOrderFront(nil)
            self.installGlobalKeyMonitor()
        }

        if let filename = theme.imageFileName {
            ImageStore.loadBlurredAsync(filename, targetSize: CGSize(width: largestScreen.frame.width * scale, height: largestScreen.frame.height * scale), blurRadius: blurRadius) { image in
                showWindows(image)
            }
        } else {
            showWindows(nil)
        }
    }

    /// Update the rootView of each hosting view directly — no Combine, no @ObservedObject.
    private func updateAlertContent(item: AlertItem, theme: AlertTheme, backgroundImage: NSImage?, screens: [NSScreen]) {
        for (index, hostingView) in alertHostingViews.enumerated() {
            let isPrimary = index == 0
            hostingView.rootView = FullScreenAlertView(
                alertItem: item,
                theme: theme,
                queuePosition: 1,
                queueTotal: alertQueue.count,
                isPrimaryScreen: isPrimary,
                onDismiss: { [weak self] in
                    if self?.isPreviewMode == true { self?.dismissPreview() }
                    else { self?.dismissCurrentAlert() }
                },
                onSnooze: { [weak self] duration in
                    if self?.isPreviewMode == true { self?.dismissPreview() }
                    else { self?.snoozeCurrentAlert(for: duration) }
                },
                onJoinMeeting: { url in
                    NSWorkspace.shared.open(url)
                },
                backgroundImage: backgroundImage
            )
        }
    }

    private func hideAlertWindows() {
        for window in alertWindows {
            window.orderOut(nil)
        }
        // Replace content with Color.clear — tears down SwiftUI's rendering
        // tree while keeping the hosting view attached to the window.
        for hostingView in alertHostingViews {
            var view = hostingView.rootView
            view.isEmpty = true
            view.backgroundImage = nil
            hostingView.rootView = view
        }
    }

    /// Create or reuse windows so there's one per screen.
    private func reconcileAlertWindows(for screens: [NSScreen]) {
        // Remove excess windows if screens decreased
        while alertWindows.count > screens.count {
            alertWindows.removeLast()
            alertHostingViews.removeLast()
        }

        for (index, screen) in screens.enumerated() {
            if index < alertWindows.count {
                // Reuse existing window — just reposition
                alertWindows[index].setFrame(screen.frame, display: false)
            } else {
                // Create a new window for this screen
                let (window, hostingView) = createAlertWindow(for: screen, isPrimary: index == 0)
                alertWindows.append(window)
                alertHostingViews.append(hostingView)
            }
        }
    }

    private func createAlertWindow(for screen: NSScreen, isPrimary: Bool) -> (NSPanel, FirstClickHostingView<FullScreenAlertView>) {
        let window = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.hidesOnDeactivate = false
        window.isFloatingPanel = true

        // Create a placeholder view — will be replaced by updateAlertContent
        let placeholder = FullScreenAlertView(
            alertItem: .calendarEvent(CalendarEvent.mock()),
            theme: AlertTheme.defaultTheme(),
            queuePosition: 1,
            queueTotal: 1,
            isPrimaryScreen: isPrimary,
            onDismiss: {},
            onSnooze: { _ in },
            onJoinMeeting: { _ in }
        )

        let hostingView = FirstClickHostingView(rootView: placeholder)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return (window, hostingView)
    }

    // MARK: - Keyboard Monitoring
    
    private func setupKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                if self?.isShowingAlert == true {
                    self?.dismissCurrentAlert()
                    return nil
                }
            }
            return event
        }
    }

    /// Global monitor catches Escape even when the app isn't the key app —
    /// a critical safety net so the user is never locked out.
    /// Requires Accessibility permissions; falls back to a shorter auto-dismiss if unavailable.
    private func installGlobalKeyMonitor() {
        guard globalKeyMonitor == nil else { return }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                DispatchQueue.main.async {
                    self?.dismissCurrentAlert()
                }
            }
        }
        if globalKeyMonitor == nil {
            print("⚠️ Global key monitor unavailable (Accessibility permissions needed).")
        }
    }

    private func removeGlobalKeyMonitor() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
    }

    
    // MARK: - Testing/Preview
    
    func showPreviewAlert(for event: CalendarEvent) {
        let theme = ThemeService.shared.getTheme(for: event.calendar.identifier)
        showPreviewAlert(theme: theme, item: .calendarEvent(event))
    }

    func showPreviewAlert(for reminder: CustomReminder) {
        let theme = ThemeService.shared.getTheme(for: nil)
        showPreviewAlert(theme: theme, item: .customReminder(reminder))
    }

    func showPreviewAlert(theme: AlertTheme) {
        let mockEvent = CalendarEvent.mock()
        let item = AlertItem.calendarEvent(mockEvent)
        showPreviewAlert(theme: theme, item: item)
    }

    private func showPreviewAlert(theme: AlertTheme, item: AlertItem) {
        isPreviewMode = true

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let largestScreen = screens.max(by: { $0.frame.width < $1.frame.width }) ?? screens[0]
        let scale = largestScreen.backingScaleFactor
        let blurRadius = (theme.imageBlurRadius ?? 0.3) * 50

        let showWindows = { [weak self] (bgImage: NSImage?) in
            guard let self = self else { return }

            self.reconcileAlertWindows(for: screens)
            self.updateAlertContent(item: item, theme: theme, backgroundImage: bgImage, screens: screens)

            for window in self.alertWindows {
                window.orderFrontRegardless()
            }

            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            self.alertWindows.first?.makeKeyAndOrderFront(nil)
            self.installPreviewMonitors()
        }

        if let filename = theme.imageFileName {
            ImageStore.loadBlurredAsync(filename, targetSize: CGSize(width: largestScreen.frame.width * scale, height: largestScreen.frame.height * scale), blurRadius: blurRadius) { image in
                showWindows(image)
            }
        } else {
            showWindows(nil)
        }
    }

    private func installPreviewMonitors() {
        // Remove any existing monitors first
        if let m = previewLocalMonitor { NSEvent.removeMonitor(m); previewLocalMonitor = nil }
        if let m = previewGlobalMonitor { NSEvent.removeMonitor(m); previewGlobalMonitor = nil }

        previewLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismissPreview()
                return nil
            }
            return event
        }

        previewGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { self?.dismissPreview() }
            }
        }
    }

    private func dismissPreview() {
        if let m = previewLocalMonitor { NSEvent.removeMonitor(m); previewLocalMonitor = nil }
        if let m = previewGlobalMonitor { NSEvent.removeMonitor(m); previewGlobalMonitor = nil }

        hideAlertWindows()
        isPreviewMode = false

        // Restore activation policy
        if let settingsWindow = NSApp.windows.first(where: { $0.isVisible && $0.title == "Settings" }) {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                settingsWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

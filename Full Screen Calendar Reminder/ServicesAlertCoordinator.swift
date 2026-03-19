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
    
    @Published var alertQueue: [AlertItem] = []
    @Published var isShowingAlert = false

    private var alertWindows: [NSWindow] = []
    private var globalKeyMonitor: Any?
    private var snoozeTimers: [Timer] = []

    // Preview state — tracked so we can clean up before opening a new preview
    private var previewWindows: [NSWindow] = []
    private var previewLocalMonitor: Any?
    private var previewGlobalMonitor: Any?
    private var previewCloseObserver: NSObjectProtocol?

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

        // Close windows and release view hierarchy to free image memory
        for window in alertWindows {
            window.contentView = nil
            window.close()
        }
        alertWindows.removeAll()
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
        // Release view hierarchy to free image memory, then close
        for window in alertWindows {
            window.contentView = nil
            window.close()
        }
        alertWindows.removeAll()

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
            // Restore accessory mode so the dock icon is hidden
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - Alert Display
    
    private func displayFullScreenAlert(for item: AlertItem) {
        // Release view hierarchy and close any existing windows
        for window in alertWindows {
            window.contentView = nil
            window.close()
        }
        alertWindows.removeAll()

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let theme = ThemeService.shared.getTheme(for: item.calendarIdentifier)
        // Pre-render background: downscale to screen pixel size and bake in blur.
        let largestScreen = screens.max(by: { $0.frame.width < $1.frame.width }) ?? screens[0]
        let scale = largestScreen.backingScaleFactor
        let blurRadius = (theme.imageBlurRadius ?? 0.3) * 50
        let bgImage: NSImage? = theme.imageFileName.flatMap {
            ImageStore.loadBlurred($0, targetSize: CGSize(width: largestScreen.frame.width * scale, height: largestScreen.frame.height * scale), blurRadius: blurRadius)
        }

        for (index, screen) in screens.enumerated() {
            let isPrimary = index == 0
            let window = createAlertWindow(for: screen, item: item, theme: theme, backgroundImage: bgImage, isPrimary: isPrimary)
            alertWindows.append(window)
            window.orderFrontRegardless()
        }

        // Become a .regular app so macOS fully activates us and routes
        // keyboard/mouse events to our overlay windows.  Without this,
        // .accessory apps can show windows but never properly receive
        // input — causing the "frozen overlay" bug.
        // We stay .regular for the entire alert duration (the full-screen
        // overlay covers any dock icon anyway) and restore .accessory
        // in dismissCurrentAlert once all alerts are gone.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alertWindows.first?.makeKeyAndOrderFront(nil)

        installGlobalKeyMonitor()
    }

    private func createAlertWindow(
        for screen: NSScreen,
        item: AlertItem,
        theme: AlertTheme,
        backgroundImage: NSImage?,
        isPrimary: Bool
    ) -> NSPanel {
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

        let contentView = FullScreenAlertView(
            alertItem: item,
            theme: theme,
            queuePosition: 1,
            queueTotal: alertQueue.count,
            isPrimaryScreen: isPrimary,
            onDismiss: { [weak self] in
                self?.dismissCurrentAlert()
            },
            onSnooze: { [weak self] duration in
                self?.snoozeCurrentAlert(for: duration)
            },
            onJoinMeeting: { url in
                NSWorkspace.shared.open(url)
            },
            backgroundImage: backgroundImage
        )

        let hostingView = FirstClickHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
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
        // Clean up any previous preview first
        closePreviewWindows()

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let largestScreen = screens.max(by: { $0.frame.width < $1.frame.width }) ?? screens[0]
        let scale = largestScreen.backingScaleFactor
        let blurRadius = (theme.imageBlurRadius ?? 0.3) * 50

        // Load/blur image on background thread to keep UI responsive
        let loadAndShow = { [weak self] (bgImage: NSImage?) in
            guard let self = self else { return }

            for (index, screen) in screens.enumerated() {
                let isPrimary = index == 0
                let window = self.createPreviewWindow(for: screen, item: item, theme: theme, backgroundImage: bgImage, isPrimary: isPrimary)
                self.previewWindows.append(window)
                window.orderFrontRegardless()
            }

            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            self.previewWindows.first?.makeKeyAndOrderFront(nil)

            self.installPreviewMonitors()
        }

        if let filename = theme.imageFileName {
            ImageStore.loadBlurredAsync(filename, targetSize: CGSize(width: largestScreen.frame.width * scale, height: largestScreen.frame.height * scale), blurRadius: blurRadius) { image in
                loadAndShow(image)
            }
        } else {
            loadAndShow(nil)
        }

    }

    private func installPreviewMonitors() {
        previewLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePreviewWindows()
                return nil
            }
            return event
        }

        previewGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                DispatchQueue.main.async { self?.closePreviewWindows() }
            }
        }

        previewCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: previewWindows.first,
            queue: .main
        ) { [weak self] _ in
            self?.closePreviewWindows()
        }
    }

    private func closePreviewWindows() {
        // Remove event monitors
        if let m = previewLocalMonitor { NSEvent.removeMonitor(m); previewLocalMonitor = nil }
        if let m = previewGlobalMonitor { NSEvent.removeMonitor(m); previewGlobalMonitor = nil }
        if let o = previewCloseObserver { NotificationCenter.default.removeObserver(o); previewCloseObserver = nil }

        // Release view hierarchy and close windows
        for window in previewWindows {
            window.contentView = nil
            window.close()
        }
        previewWindows.removeAll()

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
    
    private func createPreviewWindow(
        for screen: NSScreen,
        item: AlertItem,
        theme: AlertTheme,
        backgroundImage: NSImage?,
        isPrimary: Bool
    ) -> NSPanel {
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

        let contentView = FullScreenAlertView(
            alertItem: item,
            theme: theme,
            queuePosition: 1,
            queueTotal: 1,
            isPrimaryScreen: isPrimary,
            onDismiss: { [weak self] in
                self?.closePreviewWindows()
            },
            onSnooze: { [weak self] _ in
                self?.closePreviewWindows()
            },
            onJoinMeeting: { _ in },
            backgroundImage: backgroundImage
        )

        let hostingView = FirstClickHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }
}

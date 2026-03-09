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
    
    func dismissCurrentAlert() {
        // Close all alert windows
        for window in alertWindows {
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
        // Close any existing windows
        for window in alertWindows {
            window.close()
        }
        alertWindows.removeAll()

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        let theme = ThemeService.shared.getTheme(for: item.calendarIdentifier)

        for (index, screen) in screens.enumerated() {
            let isPrimary = index == 0
            let window = createAlertWindow(for: screen, item: item, theme: theme, isPrimary: isPrimary)
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
            onJoinMeeting: { url in
                NSWorkspace.shared.open(url)
            }
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
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        
        var previewWindows: [NSWindow] = []
        
        for (index, screen) in screens.enumerated() {
            let isPrimary = index == 0
            let window = createPreviewWindow(for: screen, item: item, theme: theme, isPrimary: isPrimary)
            previewWindows.append(window)
            window.orderFrontRegardless()
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        previewWindows.first?.makeKeyAndOrderFront(nil)

        // Local monitor for when the app is active
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                for window in previewWindows { window.close() }
                return nil
            }
            return event
        }

        // Global monitor as safety net
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    for window in previewWindows { window.close() }
                }
            }
        }

        // Clean up monitors when the first window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: previewWindows.first,
            queue: .main
        ) { _ in
            NSEvent.removeMonitor(localMonitor as Any)
            if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func createPreviewWindow(
        for screen: NSScreen,
        item: AlertItem,
        theme: AlertTheme,
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
            onDismiss: { [weak window] in
                window?.close()
            },
            onJoinMeeting: { _ in }
        )

        let hostingView = FirstClickHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        return window
    }
}

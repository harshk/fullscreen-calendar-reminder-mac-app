//
//  AppDelegate.swift
//  Full Screen Calendar Reminder
//
//  Created by Harsh Kalra on 3/5/26.
//

import Cocoa
import SwiftUI
import SwiftData
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    var modelContainer: ModelContainer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched")

        // Pre-warm font list so the presets tab loads instantly
        _ = FontCache.shared

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup model container
        do {
            let schema = Schema([CustomReminder.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Setup menu bar
        setupMenuBar()
        
        // Request calendar access
        Task { @MainActor in
            do {
                try await CalendarService.shared.requestAccess()
            } catch {
                print("Failed to request calendar access: \(error)")
            }
        }
        
        // Setup reminder service with model context
        let context = modelContainer.mainContext
        ReminderService.shared.setModelContext(context)
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateMenuBarIcon()
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Setup panel
        let contentSize = NSSize(width: 350, height: 500)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView:
            MenuBarView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.frame = NSRect(origin: .zero, size: contentSize)
            glassView.autoresizingMask = [.width, .height]
            hostingView.frame = glassView.bounds
            hostingView.autoresizingMask = [.width, .height]
            hostingView.layer?.backgroundColor = .clear
            glassView.contentView = hostingView
            panel.contentView = glassView
        } else {
            let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))
            visualEffect.material = .menu
            visualEffect.state = .active
            visualEffect.blendingMode = .behindWindow
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 10
            visualEffect.layer?.masksToBounds = true
            hostingView.frame = visualEffect.bounds
            hostingView.autoresizingMask = [.width, .height]
            hostingView.layer?.backgroundColor = .clear
            visualEffect.addSubview(hostingView)
            panel.contentView = visualEffect
        }
        self.panel = panel
        
        // Hide dock icon when settings window closes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        // Observe open settings requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )

        // Observe dismiss popover requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissPopover),
            name: .dismissPopover,
            object: nil
        )

        // Observe pause state changes to update icon
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarIcon),
            name: NSNotification.Name("PauseStateChanged"),
            object: nil
        )
        
        // Update icon when settings change
        AppSettings.shared.$isPaused
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @objc private func updateMenuBarIcon() {
        if let button = statusItem?.button {
            let isPaused = AppSettings.shared.isPaused
            if isPaused {
                button.image = NSImage(systemSymbolName: "bell.slash.fill", accessibilityDescription: "Full Screen Calendar Reminder (Paused)")
            } else {
                let icon = NSImage(named: "StatusBarIcon")
                icon?.size = NSSize(width: 22, height: 22)
                icon?.isTemplate = true
                button.image = icon
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc private func windowDidClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              closedWindow == settingsWindow else { return }
        SettingsWindowVisible.shared.isVisible = false
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func openSettings() {
        closePanel()

        // Reuse the existing settings window to avoid the ~10-20 MB per-cycle
        // leak in SwiftUI/AppKit internals that occurs when recreating.
        SettingsWindowVisible.shared.isVisible = true
        if let settingsWindow = settingsWindow {
            NSApp.setActivationPolicy(.regular)
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        self.settingsWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleDismissPopover() {
        closePanel()
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showRightClickMenu()
            return
        }
        togglePanel()
    }

    private func showRightClickMenu() {
        let menu = NSMenu()
        let pauseTitle = AppSettings.shared.isPaused ? "Unpause Full Screen Reminders" : "Pause Full Screen Reminders"
        menu.addItem(NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // Reset so left-click still shows the panel
    }

    @objc private func togglePause() {
        AppSettings.shared.isPaused.toggle()
    }

    @objc private func togglePanel() {
        guard let panel = panel, let button = statusItem?.button else { return }

        if panel.isVisible {
            closePanel()
        } else {
            let buttonFrame = button.window!.convertToScreen(button.convert(button.bounds, to: nil))
            let panelSize = panel.frame.size
            let x = buttonFrame.midX - panelSize.width / 2
            let y = buttonFrame.minY - panelSize.height
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            panel.orderFrontRegardless()
            startEventMonitor()
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else { return event }
            // If the click is inside the panel, let it through
            if event.window === panel { return event }
            // If the click is on the status bar button, let togglePanel handle it
            if event.window === self.statusItem?.button?.window { return event }
            self.closePanel()
            return event
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}


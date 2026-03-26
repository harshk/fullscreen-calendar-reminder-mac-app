//
//  AppDelegate.swift
//  ZapCal
//
//  Created by Harsh Kalra on 3/5/26.
//

import Cocoa
import SwiftUI
import SwiftData
import Combine

extension Notification.Name {
    static let menuBarPanelDidClose = Notification.Name("menuBarPanelDidClose")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private var manageRemindersWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var addReminderWindow: NSWindow?
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    var modelContainer: ModelContainer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched")

        // Migrate Application Support directory from old name to new name
        migrateAppSupportDirectory()

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
        
        // Show welcome screen if no calendar access, otherwise request silently
        if CalendarService.shared.hasAccess {
            Task { @MainActor in
                do {
                    try await CalendarService.shared.requestAccess()
                } catch {
                    print("Failed to request calendar access: \(error)")
                }
            }
        } else {
            showWelcomeWindow()
        }

        // Start Apple Reminders service if enabled and has access
        if AppSettings.shared.appleRemindersEnabled && AppleRemindersService.shared.hasAccess {
            Task { @MainActor in
                await AppleRemindersService.shared.loadReminderLists()
                AppleRemindersService.shared.startPolling()
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

        // Observe open manage reminders requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openManageReminders),
            name: .openManageReminders,
            object: nil
        )

        // Observe show welcome screen requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowWelcomeScreen),
            name: .showWelcomeScreen,
            object: nil
        )

        // Observe open add reminder requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenAddReminder),
            name: .openAddReminder,
            object: nil
        )

        // Observe dismiss popover requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissPopover),
            name: .dismissPopover,
            object: nil
        )

        // Observe welcome setup complete — pulse icon and open popover
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWelcomeSetupComplete),
            name: .welcomeSetupComplete,
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
                button.image = NSImage(systemSymbolName: "bell.slash.fill", accessibilityDescription: "ZapCal (Paused)")
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
        guard let closedWindow = notification.object as? NSWindow else { return }

        if closedWindow == settingsWindow {
            SettingsWindowVisible.shared.isVisible = false
        } else if closedWindow == manageRemindersWindow {
            // No extra state to reset
        } else if closedWindow == welcomeWindow {
            // No extra state to reset
        } else if closedWindow == addReminderWindow {
            // No extra state to reset
        } else {
            return
        }

        // Hide dock icon if no other managed windows are visible
        // Exclude the window being closed since it's still technically visible during willClose
        let settingsVisible = settingsWindow != closedWindow && settingsWindow?.isVisible == true
        let manageVisible = manageRemindersWindow != closedWindow && manageRemindersWindow?.isVisible == true
        let welcomeVisible = welcomeWindow != closedWindow && welcomeWindow?.isVisible == true
        let addReminderVisible = addReminderWindow != closedWindow && addReminderWindow?.isVisible == true
        if !settingsVisible && !manageVisible && !welcomeVisible && !addReminderVisible {
            NSApp.setActivationPolicy(.accessory)
        }
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

    @objc private func openManageReminders() {
        closePanel()

        if let manageRemindersWindow = manageRemindersWindow {
            NSApp.setActivationPolicy(.regular)
            manageRemindersWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Manage ZapCal Reminders"
        window.contentView = NSHostingView(rootView: ManageRemindersView())
        window.center()
        window.isReleasedWhenClosed = false
        self.manageRemindersWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showWelcomeWindow() {
        closePanel()

        if let welcomeWindow = welcomeWindow {
            NSApp.setActivationPolicy(.regular)
            welcomeWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to ZapCal"
        window.contentView = NSHostingView(rootView: WelcomeView())
        window.center()
        window.isReleasedWhenClosed = false
        self.welcomeWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleShowWelcomeScreen() {
        showWelcomeWindow()
    }

    @objc private func handleWelcomeSetupComplete() {
        // Pulse the menu bar icon
        pulseMenuBarIcon()

        // Auto-open the popover after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.togglePanel()
        }
    }

    private func pulseMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        // Spin the icon back and forth
        let layer = button.layer ?? {
            button.wantsLayer = true
            return button.layer!
        }()

        let spin = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let angle = CGFloat.pi / 6 // 30 degrees
        // ~0.14s per segment (same speed as original 1.4s / 10 segments)
        // 5.0s / 0.14s ≈ 36 segments = 18 full swings
        var values: [CGFloat] = [0]
        for i in 1...35 {
            values.append(i % 2 == 1 ? angle : -angle)
        }
        values.append(0)
        let count = values.count
        spin.values = values
        spin.keyTimes = (0..<count).map { NSNumber(value: Double($0) / Double(count - 1)) }
        spin.duration = 5.0
        spin.isRemovedOnCompletion = true

        // Set anchor point to center
        let bounds = button.bounds
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)

        layer.add(spin, forKey: "wiggle")
    }

    @objc private func handleOpenAddReminder() {
        closePanel()

        if let addReminderWindow = addReminderWindow {
            NSApp.setActivationPolicy(.regular)
            addReminderWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add ZapCal Reminder"
        window.contentView = NSHostingView(rootView: AddReminderView())
        window.center()
        window.isReleasedWhenClosed = false
        self.addReminderWindow = window

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
        let pauseTitle = AppSettings.shared.isPaused ? "Resume ZapCal Alerts" : "Pause all ZapCal Alerts"
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
            // visibleFrame.maxY is the exact bottom edge of the menu bar,
            // independent of screen resolution or scaling.
            let screen = button.window!.screen ?? NSScreen.main!
            let y = screen.visibleFrame.maxY - panelSize.height
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            // Reactivate the visual effect blur before showing
            if let visualEffect = panel.contentView as? NSVisualEffectView {
                visualEffect.state = .active
            }
            panel.orderFrontRegardless()
            startEventMonitor()
        }
    }

    private func closePanel() {
        // Deactivate the visual effect blur to release GPU textures
        if let visualEffect = panel?.contentView as? NSVisualEffectView {
            visualEffect.state = .inactive
        }
        panel?.orderOut(nil)
        stopEventMonitor()
        NotificationCenter.default.post(name: .menuBarPanelDidClose, object: nil)
    }

    /// Whether the panel dismiss monitors should act. Set instead of
    /// creating/destroying monitors each open/close (which leaks ~0.3 MB/cycle).
    private var panelMonitorsActive = false

    private func startEventMonitor() {
        panelMonitorsActive = true
        guard eventMonitor == nil else { return }  // already installed

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard self?.panelMonitorsActive == true else { return }
            self?.closePanel()
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panelMonitorsActive, let panel = self.panel, panel.isVisible else { return event }
            if event.window === panel { return event }
            if event.window === self.statusItem?.button?.window { return event }
            self.closePanel()
            return event
        }
    }

    private func stopEventMonitor() {
        panelMonitorsActive = false
    }

    // MARK: - App Support Directory Migration

    private func migrateAppSupportDirectory() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldDir = appSupport.appendingPathComponent("Full Screen Calendar Reminder", isDirectory: true)
        let newDir = appSupport.appendingPathComponent("ZapCal", isDirectory: true)
        guard fm.fileExists(atPath: oldDir.path), !fm.fileExists(atPath: newDir.path) else { return }
        do {
            try fm.moveItem(at: oldDir, to: newDir)
            print("Migrated app support directory to ZapCal")
        } catch {
            print("Failed to migrate app support directory: \(error)")
        }
    }
}

